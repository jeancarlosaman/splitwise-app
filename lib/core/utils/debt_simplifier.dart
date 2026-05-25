/// Simplifies a set of debts to the minimum number of transactions.
///
/// Algorithm:
///   1. Compute net balance per person.
///      Positive balance  → the person is owed money (creditor).
///      Negative balance  → the person owes money (debtor).
///   2. Greedily match the largest creditor with the largest debtor,
///      create a settlement for min(|credit|, |debit|), then recurse.
library debt_simplifier;

/// A single suggested payment: [from] pays [amount] to [to].
class Settlement {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const Settlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  @override
  String toString() =>
      'Settlement(from: $fromUserId → to: $toUserId, amount: $amount)';
}

class DebtSimplifier {
  DebtSimplifier._();

  /// Takes a map of {userId: netBalance} and returns the minimum set of
  /// [Settlement]s that zeroes out all balances.
  ///
  /// [balances] must already be computed: positive = creditor, negative = debtor.
  static List<Settlement> simplify(Map<String, double> balances) {
    // Filter out near-zero balances (floating-point noise)
    final net = Map<String, double>.fromEntries(
      balances.entries.where((e) => e.value.abs() > 0.005),
    );

    final settlements = <Settlement>[];
    _simplifyRecursive(net, settlements);
    return settlements;
  }

  static void _simplifyRecursive(
    Map<String, double> balances,
    List<Settlement> out,
  ) {
    // Find the person who is owed the most (max creditor)
    String? maxCreditorId;
    double maxCredit = 0;

    // Find the person who owes the most (max debtor)
    String? maxDebtorId;
    double maxDebt = 0;

    for (final entry in balances.entries) {
      if (entry.value > maxCredit) {
        maxCredit = entry.value;
        maxCreditorId = entry.key;
      }
      if (entry.value < -maxDebt) {
        maxDebt = -entry.value;
        maxDebtorId = entry.key;
      }
    }

    // Base case: no more debts
    if (maxCreditorId == null || maxDebtorId == null) return;

    // The debtor pays the minimum of what they owe and what the creditor needs
    final payAmount = maxCredit < maxDebt ? maxCredit : maxDebt;
    final roundedAmount = (payAmount * 100).round() / 100;

    if (roundedAmount > 0) {
      out.add(Settlement(
        fromUserId: maxDebtorId,
        toUserId: maxCreditorId,
        amount: roundedAmount,
      ));
    }

    // Update balances
    balances[maxCreditorId] = (balances[maxCreditorId]! - payAmount);
    balances[maxDebtorId]   = (balances[maxDebtorId]!  + payAmount);

    // Remove settled-up parties
    if (balances[maxCreditorId]!.abs() < 0.005) {
      balances.remove(maxCreditorId);
    }
    if (balances[maxDebtorId]!.abs() < 0.005) {
      balances.remove(maxDebtorId);
    }

    _simplifyRecursive(balances, out);
  }

  /// Computes per-user net balances from a list of expense records.
  ///
  /// [expenses] is a list of maps with keys:
  ///   - 'paid_by': userId who paid
  ///   - 'participants': List<{'user_id': String, 'share_amount': double}>
  static Map<String, double> computeNetBalances(
    List<Map<String, dynamic>> expenses,
  ) {
    final net = <String, double>{};

    for (final expense in expenses) {
      final paidBy = expense['paid_by'] as String;
      final participants =
          (expense['participants'] as List<dynamic>).cast<Map<String, dynamic>>();

      for (final p in participants) {
        final userId = p['user_id'] as String;
        final share = (p['share_amount'] as num).toDouble();

        if (userId == paidBy) {
          // Payer is also a participant: net effect is (total - share) owed TO them
          net[paidBy] = (net[paidBy] ?? 0) + share; // subtract their own share via loop
        } else {
          // This participant owes the payer
          net[userId] = (net[userId] ?? 0) - share;
          net[paidBy] = (net[paidBy] ?? 0) + share;
        }
      }

      // Correct the double-counting for payer's own share
      final payerParticipant = participants.firstWhere(
        (p) => p['user_id'] == paidBy,
        orElse: () => {},
      );
      if (payerParticipant.isNotEmpty) {
        final payerShare = (payerParticipant['share_amount'] as num).toDouble();
        net[paidBy] = (net[paidBy] ?? 0) - payerShare;
      }
    }

    return net;
  }

  /// Simpler version: given a list of {userId, shareAmount} and the payer,
  /// returns the delta map for a single expense.
  static Map<String, double> deltasForExpense({
    required String paidByUserId,
    required double totalAmount,
    required List<({String userId, double shareAmount})> participants,
  }) {
    final deltas = <String, double>{};

    for (final p in participants) {
      if (p.userId == paidByUserId) continue; // payer owes nothing to themselves
      deltas[p.userId] = (deltas[p.userId] ?? 0) - p.shareAmount;
      deltas[paidByUserId] = (deltas[paidByUserId] ?? 0) + p.shareAmount;
    }

    return deltas;
  }
}
