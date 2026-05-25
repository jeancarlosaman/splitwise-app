import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/repositories/expenses_repository.dart';
import '../models/expense.dart';
import '../models/receipt_item.dart';

// ─────────────────────────────────────────
// Expenses list per group
// ─────────────────────────────────────────

class GroupExpensesNotifier
    extends FamilyAsyncNotifier<List<Expense>, String> {
  @override
  Future<List<Expense>> build(String groupId) async {
    return ref.read(expensesRepositoryProvider).fetchExpenses(groupId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(expensesRepositoryProvider).fetchExpenses(arg),
    );
  }

  Future<Expense> addExpense({
    required String description,
    required double amount,
    required String currency,
    required String paidByUserId,
    required String createdByUserId,
    required String splitType,
    required List<({String userId, double shareAmount})> participants,
    File? receiptImage,
    List<ReceiptItem>? receiptItems,
  }) async {
    final repo = ref.read(expensesRepositoryProvider);

    // Upload receipt image first if present
    String? receiptUrl;
    if (receiptImage != null) {
      // We don't have an expense ID yet — upload after creation
      // We'll handle this by creating expense first, then updating
    }

    final expense = await repo.createExpense(
      groupId:         arg,
      description:     description,
      amount:          amount,
      currency:        currency,
      paidByUserId:    paidByUserId,
      createdByUserId: createdByUserId,
      splitType:       splitType,
      participants:    participants,
      receiptUrl:      receiptUrl,
      receiptItems:    receiptItems,
    );

    // Upload image and update URL if provided
    if (receiptImage != null) {
      try {
        final url = await repo.uploadReceiptImage(
          expenseId: expense.id,
          imageFile: receiptImage,
        );
        // Note: In production you'd update the DB record here.
        // For now we just store locally in the returned object.
        final updated = expense.copyWith(receiptUrl: url);
        state = AsyncData([updated, ...?state.valueOrNull]);
        return updated;
      } catch (_) {
        // Image upload failed — expense still saved without image
      }
    }

    state = AsyncData([expense, ...?state.valueOrNull]);
    return expense;
  }

  Future<void> deleteExpense(String expenseId) async {
    await ref.read(expensesRepositoryProvider).deleteExpense(expenseId);
    state = AsyncData(
      (state.valueOrNull ?? []).where((e) => e.id != expenseId).toList(),
    );
  }
}

final groupExpensesProvider =
    AsyncNotifierProviderFamily<GroupExpensesNotifier, List<Expense>, String>(
  GroupExpensesNotifier.new,
);

// ─────────────────────────────────────────
// Single expense
// ─────────────────────────────────────────

final expenseProvider =
    FutureProvider.family<Expense, String>((ref, expenseId) async {
  return ref.read(expensesRepositoryProvider).fetchExpense(expenseId);
});
