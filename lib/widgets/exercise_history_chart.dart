import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/services/progression_coach.dart';

/// Rounds to one decimal place (for displaying estimated values).
double roundTo1(double value) => (value * 10).round() / 10;

/// Time window shown by [ExerciseHistoryChart].
enum HistoryRange { threeMonths, oneYear, all }

/// Value plotted per session by [ExerciseHistoryChart].
enum HistoryMetric { e1rm, topSetWeight }

/// Line chart of one exercise's sessions over time: best estimated 1RM (or
/// top-set weight) per session, with range and metric toggles. Points can be
/// tapped to show the date and value.
class ExerciseHistoryChart extends StatefulWidget {
  const ExerciseHistoryChart({
    super.key,
    required this.sessions,
    required this.coach,
    this.plateau = false,
    this.now,
  });

  /// Sessions for the exercise, any order.
  final List<SessionSummary> sessions;
  final ProgressionCoach coach;

  /// Show a subtle plateau note under the chart.
  final bool plateau;

  /// Reference time for the range filter (defaults to now).
  final DateTime? now;

  @override
  State<ExerciseHistoryChart> createState() => _ExerciseHistoryChartState();
}

class _ExerciseHistoryChartState extends State<ExerciseHistoryChart> {
  HistoryRange _range = HistoryRange.threeMonths;
  HistoryMetric _metric = HistoryMetric.e1rm;

  static const _dayMs = 86400000.0;

  List<SessionSummary> _visibleSessions() {
    final now = widget.now ?? DateTime.now();
    final DateTime? cutoff = switch (_range) {
      HistoryRange.threeMonths => now.subtract(const Duration(days: 91)),
      HistoryRange.oneYear => now.subtract(const Duration(days: 365)),
      HistoryRange.all => null,
    };
    final list = widget.sessions
        .where((s) => cutoff == null || !s.date.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  double _valueOf(SessionSummary s) =>
      _metric == HistoryMetric.e1rm ? s.bestE1rm : s.topSet.weight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final visible = _visibleSessions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SegmentedButton<HistoryRange>(
              key: const Key('history-range-toggle'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: HistoryRange.threeMonths, label: Text('3 mo')),
                ButtonSegment(value: HistoryRange.oneYear, label: Text('1 yr')),
                ButtonSegment(value: HistoryRange.all, label: Text('All')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            SegmentedButton<HistoryMetric>(
              key: const Key('history-metric-toggle'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: HistoryMetric.e1rm, label: Text('e1RM')),
                ButtonSegment(
                    value: HistoryMetric.topSetWeight, label: Text('Top set')),
              ],
              selected: {_metric},
              onSelectionChanged: (s) => setState(() => _metric = s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'No sessions in this range',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : _buildChart(context, visible),
        ),
        const SizedBox(height: 4),
        Text(
          _metric == HistoryMetric.e1rm
              ? 'Best estimated 1RM per session (${widget.coach.unit})'
              : 'Top-set weight per session (${widget.coach.unit})',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        if (widget.plateau) ...[
          const SizedBox(height: 8),
          Row(
            key: const Key('history-plateau-note'),
            children: [
              Icon(Icons.trending_flat,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Progress has levelled off over your last few sessions.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChart(BuildContext context, List<SessionSummary> visible) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(color: scheme.onSurfaceVariant, fontSize: 10);

    final spots = [
      for (final s in visible)
        FlSpot(s.date.millisecondsSinceEpoch / _dayMs, _valueOf(s)),
    ];

    var minX = spots.first.x;
    var maxX = spots.last.x;
    if (maxX - minX < 1) {
      minX -= 1;
      maxX += 1;
    }
    final values = spots.map((s) => s.y);
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final pad = math.max((rawMax - rawMin) * 0.15, math.max(rawMax * 0.05, 1));
    final minY = math.max(0.0, rawMin - pad);
    final maxY = rawMax + pad;
    final yInterval = (maxY - minY) / 4;
    final xInterval = (maxX - minX) / 2;

    String axisDate(double x) => DateFormat.MMMd()
        .format(DateTime.fromMillisecondsSinceEpoch((x * _dayMs).round()));

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                      ProgressionCoach.formatNumber(value.roundToDouble()),
                      style: labelStyle),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(axisDate(value), style: labelStyle),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (touched) => touched.map((spot) {
              final session = visible[spot.spotIndex];
              return LineTooltipItem(
                '${DateFormat.yMMMd().format(session.date)}\n'
                '${widget.coach.formatWeight(roundTo1(_valueOf(session)))}',
                TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: scheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: scheme.primary,
                strokeWidth: 2,
                strokeColor: scheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
