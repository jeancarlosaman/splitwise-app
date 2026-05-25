import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/balances_provider.dart';
import '../models/balance.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/user_avatar.dart';

class BalancesScreen extends ConsumerWidget {
  const BalancesScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(groupBalancesProvider(groupId));

    return Scaffold(
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
        loading: () => const InlineLoader(message: 'Computing balances…'),
        error:   (e, _) => ErrorView(message: e.toString()),
        data:    (balances) => _BalancesView(balances: balances),
      ),
    );
  }
}

class _BalancesView extends StatelessWidget {
  const _BalancesView({required this.balances});

  final GroupBalances balances;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // All settled banner
        if (balances.isAllSettled)
          _AllSettledBanner()
        else ...[
          // Net balances section
          Text(
            'Net Balances',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...balances.userBalances.map((ub) => _BalanceTile(balance: ub)),

          const SizedBox(height: 24),

          // Settlements section
          Text(
            'Suggested Payments',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Minimum transactions to settle all debts',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...balances.settlements
              .map((s) => _SettlementCard(settlement: s)),
        ],
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.balance});

  final UserBalance balance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color amountColor;
    String label;
    IconData icon;

    if (balance.isCreditor) {
      amountColor = const Color(0xFF2E7D32);
      label       = 'gets back';
      icon        = Icons.arrow_downward_rounded;
    } else if (balance.isDebtor) {
      amountColor = const Color(0xFFC62828);
      label       = 'owes';
      icon        = Icons.arrow_upward_rounded;
    } else {
      amountColor = cs.onSurfaceVariant;
      label       = 'settled up';
      icon        = Icons.check_circle_outline_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              UserAvatar(user: balance.user, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.user.name,
                      style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      label,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(icon, color: amountColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    CurrencyUtils.formatCompact(
                        balance.amount.abs(), balance.currency),
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: amountColor,
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
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({required this.settlement});

  final SettlementSuggestion settlement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // From user
              Column(
                children: [
                  UserAvatar(user: settlement.from, radius: 22),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    child: Text(
                      settlement.from.name,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Arrow + amount
              Expanded(
                child: Column(
                  children: [
                    Text(
                      CurrencyUtils.formatAmount(
                          settlement.amount, settlement.currency),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: cs.primary.withValues(alpha: 0.4)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: cs.primary,
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: Divider(color: cs.primary.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    Text(
                      'pays',
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              // To user
              Column(
                children: [
                  UserAvatar(user: settlement.to, radius: 22),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    child: Text(
                      settlement.to.name,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

class _AllSettledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2E7D32),
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            'All settled up!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'No outstanding debts in this group.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
