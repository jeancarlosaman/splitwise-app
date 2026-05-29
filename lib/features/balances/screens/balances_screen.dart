import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/balances_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/theme.dart';
import '../../../shared/repositories/supabase_client.dart';

class BalancesScreen extends ConsumerWidget {
  final String groupId;
  const BalancesScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(groupBalancesProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));
    final myId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('Balances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(groupBalancesProvider(groupId)),
          ),
        ],
      ),
      body: balancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => Center(child: Text('$e')),
        data: (balances) {
          final members = membersAsync.value ?? [];
          String nameFor(String userId) {
            if (userId == myId) return 'You';
            try {
              return members.firstWhere((m) => m.user.id == userId).user.displayName;
            } catch (_) {
              return userId.substring(0, 8);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Net balances ────────────────────────────────
              _SectionHeader(title: 'Net Balances', icon: Icons.bar_chart_rounded),
              const SizedBox(height: 10),
              if (balances.netBalances.isEmpty)
                _EmptyCard(message: 'No balances yet. Add some expenses!')
              else
                ...balances.netBalances.entries.map((entry) {
                  final isPositive = entry.value >= 0;
                  final label = nameFor(entry.key);
                  return _BalanceCard(
                    name: label,
                    amount: entry.value,
                    isPositive: isPositive,
                    subtitle: isPositive ? 'is owed money' : 'owes money',
                  );
                }),

              const SizedBox(height: 28),

              // ── Suggested settlements ────────────────────────
              _SectionHeader(title: 'Suggested Payments', icon: Icons.swap_horiz_rounded),
              const SizedBox(height: 10),
              if (balances.settlements.isEmpty)
                _EmptyCard(message: 'Everyone is settled up! 🎉')
              else
                ...balances.settlements.map((payment) {
                  final fromLabel = nameFor(payment.from);
                  final toLabel = nameFor(payment.to);
                  return _SettlementCard(
                    from: fromLabel, to: toLabel, amount: payment.amount);
                }),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppTheme.greenSubtle,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.green, size: 17),
      ),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700, fontSize: 16)),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border, width: 0.5),
    ),
    child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
  );
}

class _BalanceCard extends StatelessWidget {
  final String name, subtitle;
  final double amount;
  final bool isPositive;
  const _BalanceCard({required this.name, required this.amount,
      required this.isPositive, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppTheme.positive : AppTheme.negative;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: color, size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            (isPositive ? '+' : '') + CurrencyUtils.format(amount),
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final String from, to;
  final double amount;
  const _SettlementCard({required this.from, required this.to, required this.amount});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border, width: 0.5),
    ),
    child: Row(
      children: [
        const Icon(Icons.send_rounded, color: AppTheme.amber, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: from,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              const TextSpan(text: ' pays ',
                  style: TextStyle(color: AppTheme.textSecondary)),
              TextSpan(text: to,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        Text(CurrencyUtils.format(amount),
            style: const TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    ),
  );
}
