import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/progress_widgets.dart';

/// Body-weight entries ([MetricType.weight] metrics) over time.
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({
    super.key,
    required this.entries,
    required this.unitLabel,
    required this.caption,
  });

  /// Oldest first; at least one entry.
  final List<FitnessMetric> entries;
  final String unitLabel;
  final String caption;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final axis = chartAxisStyle(context);
    final first = entries.first;
    final last = entries.last;
    final unit = last.unit ?? unitLabel;
    final dateFmt = DateFormat('MMM d');

    // x = days since the first entry, so uneven logging keeps true spacing.
    double x(FitnessMetric m) =>
        m.date.difference(first.date).inHours / 24.0;
    final spots = [for (final m in entries) FlSpot(x(m), m.value)];
    final values = entries.map((m) => m.value);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV) * 0.2).clamp(1.0, double.infinity);
    final maxX = spots.last.x <= 0 ? 1.0 : spots.last.x;
    final change = last.value - first.value;

    return ProgressCard(
      title: 'Body weight',
      caption: caption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${_fmt(last.value)} $unit',
                style: theme.textTheme.titleLarge,
              ),
              if (entries.length > 1)
                TextSpan(
                  text: '  ${change >= 0 ? '↑' : '↓'} '
                      '${_fmt(change.abs())} $unit since '
                      '${dateFmt.format(first.date)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ]),
          ),
          const SizedBox(height: Gap.md),
          SizedBox(
            height: kProgressChartHeight,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: minV - pad,
                maxY: maxV + pad,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: scheme.outlineVariant, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) {
                          return const SizedBox.shrink();
                        }
                        return Text(value.round().toString(), style: axis);
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: maxX,
                      getTitlesWidget: (value, meta) {
                        final date = value <= 0
                            ? first.date
                            : value >= maxX && entries.length > 1
                                ? last.date
                                : null;
                        if (date == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: Gap.xs),
                          child: Text(dateFmt.format(date), style: axis),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touched) => [
                      for (final s in touched)
                        LineTooltipItem(
                          '${dateFmt.format(entries[s.spotIndex].date)}\n'
                          '${_fmt(s.y)} $unit',
                          TextStyle(color: scheme.onInverseSurface),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: scheme.secondary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: scheme.secondary,
                        strokeWidth: 2,
                        strokeColor: scheme.surfaceContainerLow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
