import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/groups_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppTheme.black,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.greenSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.green.withOpacity(0.4)),
                    ),
                    child: const Center(child: Text('💸', style: TextStyle(fontSize: 14))),
                  ),
                  const SizedBox(width: 10),
                  const Text('SplitWise',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800,
                        fontSize: 18, letterSpacing: -0.5)),
                ],
              ),
              background: Container(
                color: AppTheme.black,
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text('My Groups',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 30,
                            fontWeight: FontWeight.w800, letterSpacing: -1)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
                      onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
                      tooltip: 'Sign out',
                    ),
                  ],
                ),
              ),
            ),
          ),

          groupsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.green))),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
            data: (groups) {
              if (groups.isEmpty) return SliverFillRemaining(child: _EmptyState());
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _GroupCard(group: groups[i]),
                    childCount: groups.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/groups/create'),
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final dynamic group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/groups/${group.id}'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.greenSubtle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.green.withOpacity(0.2)),
                  ),
                  child: Center(child: Text(group.emoji, style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name,
                        style: const TextStyle(color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text('Tap to view expenses',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppTheme.greenSubtle,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppTheme.green.withOpacity(0.3)),
              ),
              child: const Center(child: Text('💸', style: TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 24),
            const Text('No groups yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Create a group to start splitting\nexpenses with friends',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
