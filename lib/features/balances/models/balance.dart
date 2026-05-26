import '../../../core/utils/debt_simplifier.dart';

class GroupBalances {
  final Map<String, double> netBalances; // userId → net amount
  final List<Payment> settlements;

  const GroupBalances({
    required this.netBalances,
    required this.settlements,
  });

  factory GroupBalances.compute(Map<String, double> rawBalances) {
    final settlements = DebtSimplifier.simplify(rawBalances);
    return GroupBalances(
      netBalances: rawBalances,
      settlements: settlements,
    );
  }
}
