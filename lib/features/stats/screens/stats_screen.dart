import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/models/group.dart';
import '../../../shared/repositories/expenses_repository.dart';

/// Spending per group for the current user, computed by summing the user's
/// share of every expense they're a participant of.
final spendingByGroupProvider = FutureProvider<Map<String, double>>((ref) {
  return ExpensesRepository().getUserSpendingByGroup();
});

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(spendingByGroupProvider);
    final groupsAsync = ref.watch(groupsProvider);

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
        title: const Text('Statistics',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
      ),
      body: RefreshIndicator(
        color: AppTheme.green,
        onRefresh: () async {
          ref.invalidate(spendingByGroupProvider);
          await ref.read(groupsProvider.notifier).refresh();
        },
        child: spendingAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.green)),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppTheme.textSecondary))),
          data: (spending) {
            return groupsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.green)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (groups) =>
                  _StatsView(groups: groups, spendingByGroup: spending),
            );
          },
        ),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  final List<ExpenseGroup> groups;
  final Map<String, double> spendingByGroup;

  const _StatsView({required this.groups, required this.spendingByGroup});

  @override
  Widget build(BuildContext context) {
    // Build segments: only groups with non-zero spending.
    final segments = <_Segment>[];
    double total = 0;
    double personalTotal = 0;
    double sharedTotal = 0;

    for (final g in groups) {
      final amount = spendingByGroup[g.id] ?? 0;
      if (amount <= 0) continue;
      segments.add(_Segment(group: g, amount: amount));
      total += amount;
      if (g.isPersonal) {
        personalTotal += amount;
      } else {
        sharedTotal += amount;
      }
    }

    segments.sort((a, b) => b.amount.compareTo(a.amount));

    // Assign colors. Personal group gets the brand green; others rotate through
    // a palette so they're visually distinct in the pie.
    final palette = _palette(segments.length);
    for (int i = 0; i < segments.length; i++) {
      segments[i] = segments[i].copyWith(color: palette[i]);
    }

    if (segments.isEmpty) {
      return ListView(
        children: const [_EmptyStats()],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _SummaryRow(
          total: total,
          personalTotal: personalTotal,
          sharedTotal: sharedTotal,
        ),
        const SizedBox(height: 24),
        _PieCard(segments: segments, total: total),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text('Breakdown',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5)),
        ),
        ...segments.map((s) =>
            _GroupBreakdownTile(segment: s, totalAcrossGroups: total)),
      ],
    );
  }

  static List<Color> _palette(int n) {
    const colors = <Color>[
      AppTheme.green,
      Color(0xFF00BCD4), // cyan
      Color(0xFFFFD600), // amber
      Color(0xFFFF6E40), // deep orange
      Color(0xFFAB47BC), // purple
      Color(0xFF42A5F5), // blue
      Color(0xFFEC407A), // pink
      Color(0xFF66BB6A), // soft green
    ];
    return List.generate(n, (i) => colors[i % colors.length]);
  }
}

class _SummaryRow extends StatelessWidget {
  final double total;
  final double personalTotal;
  final double sharedTotal;
  const _SummaryRow({
    required this.total,
    required this.personalTotal,
    required this.sharedTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
                label: 'Total',
                value: total,
                emphasis: true,
                accent: AppTheme.green)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                label: 'Personal',
                value: personalTotal,
                accent: AppTheme.green)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                label: 'Shared',
                value: sharedTotal,
                accent: const Color(0xFF00BCD4))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasis;
  final Color accent;
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: emphasis ? AppTheme.greenSubtle : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: emphasis
                ? AppTheme.green.withValues(alpha: 0.35)
                : AppTheme.border,
            width: 0.5),
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
                      color: accent, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.format(value, currency: AppConstants.defaultCurrency),
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: emphasis ? 18 : 16,
                letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}

class _PieCard extends StatefulWidget {
  final List<_Segment> segments;
  final double total;
  const _PieCard({required this.segments, required this.total});

  @override
  State<_PieCard> createState() => _PieCardState();
}

class _PieCardState extends State<_PieCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: [
                      for (int i = 0; i < widget.segments.length; i++)
                        _section(widget.segments[i], i),
                    ],
                  ),
                ),
                _CenterLabel(
                    touchedIndex: _touchedIndex,
                    segments: widget.segments,
                    total: widget.total),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _section(_Segment seg, int index) {
    final isTouched = index == _touchedIndex;
    final radius = isTouched ? 76.0 : 64.0;
    return PieChartSectionData(
      color: seg.color,
      value: seg.amount,
      title: '',
      radius: radius,
      borderSide: isTouched
          ? BorderSide(color: seg.color.withValues(alpha: 0.6), width: 4)
          : BorderSide.none,
    );
  }
}

class _CenterLabel extends StatelessWidget {
  final int touchedIndex;
  final List<_Segment> segments;
  final double total;
  const _CenterLabel({
    required this.touchedIndex,
    required this.segments,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final showing = touchedIndex >= 0 && touchedIndex < segments.length
        ? segments[touchedIndex]
        : null;
    final amount = showing?.amount ?? total;
    final label = showing == null
        ? 'Total'
        : (showing.group.isPersonal ? 'My Expenses' : showing.group.name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          CurrencyUtils.format(amount, currency: AppConstants.defaultCurrency),
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
        ),
        if (showing != null && total > 0) ...[
          const SizedBox(height: 2),
          Text('${(showing.amount / total * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _GroupBreakdownTile extends StatelessWidget {
  final _Segment segment;
  final double totalAcrossGroups;
  const _GroupBreakdownTile(
      {required this.segment, required this.totalAcrossGroups});

  @override
  Widget build(BuildContext context) {
    final pct = totalAcrossGroups > 0
        ? (segment.amount / totalAcrossGroups * 100)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/groups/${segment.group.id}'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: segment.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: segment.color.withValues(alpha: 0.4),
                        width: 1),
                  ),
                  child: Center(
                      child: Text(segment.group.emoji,
                          style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          segment.group.isPersonal
                              ? 'My Expenses'
                              : segment.group.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            height: 4,
                            width: 60,
                            decoration: BoxDecoration(
                                color: AppTheme.border,
                                borderRadius: BorderRadius.circular(2)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (pct / 100).clamp(0.02, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: segment.color,
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                    CurrencyUtils.format(segment.amount,
                        currency: AppConstants.defaultCurrency),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.greenSubtle,
              borderRadius: BorderRadius.circular(32),
              border:
                  Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child:
                const Center(child: Text('📊', style: TextStyle(fontSize: 48))),
          ),
          const SizedBox(height: 24),
          const Text('No spending yet',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
              'Add some expenses and come back to\nsee where your money goes',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _Segment {
  final ExpenseGroup group;
  final double amount;
  final Color color;
  const _Segment({
    required this.group,
    required this.amount,
    this.color = AppTheme.green,
  });

  _Segment copyWith({Color? color}) => _Segment(
        group: group,
        amount: amount,
        color: color ?? this.color,
      );
}
