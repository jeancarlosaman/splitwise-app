/// Simplifies a set of debts into the minimum number of transactions.
///
/// Algorithm: greedy pairing of biggest creditor with biggest debtor.
/// O(n log n) per iteration, good enough for group sizes < 100.
class DebtSimplifier {
  /// [balances] maps userId → net amount.
  /// Positive = this person is owed money.
  /// Negative = this person owes money.
  ///
  /// Returns a list of [Payment] objects describing who pays whom how much.
  static List<Payment> simplify(Map<String, double> balances) {
    // Filter out near-zero balances (floating point noise)
    final credits = <_Entry>[];
    final debts = <_Entry>[];

    for (final entry in balances.entries) {
      final rounded = double.parse(entry.value.toStringAsFixed(2));
      if (rounded > 0.01) {
        credits.add(_Entry(entry.key, rounded));
      } else if (rounded < -0.01) {
        debts.add(_Entry(entry.key, rounded.abs()));
      }
    }

    credits.sort((a, b) => b.amount.compareTo(a.amount));
    debts.sort((a, b) => b.amount.compareTo(a.amount));

    final payments = <Payment>[];

    while (credits.isNotEmpty && debts.isNotEmpty) {
      final credit = credits.first;
      final debt = debts.first;

      final amount = credit.amount < debt.amount ? credit.amount : debt.amount;
      payments.add(Payment(from: debt.userId, to: credit.userId, amount: amount));

      credit.amount -= amount;
      debt.amount -= amount;

      if (credit.amount < 0.01) credits.removeAt(0);
      if (debt.amount < 0.01) debts.removeAt(0);
    }

    return payments;
  }
}

class _Entry {
  final String userId;
  double amount;
  _Entry(this.userId, this.amount);
}

class Payment {
  final String from;
  final String to;
  final double amount;

  const Payment({required this.from, required this.to, required this.amount});

  @override
  String toString() => 'Payment($from → $to: $amount)';
}
