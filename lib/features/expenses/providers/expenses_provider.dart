import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../../../shared/repositories/expenses_repository.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(),
);

final groupExpensesProvider =
    AsyncNotifierProviderFamily<GroupExpensesNotifier, List<Expense>, String>(
  GroupExpensesNotifier.new,
);

class GroupExpensesNotifier
    extends FamilyAsyncNotifier<List<Expense>, String> {
  @override
  Future<List<Expense>> build(String groupId) async {
    return ref.read(expensesRepositoryProvider).getExpenses(groupId);
  }

  Future<void> refresh() async {
    state = AsyncData(
        await ref.read(expensesRepositoryProvider).getExpenses(arg));
  }

  Future<void> deleteExpense(String expenseId) async {
    await ref.read(expensesRepositoryProvider).deleteExpense(expenseId);
    state = AsyncData(
        state.value!.where((e) => e.id != expenseId).toList());
  }
}
