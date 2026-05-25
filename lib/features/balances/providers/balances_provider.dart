import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/repositories/expenses_repository.dart';
import '../../../shared/repositories/groups_repository.dart';
import '../../../shared/repositories/profiles_repository.dart';
import '../models/balance.dart';

final groupBalancesProvider =
    FutureProvider.family<GroupBalances, String>((ref, groupId) async {
  final expensesRepo = ref.read(expensesRepositoryProvider);
  final groupsRepo   = ref.read(groupsRepositoryProvider);
  final profilesRepo = ref.read(profilesRepositoryProvider);

  // Fetch members
  final members = await groupsRepo.fetchMembers(groupId);
  final memberUsers = members.map((m) => m.user).toList();

  // Fetch expense data (amounts + participants)
  final expenseData = await expensesRepo.fetchExpensesForBalances(groupId);

  // Determine most common currency
  // For simplicity, use the first expense's currency or EUR
  String currency = 'EUR';
  if (expenseData.isNotEmpty) {
    // Full expenses have currency info but our balance query doesn't fetch it.
    // Fetch it separately.
    final expenses = await expensesRepo.fetchExpenses(groupId);
    if (expenses.isNotEmpty) {
      // Use the most frequently occurring currency
      final freq = <String, int>{};
      for (final e in expenses) {
        freq[e.currency] = (freq[e.currency] ?? 0) + 1;
      }
      currency = freq.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }
  }

  return GroupBalances.compute(
    members:     memberUsers,
    expenseData: expenseData,
    currency:    currency,
  );
});
