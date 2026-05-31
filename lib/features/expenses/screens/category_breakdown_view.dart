import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../models/expense_category.dart';
import '../providers/expenses_provider.dart';

/// Body-only widget for the personal group's "Categories" tab. Buckets
/// every expense by [ExpenseCategory] and shows a donut + sorted list.
///
/// Reuses `groupExpensesProvider` so it stays in sync with the Expenses tab.
class CategoryBreakdownView extends ConsumerWidget {
  final String groupId;
  const CategoryBreakdownView({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(groupId));

    return expensesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.mint)),
      error: (e, _) => Center(child: Text('$e')),
      data: (expenses) {
        if (expenses.isEmpty) return const _EmptyState();

        // Bucket totals by category. Settlements (description starts with
        // "Settled:") are excluded — they're transfers, not spending.
        final totals = <ExpenseCategory, double>{};
        double grand = 0;
        for (final e in expenses) {
          if (e.description.startsWith('Settled:')) continue;
          final cat = ExpenseCategory.fromCode(e.category);
          totals[cat] = (totals[cat] ?? 0) + e.amount;
          grand += e.amount;
        }
        if (totals.isEmpty) return const _EmptyState();

        final sorted = totals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return RefreshIndicator(
          color: AppTheme.mint,
          onRefresh: () =>
              ref.read(groupExpensesProvider(groupId).notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _DonutCard(sorted: sorted, total: grand),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text('BREAKDOWN',
                    style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              ...sorted.map((e) => _CategoryRow(
                    category: e.key,
                    amount: e.value,
                    pctOfTotal: grand == 0 ? 0 : e.value / grand,
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _DonutCard extends StatefulWidget {
  final List<MapEntry<ExpenseCategory, double>> sorted;
  final double total;
  const _DonutCard({required this.sorted, required this.total});

  @override
  State<_DonutCard> createState() => _DonutCardState();
}

class _DonutCardState extends State<_DonutCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final showing = (_touched >= 0 && _touched < widget.sorted.length)
        ? widget.sorted[_touched]
        : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: const BorderRadius.all(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 64,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touched = -1;
                        return;
                      }
                      _touched =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: [
                  for (int i = 0; i < widget.sorted.length; i++)
                    PieChartSectionData(
                      value: widget.sorted[i].value,
                      color: widget.sorted[i].key.color,
                      radius: i == _touched ? 78 : 66,
                      title: '',
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    showing == null
                        ? 'TOTAL'
                        : showing.key.label.toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(
                  CurrencyUtils.format(
                      showing?.value ?? widget.total,
                      currency: AppConstants.defaultCurrency),
                  style: AppTheme.moneyStyle(
                      fontSize: 22,
                      weight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
                if (showing != null && widget.total > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                      '${(showing.value / widget.total * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final ExpenseCategory category;
  final double amount;
  final double pctOfTotal;
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.pctOfTotal,
  });

  @override
  Widget build(BuildContext context) {
    final pctText = (pctOfTotal * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.all(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: category.color.withValues(alpha: 0.35),
                    width: 1),
              ),
              child: Center(
                child: Text(category.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.label,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pctOfTotal.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: AppTheme.ink3,
                            valueColor: AlwaysStoppedAnimation(
                                category.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$pctText%',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
                CurrencyUtils.format(amount,
                    currency: AppConstants.defaultCurrency),
                style: AppTheme.moneyStyle(
                    fontSize: 15, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.greenSubtle,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
              ),
              child: const Center(
                  child: Text('📊', style: TextStyle(fontSize: 38))),
            ),
            const SizedBox(height: 20),
            const Text('No spending yet',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Log an expense to see your\nspending broken down by category',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
