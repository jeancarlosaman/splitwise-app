import '../../auth/models/app_user.dart';
import '../../../core/utils/debt_simplifier.dart';

/// Net balance for a single user in a group.
/// [amount] > 0 means they are owed money.
/// [amount] < 0 means they owe money.
class UserBalance {
  const UserBalance({
    required this.user,
    required this.amount,
    required this.currency,
  });

  final AppUser user;
  final double  amount;
  final String  currency;

  bool get isCreditor => amount > 0.005;
  bool get isDebtor   => amount < -0.005;
  bool get isSettled  => amount.abs() <= 0.005;
}

/// A single settlement suggestion from the debt-simplifier.
class SettlementSuggestion {
  const SettlementSuggestion({
    required this.from,
    required this.to,
    required this.amount,
    required this.currency,
  });

  final AppUser from;
  final AppUser to;
  final double  amount;
  final String  currency;
}

/// Complete balance state for a group.
class GroupBalances {
  const GroupBalances({
    required this.userBalances,
    required this.settlements,
    required this.currency,
  });

  final List<UserBalance>        userBalances;
  final List<SettlementSuggestion> settlements;
  final String                   currency;

  bool get isAllSettled => settlements.isEmpty;

  static GroupBalances compute({
    required List<AppUser> members,
    required List<Map<String, dynamic>> expenseData,
    required String currency,
  }) {
    // Build a user map for lookups
    final userMap = {for (final m in members) m.id: m};

    // Compute net balances using the simplifier
    final netBalances = DebtSimplifier.computeNetBalances(expenseData);

    final userBalances = <UserBalance>[];
    for (final m in members) {
      userBalances.add(UserBalance(
        user:     m,
        amount:   netBalances[m.id] ?? 0.0,
        currency: currency,
      ));
    }

    // Simplify debts
    final balancesCopy = Map<String, double>.from(netBalances);
    final rawSettlements = DebtSimplifier.simplify(balancesCopy);

    final settlements = rawSettlements
        .where((s) =>
            userMap.containsKey(s.fromUserId) &&
            userMap.containsKey(s.toUserId))
        .map((s) => SettlementSuggestion(
              from:     userMap[s.fromUserId]!,
              to:       userMap[s.toUserId]!,
              amount:   s.amount,
              currency: currency,
            ))
        .toList();

    return GroupBalances(
      userBalances: userBalances,
      settlements:  settlements,
      currency:     currency,
    );
  }
}
