import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/expenses_provider.dart';
import '../../../shared/repositories/expenses_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/theme.dart';
import '../../../features/expenses/models/expense_participant.dart';
import '../../../shared/widgets/user_avatar.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String groupId;
  final String expenseId;

  const ExpenseDetailScreen({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final expense = expensesAsync.value?.cast<dynamic>().firstWhere(
          (e) => e.id == expenseId,
          orElse: () => null,
        );

    if (expense == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense'),
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: () =>
                context.push('/groups/$groupId/expenses/$expenseId/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            color: AppTheme.negative,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('Delete expense?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  content:
                      const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.negative),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref
                    .read(groupExpensesProvider(groupId).notifier)
                    .deleteExpense(expenseId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Amount hero ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  CurrencyUtils.format(expense.amount,
                      currency: expense.currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  expense.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy · h:mm a')
                      .format(expense.createdAt),
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Paid by ──────────────────────────────────────────────
          _InfoTile(
            icon: Icons.person_outline_rounded,
            label: 'Paid by',
            value: expense.paidByName ?? '…',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.category_outlined,
            label: 'Split type',
            value: expense.splitType == 'equal'
                ? 'Equal split'
                : 'By item',
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // ── Participants ─────────────────────────────────────────
          Text(
            'Split between',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _ParticipantsList(expenseId: expenseId, isDark: isDark),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                  fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}

class _ParticipantsList extends ConsumerWidget {
  final String expenseId;
  final bool isDark;
  const _ParticipantsList({required this.expenseId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(expensesRepositoryProvider);

    return FutureBuilder<List<ExpenseParticipant>>(
      future: repo.getParticipants(expenseId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Text('No participants found.');
        }
        return Column(
          children: snap.data!.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (p.user != null)
                    UserAvatar(user: p.user!, radius: 18)
                  else
                    const CircleAvatar(
                        radius: 18,
                        child: Icon(Icons.person, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.user?.displayName ?? p.userId.substring(0, 8),
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                  ),
                  Text(
                    CurrencyUtils.format(p.shareAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.primary),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
