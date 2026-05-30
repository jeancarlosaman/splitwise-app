import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/groups_provider.dart';
import '../../balances/screens/settle_all_screen.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../core/utils/currency_utils.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final personalAsync = ref.watch(personalGroupProvider);
    final sharedGroups = ref.watch(sharedGroupsProvider);
    final settlementsAsync = ref.watch(allSettlementsProvider);

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
                      icon: const Icon(Icons.pie_chart_rounded,
                          color: AppTheme.textSecondary),
                      onPressed: () => context.push('/stats'),
                      tooltip: 'Statistics',
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_rounded,
                          color: AppTheme.textSecondary),
                      onPressed: () => context.push('/profile'),
                      tooltip: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // "Things to settle" banner — only shows when there are outstanding
          // payments involving the current user.
          SliverToBoxAdapter(
            child: settlementsAsync.maybeWhen(
              data: (entries) {
                if (entries.isEmpty) return const SizedBox.shrink();
                final youOweTotal = entries
                    .where((e) => e.youOwe)
                    .fold<double>(0, (s, e) => s + e.amount);
                final owedToYouTotal = entries
                    .where((e) => !e.youOwe)
                    .fold<double>(0, (s, e) => s + e.amount);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _SettleBanner(
                    count: entries.length,
                    youOweTotal: youOweTotal,
                    owedToYouTotal: owedToYouTotal,
                    onTap: () => context.push('/settle'),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // Personal group tile — always visible at the top, even before any
          // shared groups exist.
          SliverToBoxAdapter(
            child: personalAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (personal) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _PersonalGroupCard(group: personal),
              ),
            ),
          ),

          // Section header for shared groups
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Row(
                children: [
                  const Text('Shared Groups',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  if (sharedGroups.isNotEmpty)
                    Text('${sharedGroups.length}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),

          groupsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.green)),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: $e',
                        style: const TextStyle(color: AppTheme.textSecondary)))),
            data: (_) {
              if (sharedGroups.isEmpty) {
                return const SliverToBoxAdapter(child: _SharedEmptyState());
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _GroupCard(group: sharedGroups[i]),
                    childCount: sharedGroups.length,
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

class _SettleBanner extends StatelessWidget {
  final int count;
  final double youOweTotal;
  final double owedToYouTotal;
  final VoidCallback onTap;

  const _SettleBanner({
    required this.count,
    required this.youOweTotal,
    required this.owedToYouTotal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final youOwe = youOweTotal > 0;
    final owedToYou = owedToYouTotal > 0;
    // Color the banner red if the user has unpaid debts (more urgent),
    // otherwise green for "money coming your way".
    final accent = youOwe ? AppTheme.negative : AppTheme.positive;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: accent.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.swap_horiz_rounded,
                    color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Things to settle',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        if (youOwe) ...[
                          const TextSpan(
                            text: 'you owe ',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13),
                          ),
                          TextSpan(
                            text: CurrencyUtils.format(youOweTotal,
                                currency: AppConstants.defaultCurrency),
                            style: const TextStyle(
                                color: AppTheme.negative,
                                fontWeight: FontWeight.w800,
                                fontSize: 13),
                          ),
                        ],
                        if (youOwe && owedToYou)
                          const TextSpan(
                              text: '  ·  ',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        if (owedToYou) ...[
                          TextSpan(
                            text: CurrencyUtils.format(owedToYouTotal,
                                currency: AppConstants.defaultCurrency),
                            style: const TextStyle(
                                color: AppTheme.positive,
                                fontWeight: FontWeight.w800,
                                fontSize: 13),
                          ),
                          const TextSpan(
                            text: ' owed to you',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        color: accent, size: 18),
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

class _PersonalGroupCard extends StatelessWidget {
  final dynamic group;
  const _PersonalGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.greenSubtle,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/groups/${group.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.green.withOpacity(0.35), width: 1),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                    child: Text('👤', style: TextStyle(fontSize: 26))),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Expenses',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    SizedBox(height: 4),
                    Text('Solo spending — just for you',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedEmptyState extends StatelessWidget {
  const _SharedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.greenSubtle,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.green.withOpacity(0.3)),
              ),
              child: const Center(
                  child: Text('💸', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 14),
            const Text('No shared groups yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Create one to split expenses with friends',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
