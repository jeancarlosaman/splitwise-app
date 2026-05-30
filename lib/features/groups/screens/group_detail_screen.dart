import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../models/group.dart';
import '../providers/groups_provider.dart';
import '../../balances/screens/balances_screen.dart';
import '../../expenses/screens/expense_list_screen.dart';
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

  void _shareInviteSheet(ExpenseGroup group) {
    final code = group.joinCode;
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This group has no invite code yet — try refreshing.')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Invite to ${group.name}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'Anyone with this code can join the group. Share it via your favorite app.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),

              // Big code display + copy
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.greenSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.green.withValues(alpha: 0.4),
                      width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(code,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          color: AppTheme.green),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(
                            const SnackBar(
                                content: Text('Code copied'),
                                duration: Duration(seconds: 2)));
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share invite',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                onPressed: () async {
                  // share_plus 10.x: static Share.share is still the simplest
                  // call site and works on iOS, Android, and macOS.
                  await Share.share(
                    'Join my SplitWise group "${group.name}" ${group.emoji}\n\n'
                    'Open SplitWise → tap "Join" → enter code:\n\n'
                    '$code',
                    subject: 'Join my SplitWise group',
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Done',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          // Personal groups only have one member — hide invite + add-member.
          if (!isPersonal) ...[
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Share invite',
              onPressed: group == null ? null : () => _shareInviteSheet(group!),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _showAddMemberDialog,
              tooltip: 'Add by email',
            ),
          ],
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
          // Expenses tab — content inlined directly, no intermediate tap.
          ExpenseListView(groupId: widget.groupId),
          // Balances tab — same.
          BalancesView(groupId: widget.groupId),
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

