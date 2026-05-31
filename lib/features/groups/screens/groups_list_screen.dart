import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/group.dart';
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

    // Compute the user's net position (incoming - outgoing) for the hero card.
    final entries = settlementsAsync.value ?? const [];
    final youOweTotal =
        entries.where((e) => e.youOwe).fold<double>(0, (s, e) => s + e.amount);
    final owedToYouTotal = entries
        .where((e) => !e.youOwe)
        .fold<double>(0, (s, e) => s + e.amount);
    final net = owedToYouTotal - youOweTotal;
    final hasAnyDebts = entries.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Compact app bar ─────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 56,
            title: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppTheme.mintGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Center(
                    child: Text('S',
                        style: TextStyle(
                            color: Color(0xFF052E1F),
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('SplitWise',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.4)),
              ],
            ),
            actions: [
              _AppBarChip(
                icon: Icons.pie_chart_rounded,
                onTap: () => context.push('/stats'),
              ),
              const SizedBox(width: 8),
              _AppBarChip(
                icon: Icons.person_rounded,
                onTap: () => context.push('/profile'),
              ),
              const SizedBox(width: 16),
            ],
          ),

          // ── Hero balance card ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _HeroBalanceCard(
                net: net,
                youOweTotal: youOweTotal,
                owedToYouTotal: owedToYouTotal,
                hasData: hasAnyDebts || settlementsAsync.hasValue,
                onTap: hasAnyDebts ? () => context.push('/settle') : null,
              ),
            ),
          ),

          // ── Personal group tile ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: personalAsync.when(
              loading: () => const SizedBox(height: 90),
              error: (_, __) => const SizedBox.shrink(),
              data: (personal) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: _PersonalGroupCard(group: personal),
              ),
            ),
          ),

          // ── Section header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
              child: Row(
                children: [
                  const Text('SHARED GROUPS',
                      style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.2)),
                  const Spacer(),
                  if (sharedGroups.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.ink2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${sharedGroups.length}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),

          // ── Shared groups list ──────────────────────────────────────────
          groupsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.mint, strokeWidth: 2.5)),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error: $e',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
            data: (_) {
              if (sharedGroups.isEmpty) {
                return const SliverToBoxAdapter(child: _SharedEmptyState());
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('New Group',
            style: TextStyle(
                fontWeight: FontWeight.w700, letterSpacing: -0.1)),
      ),
    );
  }
}

// ── Hero balance card ─────────────────────────────────────────────────────
class _HeroBalanceCard extends StatelessWidget {
  final double net;
  final double youOweTotal;
  final double owedToYouTotal;
  final bool hasData;
  final VoidCallback? onTap;

  const _HeroBalanceCard({
    required this.net,
    required this.youOweTotal,
    required this.owedToYouTotal,
    required this.hasData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;
    final accent = isPositive ? AppTheme.mint : AppTheme.negative;

    // Subtle tinted gradient backdrop in the direction of the net position.
    final gradient = !hasData
        ? AppTheme.cardGradient
        : (isPositive
            ? AppTheme.mintTintGradient
            : AppTheme.negativeTintGradient);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(AppTheme.radiusXl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.all(AppTheme.radiusXl),
            border: Border.all(
              color: hasData
                  ? accent.withValues(alpha: 0.25)
                  : AppTheme.border,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !hasData
                        ? 'NET POSITION'
                        : isPositive
                            ? 'YOU ARE OWED'
                            : 'YOU OWE',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Settle',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward_rounded,
                              size: 12, color: accent),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    !hasData
                        ? CurrencyUtils.format(0,
                            currency: AppConstants.defaultCurrency)
                        : '${isPositive ? '' : '-'}${CurrencyUtils.format(net.abs(), currency: AppConstants.defaultCurrency)}',
                    style: AppTheme.moneyHero(
                        color:
                            !hasData ? AppTheme.textSecondary : accent),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius:
                      const BorderRadius.all(AppTheme.radiusMd),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeroSubStat(
                        label: 'You owe',
                        amount: youOweTotal,
                        accent: AppTheme.negative,
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.06)),
                    Expanded(
                      child: _HeroSubStat(
                        label: 'Owed to you',
                        amount: owedToYouTotal,
                        accent: AppTheme.mint,
                        alignEnd: true,
                      ),
                    ),
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

class _HeroSubStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color accent;
  final bool alignEnd;
  const _HeroSubStat({
    required this.label,
    required this.amount,
    required this.accent,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
              CurrencyUtils.format(amount,
                  currency: AppConstants.defaultCurrency),
              style: AppTheme.moneyStyle(
                  fontSize: 15, color: accent, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── App-bar chip (round icon button) ──────────────────────────────────────
class _AppBarChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarChip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.ink2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border, width: 1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 18),
        ),
      ),
    );
  }
}

// ── Personal group tile ───────────────────────────────────────────────────
class _PersonalGroupCard extends StatelessWidget {
  final ExpenseGroup group;
  const _PersonalGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(AppTheme.radiusLg),
        onTap: () => context.push('/groups/${group.id}'),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.mintTintGradient,
            borderRadius: const BorderRadius.all(AppTheme.radiusLg),
            border: Border.all(
                color: AppTheme.mint.withValues(alpha: 0.25), width: 1),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.mintGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTheme.mintGlow,
                      blurRadius: 18,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded,
                      color: Color(0xFF052E1F), size: 26),
                ),
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
                            fontSize: 17,
                            letterSpacing: -0.3)),
                    SizedBox(height: 3),
                    Text('Solo spending · just for you',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.mint, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared group card ─────────────────────────────────────────────────────
class _GroupCard extends ConsumerWidget {
  final ExpenseGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(AppTheme.radiusLg),
          onTap: () => context.push('/groups/${group.id}'),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: const BorderRadius.all(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.ink2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border, width: 1),
                  ),
                  child: Center(
                      child: Text(group.emoji,
                          style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text('Tap to open',
                          style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textTertiary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state for shared groups ─────────────────────────────────────────
class _SharedEmptyState extends StatelessWidget {
  const _SharedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: const BorderRadius.all(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.ink2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: const Center(
                  child: Icon(Icons.group_outlined,
                      color: AppTheme.textSecondary, size: 26)),
            ),
            const SizedBox(height: 14),
            const Text('No shared groups yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Create one to split expenses with friends',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
