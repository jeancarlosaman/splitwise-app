import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/group.dart';
import '../providers/groups_provider.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/user_avatar.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});
  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  void _showAddMemberDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(groupMembersProvider(widget.groupId).notifier)
                    .addMemberByEmail(emailCtrl.text.trim());
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Member added!')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')));
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

    // Find the group in the cached list, but DON'T throw if it's missing —
    // that produces a white screen when the personal group was just auto-created
    // and the groupsProvider cache hasn't refreshed yet. Show a sensible
    // fallback header instead.
    final allGroups = groupsAsync.value ?? const [];
    ExpenseGroup? group;
    for (final g in allGroups) {
      if (g.id == widget.groupId) {
        group = g;
        break;
      }
    }
    final isPersonal = group?.isPersonal ?? false;
    final headerText = group != null
        ? (isPersonal ? '👤  My Expenses' : '${group.emoji}  ${group.name}')
        : (groupsAsync.isLoading ? 'Loading…' : 'Group');

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: Text(headerText),
        actions: [
          // Personal groups only have one member — hide the "add member" button.
          if (!isPersonal)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _showAddMemberDialog,
              tooltip: 'Add member',
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Expenses tab
          _QuickNavTab(
            icon: Icons.receipt_long_rounded,
            label: 'View Expenses',
            onTap: () => context.push('/groups/${widget.groupId}/expenses'),
            subtitle: 'See all group expenses',
          ),
          // Balances tab
          _QuickNavTab(
            icon: Icons.account_balance_wallet_rounded,
            label: 'View Balances',
            onTap: () => context.push('/groups/${widget.groupId}/balances'),
            subtitle: 'See who owes what',
          ),
          // Members tab
          membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
            error: (e, _) => Center(child: Text('$e')),
            data: (members) => ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(indent: 72, height: 1),
              itemBuilder: (_, i) {
                final m = members[i];
                return ListTile(
                  leading: UserAvatar(user: m.user, radius: 22),
                  title: Text(m.user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(m.user.email,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabCtrl,
        builder: (_, __) => _tabCtrl.index == 0
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/groups/${widget.groupId}/add-expense'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _QuickNavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickNavTab({required this.icon, required this.label,
      required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.greenSubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                ),
                child: Icon(icon, color: AppTheme.green, size: 30),
              ),
              const SizedBox(height: 16),
              Text(label, style: const TextStyle(color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.greenSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.green.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Open', style: TextStyle(color: AppTheme.green,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: AppTheme.green, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
