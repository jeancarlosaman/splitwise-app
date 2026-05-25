import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/groups_provider.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../expenses/models/expense.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/user_avatar.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return groupAsync.when(
      loading: () =>
          const Scaffold(body: InlineLoader(message: 'Loading group…')),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: e.toString()),
      ),
      data: (group) => Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(group.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(group.name),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: 'Balances',
              onPressed: () => context.push('/groups/$groupId/balances'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Members strip
            membersAsync.when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (members) => _MembersSection(
                members: members
                    .map((m) => m.user)
                    .toList(),
                groupId: groupId,
              ),
            ),

            const Divider(height: 1),

            // Expenses list
            Expanded(
              child: expensesAsync.when(
                loading: () =>
                    const InlineLoader(message: 'Loading expenses…'),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (expenses) => expenses.isEmpty
                    ? _EmptyExpenses(groupId: groupId)
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(groupExpensesProvider(groupId).notifier)
                            .refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: expenses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _ExpenseTile(
                            expense: expenses[i],
                            groupId: groupId,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/groups/$groupId/add-expense'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Expense'),
        ),
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection({
    required this.members,
    required this.groupId,
  });

  final List members;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.people_alt_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '${members.length} member${members.length == 1 ? '' : 's'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final user in members) ...[
                    Tooltip(
                      message: user.name,
                      child: UserAvatar(user: user, radius: 16),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _showInviteDialog(context, ref),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Member'),
        content: TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'friend@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.of(ctx).pop();

              final member = await ref
                  .read(groupMembersProvider(groupId).notifier)
                  .inviteByEmail(email);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      member != null
                          ? '${member.user.name} added!'
                          : 'No account found for $email.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.groupId});

  final Expense expense;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/groups/$groupId/expense/${expense.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _expenseIcon(expense.description),
                  color: cs.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid by ${expense.paidByProfile?.name ?? 'unknown'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.formatCompact(
                        expense.amount, expense.currency),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                  Text(
                    _formatDate(expense.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _expenseIcon(String description) {
    final d = description.toLowerCase();
    if (d.contains('food') || d.contains('lunch') || d.contains('dinner') ||
        d.contains('restaurant') || d.contains('pizza')) {
      return Icons.restaurant_outlined;
    }
    if (d.contains('transport') || d.contains('taxi') || d.contains('uber') ||
        d.contains('train')) {
      return Icons.directions_car_outlined;
    }
    if (d.contains('hotel') || d.contains('airbnb') || d.contains('accommodation')) {
      return Icons.hotel_outlined;
    }
    if (d.contains('grocery') || d.contains('supermarket') || d.contains('shop')) {
      return Icons.shopping_cart_outlined;
    }
    if (d.contains('drink') || d.contains('bar') || d.contains('beer')) {
      return Icons.local_bar_outlined;
    }
    return Icons.receipt_outlined;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: cs.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No expenses yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first expense.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
