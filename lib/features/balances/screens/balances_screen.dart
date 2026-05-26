import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/balances_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../../core/utils/currency_utils.dart';
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
      appBar: AppBar(
        title: const Text('Balances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(groupBalancesProvider(groupId)),
          ),
        ],
      ),
      body: balancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (balances) {
          final members = membersAsync.value ?? [];
          String nameFor(String userId) {
            if (userId == myId) return 'You';
            return members
                    .firstWhere(
                      (m) => m.user.id == userId,
                      orElse: () => throw '',
                    )
                    .user
                    .displayName;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Net balances ──────────────────────────────────────
              Text('Net Balances',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (balances.netBalances.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No balances yet. Add some expenses!'),
                  ),
                )
              else
                ...balances.netBalances.entries.map((entry) {
                  final isPositive = entry.value >= 0;
                  String label;
                  try {
                    label = nameFor(entry.key);
                  } catch (_) {
                    label = entry.key.substring(0, 8);
                  }
                  return Card(
                    child: ListTile(
                      title: Text(label),
                      trailing: Text(
                        (isPositive ? '+' : '') +
                            CurrencyUtils.format(entry.value),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      subtitle: Text(isPositive
                          ? 'is owed money'
                          : 'owes money'),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // ── Suggested settlements ─────────────────────────────
              Text('Suggested Payments',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (balances.settlements.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Everyone is settled up! 🎉'),
                  ),
                )
              else
                ...balances.settlements.map((payment) {
                  String fromLabel, toLabel;
                  try {
                    fromLabel = nameFor(payment.from);
                  } catch (_) {
                    fromLabel = payment.from.substring(0, 8);
                  }
                  try {
                    toLabel = nameFor(payment.to);
                  } catch (_) {
                    toLabel = payment.to.substring(0, 8);
                  }

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.arrow_forward,
                          color: Colors.orange),
                      title: Text('$fromLabel pays $toLabel'),
                      trailing: Text(
                        CurrencyUtils.format(payment.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
