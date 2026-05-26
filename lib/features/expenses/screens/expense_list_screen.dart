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
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(groupExpensesProvider(groupId).notifier).refresh(),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧾', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text('No expenses yet',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add the first one',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                  ),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<dynamic>>{};
          for (final e in expenses) {
            final key = DateFormat('MMMM d, yyyy').format(e.createdAt);
            grouped.putIfAbsent(key, () => []).add(e);
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(groupExpensesProvider(groupId).notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 4),
              itemCount: grouped.length,
              itemBuilder: (context, sectionIdx) {
                final date = grouped.keys.elementAt(sectionIdx);
                final items = grouped[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        date,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.45),
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                    ...items.map((expense) {
                      final isPayer = expense.paidBy == myId;
                      return _ExpenseCard(
                        expense: expense,
                        isPayer: isPayer,
                        onTap: () => context.push(
                            '/groups/$groupId/expenses/${expense.id}'),
                      );
                    }),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/groups/$groupId/add-expense'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Add',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final dynamic expense;
  final bool isPayer;
  final VoidCallback onTap;

  const _ExpenseCard({
    required this.expense,
    required this.isPayer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isPayer
                        ? AppTheme.primaryGradient
                        : const LinearGradient(
                            colors: [Color(0xFF6B7280), Color(0xFF4B5563)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    expense.receiptUrl != null
                        ? Icons.receipt_rounded
                        : Icons.attach_money_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isPayer
                            ? 'You paid'
                            : '${expense.paidByName ?? 'Someone'} paid',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                      ),
                    ],
                  ),
                ),
                // Amount
                Text(
                  CurrencyUtils.format(expense.amount,
                      currency: expense.currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isPayer ? AppTheme.primary : null,
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
