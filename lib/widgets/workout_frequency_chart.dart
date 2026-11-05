import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/progress_period.dart';
import 'package:testfitness/ui/progress_widgets.dart';

/// Workouts per bucket of the selected [PeriodWindow] as labelled bars.
class WorkoutFrequencyChart extends StatelessWidget {
  const WorkoutFrequencyChart({
    super.key,
    required this.window,
    required this.counts,
  });

  final PeriodWindow window;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final axis = chartAxisStyle(context);
    final buckets = window.buckets;
    final maxCount = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
    final maxY = (maxCount < 3 ? 3 : maxCount + 1).toDouble();
    final labelEvery = (buckets.length / 4).ceil().clamp(1, 1000);
    final total = counts.fold<int>(0, (a, b) => a + b);
    final average = buckets.isEmpty ? 0.0 : total / buckets.length;

    return ProgressCard(
      title: 'Consistency',
      caption: 'Workouts per ${window.unit} · avg '
          '${average.toStringAsFixed(1)}',
      child: SizedBox(
        height: kProgressChartHeight,
        child: Semantics(
          label: 'Workouts per ${window.unit} chart, $total workouts in '
              '${buckets.length} ${window.unit}s',
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY / 3).ceilToDouble(),
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: scheme.outlineVariant, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (maxY / 3).ceilToDouble(),
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max) return const SizedBox.shrink();
                      return Text(value.round().toString(), style: axis);
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 ||
                          i >= buckets.length ||
                          (buckets.length - 1 - i) % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: Gap.xs),
                        child: Text(buckets[i].label, style: axis),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final n = rod.toY.round();
                    return BarTooltipItem(
                      '${buckets[group.x].label}\n'
                      '$n workout${n == 1 ? '' : 's'}',
                      TextStyle(color: scheme.onInverseSurface),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < counts.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: scheme.primary,
                        width: buckets.length > 16 ? 6 : 12,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
