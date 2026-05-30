import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../../shared/repositories/expenses_repository.dart';
import '../../../shared/repositories/groups_repository.dart';
import '../../../shared/repositories/profiles_repository.dart';
import '../../../shared/repositories/supabase_client.dart';
import '../../auth/models/app_user.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/groups_provider.dart';
import '../providers/balances_provider.dart';
import '../settle_flow.dart';
import '../../expenses/providers/expenses_provider.dart';

/// Aggregated outstanding payments across every group the user belongs to.
///
/// Each entry is a [SettleEntry] — already simplified per group, filtered to
/// payments involving the current user (as debtor OR creditor), with the
/// other party's profile resolved so we can render Revolut/Bizum options.
class SettleEntry {
  final ExpenseGroup group;
  final String fromUserId;
  final String toUserId;
  final AppUser otherUser; // the non-current-user party
  final String otherName;
  final double amount;

  /// True if the current user is the debtor (they need to pay).
  final bool youOwe;

  const SettleEntry({
    required this.group,
    required this.fromUserId,
    required this.toUserId,
    required this.otherUser,
    required this.otherName,
    required this.amount,
    required this.youOwe,
  });
}

final allSettlementsProvider = FutureProvider<List<SettleEntry>>((ref) async {
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return [];

  final groups = await ref.watch(groupsProvider.future);
  if (groups.isEmpty) return [];

  final expensesRepo = ExpensesRepository();
  final groupsRepo = GroupsRepository();
  final profilesRepo = ProfilesRepository();

  // Cache profiles across groups so we don't re-fetch the same user.
  final profileCache = <String, AppUser>{};

  final result = <SettleEntry>[];

  // Process groups in parallel for snappier loading on many groups.
  await Future.wait(groups.map((group) async {
    final raw = await expensesRepo.computeBalances(group.id);
    final payments = DebtSimplifier.simplify(raw);

    // Only payments involving me.
    final mine = payments
        .where((p) => p.from == myId || p.to == myId)
        .toList();
    if (mine.isEmpty) return;

    // Member list is cheaper than a profile fetch when we just need names.
    final members = await groupsRepo.getGroupMembers(group.id);
    final byId = {for (final m in members) m.user.id: m.user};

    for (final p in mine) {
      final otherId = p.from == myId ? p.to : p.from;
      AppUser? other = byId[otherId];
      // Members list joins profiles, so this should normally be populated.
      // Fall back to a direct profile fetch if not (e.g. user left the group
      // after creating the expense).
      if (other == null) {
        other = profileCache[otherId] ??
            await profilesRepo.getProfile(otherId);
        if (other == null) continue;
        profileCache[otherId] = other;
      }
      result.add(SettleEntry(
        group: group,
        fromUserId: p.from,
        toUserId: p.to,
        otherUser: other,
        otherName: other.displayName,
        amount: p.amount,
        youOwe: p.from == myId,
      ));
    }
  }));

  // Sort: things you owe first (more urgent for the user), bigger first.
  result.sort((a, b) {
    if (a.youOwe != b.youOwe) return a.youOwe ? -1 : 1;
    return b.amount.compareTo(a.amount);
  });

  return result;
});

class SettleAllScreen extends ConsumerWidget {
  const SettleAllScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(allSettlementsProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Things to Settle',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: () => ref.invalidate(allSettlementsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.green,
        onRefresh: () async {
          ref.invalidate(allSettlementsProvider);
          await ref.read(allSettlementsProvider.future);
        },
        child: entriesAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.green)),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error: $e',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
          data: (entries) {
            if (entries.isEmpty) return ListView(children: const [_AllClear()]);

            final youOwe = entries.where((e) => e.youOwe).toList();
            final owedToYou = entries.where((e) => !e.youOwe).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _Summary(youOwe: youOwe, owedToYou: owedToYou),
                const SizedBox(height: 20),
                if (youOwe.isNotEmpty) ...[
                  _SectionLabel(label: 'You owe'),
                  const SizedBox(height: 8),
                  ...youOwe.map((e) => _SettleRow(entry: e, ref: ref)),
                  const SizedBox(height: 20),
                ],
                if (owedToYou.isNotEmpty) ...[
                  _SectionLabel(label: 'Owed to you'),
                  const SizedBox(height: 8),
                  ...owedToYou.map((e) => _SettleRow(entry: e, ref: ref)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<SettleEntry> youOwe;
  final List<SettleEntry> owedToYou;
  const _Summary({required this.youOwe, required this.owedToYou});

  @override
  Widget build(BuildContext context) {
    final outgoing = youOwe.fold<double>(0, (s, e) => s + e.amount);
    final incoming = owedToYou.fold<double>(0, (s, e) => s + e.amount);
    final net = incoming - outgoing;
    final netPositive = net >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Net position',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            '${netPositive ? '+' : ''}${CurrencyUtils.format(net, currency: AppConstants.defaultCurrency)}',
            style: TextStyle(
                color: netPositive ? AppTheme.positive : AppTheme.negative,
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Sub(
                  label: 'You owe',
                  amount: outgoing,
                  count: youOwe.length,
                  color: AppTheme.negative,
                ),
              ),
              Container(
                  width: 1, height: 40, color: AppTheme.border),
              Expanded(
                child: _Sub(
                  label: 'Owed to you',
                  amount: incoming,
                  count: owedToYou.length,
                  color: AppTheme.positive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sub extends StatelessWidget {
  final String label;
  final double amount;
  final int count;
  final Color color;
  const _Sub({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(CurrencyUtils.format(amount, currency: AppConstants.defaultCurrency),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Text('${count} ${count == 1 ? "payment" : "payments"}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)),
    );
  }
}

class _SettleRow extends StatelessWidget {
  final SettleEntry entry;
  final WidgetRef ref;
  const _SettleRow({required this.entry, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color =
        entry.youOwe ? AppTheme.negative : AppTheme.positive;
    final groupLabel =
        entry.group.isPersonal ? 'My Expenses' : entry.group.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  entry.youOwe
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: entry.youOwe ? 'Pay ' : 'Collect from ',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      TextSpan(
                          text: entry.otherName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(entry.group.emoji,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(groupLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyUtils.format(entry.amount,
                      currency: AppConstants.defaultCurrency),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16),
                ),
                const SizedBox(height: 6),
                _SettleButton(entry: entry, ref: ref),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettleButton extends StatelessWidget {
  final SettleEntry entry;
  final WidgetRef ref;
  const _SettleButton({required this.entry, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: entry.youOwe ? AppTheme.green : AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          // The settle sheet records the payment; once it returns, refresh
          // this aggregated view too.
          await showSettleSheet(
            context: context,
            ref: ref,
            groupId: entry.group.id,
            fromUserId: entry.fromUserId,
            toUserId: entry.toUserId,
            fromName:
                entry.youOwe ? 'You' : entry.otherName,
            toName: entry.youOwe ? entry.otherName : 'You',
            amount: entry.amount,
          );
          ref.invalidate(allSettlementsProvider);
          ref.invalidate(groupExpensesProvider(entry.group.id));
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: entry.youOwe
                ? null
                : Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Text(
            entry.youOwe ? 'Pay' : 'Mark received',
            style: TextStyle(
                color: entry.youOwe ? Colors.black : AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.greenSubtle,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: const Center(child: Text('✅', style: TextStyle(fontSize: 48))),
          ),
          const SizedBox(height: 24),
          const Text('All settled up',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
              'No outstanding debts across any of your groups.\nNice 👌',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
