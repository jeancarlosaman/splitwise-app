import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../features/expenses/models/expense.dart';
import '../../features/expenses/models/expense_participant.dart';
import '../../features/expenses/models/receipt_item.dart';
import 'supabase_client.dart';

class ExpensesRepository {
  const ExpensesRepository(this._client);

  final SupabaseClient _client;

  /// Returns all expenses in [groupId], ordered by newest first.
  Future<List<Expense>> fetchExpenses(String groupId) async {
    final data = await _client
        .from('expenses')
        .select('''
          *,
          paid_by_profile:profiles!expenses_paid_by_fkey(*),
          expense_participants(
            *,
            profiles(*)
          )
        ''')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Expense.fromJson(e)).toList();
  }

  /// Fetches a single expense with participants and receipt items.
  Future<Expense> fetchExpense(String expenseId) async {
    final data = await _client
        .from('expenses')
        .select('''
          *,
          paid_by_profile:profiles!expenses_paid_by_fkey(*),
          expense_participants(
            *,
            profiles(*)
          ),
          receipt_items(*)
        ''')
        .eq('id', expenseId)
        .single();

    return Expense.fromJson(data);
  }

  /// Creates a new expense with its participants.
  Future<Expense> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String currency,
    required String paidByUserId,
    required String createdByUserId,
    required String splitType,
    required List<({String userId, double shareAmount})> participants,
    String? receiptUrl,
    List<ReceiptItem>? receiptItems,
  }) async {
    // 1. Insert the expense
    final expenseData = await _client
        .from('expenses')
        .insert({
          'group_id':    groupId,
          'description': description,
          'amount':      amount,
          'currency':    currency,
          'paid_by':     paidByUserId,
          'created_by':  createdByUserId,
          'split_type':  splitType,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
        })
        .select()
        .single();

    final expenseId = expenseData['id'] as String;

    // 2. Insert participants
    if (participants.isNotEmpty) {
      await _client.from('expense_participants').insert(
        participants
            .map((p) => {
                  'expense_id':    expenseId,
                  'user_id':       p.userId,
                  'share_amount':  p.shareAmount,
                })
            .toList(),
      );
    }

    // 3. Insert receipt items (if any)
    if (receiptItems != null && receiptItems.isNotEmpty) {
      await _client.from('receipt_items').insert(
        receiptItems
            .map((item) => {
                  'expense_id':  expenseId,
                  'name':        item.name,
                  'price':       item.price,
                  if (item.assignedTo.isNotEmpty)
                    'assigned_to': item.assignedTo,
                })
            .toList(),
      );
    }

    return fetchExpense(expenseId);
  }

  /// Deletes an expense (cascades to participants and receipt items via FK).
  Future<void> deleteExpense(String expenseId) async {
    await _client.from('expenses').delete().eq('id', expenseId);
  }

  /// Fetches receipt items for [expenseId].
  Future<List<ReceiptItem>> fetchReceiptItems(String expenseId) async {
    final data = await _client
        .from('receipt_items')
        .select()
        .eq('expense_id', expenseId);
    return (data as List).map((e) => ReceiptItem.fromJson(e)).toList();
  }

  /// Fetches participants for [expenseId].
  Future<List<ExpenseParticipant>> fetchParticipants(String expenseId) async {
    final data = await _client
        .from('expense_participants')
        .select('*, profiles(*)')
        .eq('expense_id', expenseId);
    return (data as List).map((e) => ExpenseParticipant.fromJson(e)).toList();
  }

  /// Uploads a receipt image and returns its public URL.
  Future<String> uploadReceiptImage({
    required String expenseId,
    required File imageFile,
  }) async {
    final ext = imageFile.path.split('.').last;
    final path = 'receipts/$expenseId.$ext';

    await _client.storage
        .from(AppConstants.receiptsBucket)
        .upload(path, imageFile);

    final url = _client.storage
        .from(AppConstants.receiptsBucket)
        .getPublicUrl(path);

    return url;
  }

  /// Fetches all expense data needed for balance calculation in a group.
  Future<List<Map<String, dynamic>>> fetchExpensesForBalances(
      String groupId) async {
    final expenses = await _client
        .from('expenses')
        .select('''
          id, paid_by, amount,
          expense_participants(user_id, share_amount)
        ''')
        .eq('group_id', groupId);

    return (expenses as List).map((e) {
      return {
        'paid_by': e['paid_by'] as String,
        'amount': (e['amount'] as num).toDouble(),
        'participants': (e['expense_participants'] as List)
            .map((p) => {
                  'user_id': p['user_id'] as String,
                  'share_amount': (p['share_amount'] as num).toDouble(),
                })
            .toList(),
      };
    }).toList();
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return ExpensesRepository(ref.watch(supabaseClientProvider));
});
