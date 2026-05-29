import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/expenses_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/theme.dart';
import '../../../shared/repositories/supabase_client.dart';

class ExpenseListScreen extends ConsumerWidget {
  final String groupId;
  const ExpenseListScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));
    final myId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(groupExpensesProvider(groupId).notifier).refresh(),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => Center(child: Text('$e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.greenSubtle,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                    ),
                    child: const Center(child: Text('🧾', style: TextStyle(fontSize: 38))),
                  ),
                  const SizedBox(height: 20),
                  const Text('No expenses yet',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                  const SizedBox(height: 8),
                  const Text('Tap + to add the first one',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            );
          }

          final grouped = <String, List<dynamic>>{};
          for (final e in expenses) {
            final key = DateFormat('MMMM d, yyyy').format(e.createdAt);
            grouped.putIfAbsent(key, () => []).add(e);
          }

          return RefreshIndicator(
            color: AppTheme.green,
            backgroundColor: AppTheme.surface,
            onRefresh: () => ref.read(groupExpensesProvider(groupId).notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 8),
              itemCount: grouped.length,
              itemBuilder: (context, sectionIdx) {
                final date = grouped.keys.elementAt(sectionIdx);
                final items = grouped[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(date,
                        style: const TextStyle(color: AppTheme.textSecondary,
                            fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    ),
                    ...items.map((expense) => _ExpenseCard(
                      expense: expense,
                      isPayer: expense.paidBy == myId,
                      onTap: () => context.push('/groups/$groupId/expenses/${expense.id}'),
                    )),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/$groupId/add-expense'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final dynamic expense;
  final bool isPayer;
  final VoidCallback onTap;
  const _ExpenseCard({required this.expense, required this.isPayer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: isPayer ? AppTheme.greenSubtle : AppTheme.surface2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isPayer ? AppTheme.green.withOpacity(0.3) : AppTheme.border,
                    ),
                  ),
                  child: Icon(
                    expense.receiptUrl != null
                        ? Icons.receipt_rounded : Icons.attach_money_rounded,
                    color: isPayer ? AppTheme.green : AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.description,
                        style: const TextStyle(color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        isPayer ? 'You paid' : '${expense.paidByName ?? 'Someone'} paid',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Text(
                  CurrencyUtils.format(expense.amount, currency: expense.currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16,
                    color: isPayer ? AppTheme.green : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
