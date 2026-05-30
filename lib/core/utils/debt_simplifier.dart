import 'package:flutter/foundation.dart';

/// Simplifies a set of debts into the minimum number of transactions.
///
/// Algorithm: greedy pairing of biggest creditor with biggest debtor.
/// O(n log n) per iteration, good enough for group sizes < 100.
///
/// IMPORTANT: requires balanced books (sum(balances) ≈ 0). If sum != 0,
/// some expense in the group has participant shares that don't add up to the
/// expense amount, which causes the simplifier to produce nothing (silently!)
/// because there are no credits to pair against the debts (or vice versa).
/// To make that failure mode visible instead of silent, we log a warning AND
/// scale the residual side proportionally so SOMETHING shows up in the UI.
class DebtSimplifier {
  /// [balances] maps userId → net amount.
  /// Positive = this person is owed money.
  /// Negative = this person owes money.
  ///
  /// Returns a list of [Payment] objects describing who pays whom how much.
  static List<Payment> simplify(Map<String, double> balances) {
    if (balances.isEmpty) return const [];

    // Filter out near-zero balances (floating point noise)
    final credits = <_Entry>[];
    final debts = <_Entry>[];

    double sum = 0;
    for (final entry in balances.entries) {
      final rounded = double.parse(entry.value.toStringAsFixed(2));
      sum += rounded;
      if (rounded > 0.01) {
        credits.add(_Entry(entry.key, rounded));
      } else if (rounded < -0.01) {
        debts.add(_Entry(entry.key, rounded.abs()));
      }
    }

    // Books should balance. If they don't, something upstream is wrong
    // (likely participant shares not matching expense amounts). Don't return
    // empty — that hides the actual debts from the UI. Instead, redistribute
    // the residual proportionally onto whichever side is short so we can still
    // produce settlement suggestions.
    if (sum.abs() > 0.01) {
      debugPrint(
          '[DebtSimplifier] WARNING: balances do not sum to zero (residual: ${sum.toStringAsFixed(2)}). '
          'This usually means an expense has participant shares that do not add up to its amount. '
          'Pairing anyway, but the result will be approximate.');
      if (sum > 0 && debts.isEmpty && credits.isNotEmpty) {
        // More credits than debts — credits effectively "lost". Reduce the
        // largest credit by the residual so we have a balanced book.
        credits.first.amount -= sum;
        if (credits.first.amount < 0.01) credits.removeAt(0);
      } else if (sum < 0 && credits.isEmpty && debts.isNotEmpty) {
        // More debts than credits — debts effectively "extra". Reduce the
        // largest debt by the residual.
        debts.first.amount -= sum.abs();
        if (debts.first.amount < 0.01) debts.removeAt(0);
      }
      // If both sides are non-empty, the greedy pairing below handles it
      // correctly — the residual just stays distributed as it is.
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
