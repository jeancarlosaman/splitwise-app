import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/expenses_provider.dart';
import '../models/expense.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/user_avatar.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseProvider(expenseId));

    return expenseAsync.when(
      loading: () =>
          const Scaffold(body: InlineLoader(message: 'Loading expense…')),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: e.toString()),
      ),
      data: (expense) => _ExpenseDetailView(expense: expense),
    );
  }
}

class _ExpenseDetailView extends ConsumerWidget {
  const _ExpenseDetailView({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateStr =
        DateFormat('EEEE, MMMM d, y').format(expense.createdAt.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Detail'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: cs.error),
            tooltip: 'Delete expense',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      expense.description,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      CurrencyUtils.formatAmount(expense.amount, expense.currency),
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Paid by
            _SectionCard(
              title: 'Paid by',
              child: expense.paidByProfile != null
                  ? Row(
                      children: [
                        UserAvatar(user: expense.paidByProfile!, radius: 20),
                        const SizedBox(width: 12),
                        Text(
                          expense.paidByProfile!.name,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Text(expense.paidBy, style: tt.bodyMedium),
            ),
            const SizedBox(height: 12),

            // Split type
            _SectionCard(
              title: 'Split',
              child: Row(
                children: [
                  Chip(
                    label: Text(_splitTypeLabel(expense.splitType)),
                    avatar: const Icon(Icons.call_split_rounded, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Participants
            if (expense.participants.isNotEmpty)
              _SectionCard(
                title: 'Participants (${expense.participants.length})',
                child: Column(
                  children: expense.participants
                      .map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                if (p.user != null) ...[
                                  UserAvatar(user: p.user!, radius: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p.user!.name,
                                      style: tt.bodyMedium,
                                    ),
                                  ),
                                ] else
                                  Expanded(
                                    child: Text(p.userId, style: tt.bodyMedium),
                                  ),
                                Text(
                                  CurrencyUtils.formatCompact(
                                      p.shareAmount, expense.currency),
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),

            // Receipt items
            if (expense.receiptItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Receipt Items',
                child: Column(
                  children: [
                    ...expense.receiptItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                size: 8, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.name)),
                            Text(
                              CurrencyUtils.formatCompact(
                                  item.price, expense.currency),
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          CurrencyUtils.formatCompact(
                              expense.amount, expense.currency),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Receipt image
            if (expense.receiptUrl != null) ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Receipt Image',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: expense.receiptUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                      height: 100,
                      child: Center(
                          child: Icon(Icons.broken_image_outlined, size: 40)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _splitTypeLabel(String type) {
    switch (type) {
      case 'equal':   return 'Split equally';
      case 'by_item': return 'By item';
      case 'custom':  return 'Custom split';
      default:        return type;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
            'Are you sure you want to delete "${expense.description}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(groupExpensesProvider(expense.groupId).notifier)
                  .deleteExpense(expense.id);
              if (context.mounted) context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
