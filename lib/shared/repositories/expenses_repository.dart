import '../../features/expenses/models/expense.dart';
import '../../features/expenses/models/expense_participant.dart';
import '../../features/expenses/models/receipt_item.dart';
import 'supabase_client.dart';

class ExpensesRepository {
  Future<List<Expense>> getExpenses(String groupId) async {
    final data = await supabase
        .from('expenses')
        .select('*, paid_by_profile:profiles!paid_by(*)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Expense.fromJson(e)).toList();
  }

  Future<Expense> createExpense({
    required String groupId,
    required String description,
    required double amount,
    required String currency,
    required String paidBy,
    required String splitType,
    String? receiptUrl,
    String? category,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('expenses')
        .insert({
          'group_id': groupId,
          'description': description,
          'amount': amount,
          'currency': currency,
          'paid_by': paidBy,
          'created_by': userId,
          'split_type': splitType,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
          if (category != null) 'category': category,
        })
        .select()
        .single();
    return Expense.fromJson(data);
  }

  Future<void> addParticipants(
      String expenseId, List<ExpenseParticipant> participants) async {
    await supabase.from('expense_participants').insert(
          participants
              .map((p) => {
                    'expense_id': expenseId,
                    'user_id': p.userId,
                    'share_amount': p.shareAmount,
                  })
              .toList(),
        );
  }

  Future<void> addReceiptItems(
      String expenseId, List<ReceiptItem> items) async {
    await supabase.from('receipt_items').insert(
          items
              .map((i) => {
                    'expense_id': expenseId,
                    'name': i.name,
                    'price': i.price,
                    'assigned_to': i.assignedTo,
                  })
              .toList(),
        );
  }

  Future<List<ExpenseParticipant>> getParticipants(String expenseId) async {
    final data = await supabase
        .from('expense_participants')
        .select('*, profiles(*)')
        .eq('expense_id', expenseId);

    return (data as List).map((e) => ExpenseParticipant.fromJson(e)).toList();
  }

  Future<List<ReceiptItem>> getReceiptItems(String expenseId) async {
    final data = await supabase
        .from('receipt_items')
        .select()
        .eq('expense_id', expenseId);

    return (data as List).map((e) => ReceiptItem.fromJson(e)).toList();
  }

  Future<void> deleteExpense(String expenseId) async {
    await supabase.from('expenses').delete().eq('id', expenseId);
  }

  /// Records a payment from one user to another. Implemented as a regular
  /// expense (paid_by = debtor, single participant = creditor) so it flows
  /// through the existing balance computation and zeros out the debt.
  ///
  /// The description uses a "Settled:" prefix so we can later style these
  /// distinctly in the expenses list.
  Future<void> recordSettlement({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String currency,
    required String fromName,
    required String toName,
  }) async {
    final expense = await createExpense(
      groupId: groupId,
      description: 'Settled: $fromName → $toName',
      amount: amount,
      currency: currency,
      paidBy: fromUserId,
      splitType: 'equal',
    );
    await addParticipants(expense.id, [
      ExpenseParticipant(
        id: '',
        expenseId: expense.id,
        userId: toUserId,
        shareAmount: amount,
      ),
    ]);
  }

  /// Returns the current user's total spending (their share of each expense)
  /// grouped by group ID. Used by the stats screen.
  Future<Map<String, double>> getUserSpendingByGroup() async {
    final userId = supabase.auth.currentUser!.id;

    // Join expense_participants -> expenses to get group_id alongside the share.
    final data = await supabase
        .from('expense_participants')
        .select('share_amount, expenses!inner(group_id)')
        .eq('user_id', userId);

    final result = <String, double>{};
    for (final row in data as List) {
      final share = (row['share_amount'] as num).toDouble();
      final groupId =
          (row['expenses'] as Map<String, dynamic>)['group_id'] as String;
      result[groupId] = (result[groupId] ?? 0) + share;
    }
    return result;
  }

  /// Returns net balance per userId for the group.
  /// Positive = owed money, Negative = owes money.
  Future<Map<String, double>> computeBalances(String groupId) async {
    final expenses = await getExpenses(groupId);
    final balances = <String, double>{};

    for (final expense in expenses) {
      // payer gets credited
      balances[expense.paidBy] =
          (balances[expense.paidBy] ?? 0) + expense.amount;

      // load participants
      final participants = await getParticipants(expense.id);
      for (final p in participants) {
        balances[p.userId] = (balances[p.userId] ?? 0) - p.shareAmount;
      }
    }

    return balances;
  }
}
