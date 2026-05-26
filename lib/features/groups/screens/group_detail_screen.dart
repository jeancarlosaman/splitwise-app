import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/groups_provider.dart';
import '../../../shared/widgets/user_avatar.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _selectedTab = 0;

  void _showAddMemberDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(groupMembersProvider(widget.groupId).notifier)
                    .addMemberByEmail(emailCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Member added!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    final group = groupsAsync.value
        ?.firstWhere((g) => g.id == widget.groupId, orElse: () => throw '');

    return Scaffold(
      appBar: AppBar(
        title: Text(group != null ? '${group.emoji} ${group.name}' : 'Group'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _showAddMemberDialog,
            tooltip: 'Add member',
          ),
        ],
        bottom: TabBar(
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Members'),
          ],
          onTap: (i) => setState(() => _selectedTab = i),
        ),
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          // Expenses tab – push to expense list
          _ExpensesTab(groupId: widget.groupId),
          // Balances tab
          _BalancesShortcutTab(groupId: widget.groupId),
          // Members tab
          membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (members) => ListView.builder(
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                return ListTile(
                  leading: UserAvatar(user: m.user, radius: 20),
                  title: Text(m.user.displayName),
                  subtitle: Text(m.user.email),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/groups/${widget.groupId}/add-expense'),
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  const _ExpensesTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate into full expense list
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.receipt_long),
        label: const Text('View Expenses'),
        onPressed: () => context.push('/groups/$groupId/expenses'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
      ),
    );
  }
}

class _BalancesShortcutTab extends ConsumerWidget {
  final String groupId;
  const _BalancesShortcutTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.balance),
        label: const Text('View Balances'),
        onPressed: () => context.push('/groups/$groupId/balances'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(200, 48)),
      ),
    );
  }
}
