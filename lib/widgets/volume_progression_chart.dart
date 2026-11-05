import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/progress_period.dart';
import 'package:testfitness/ui/progress_widgets.dart';

/// Training volume (weight × reps of completed working sets) per bucket of
/// the selected [PeriodWindow], with a dashed linear trend line and an
/// optional cumulative view. Values are computed by the caller
/// ([ProgressMath.volumePerBucket]) so the chart stays presentational.
class VolumeProgressionChart extends StatefulWidget {
  const VolumeProgressionChart({
    super.key,
    required this.window,
    required this.values,
    required this.unitLabel,
    this.title = 'Training volume',
  });

  final PeriodWindow window;
  final List<double> values;

  /// Lower-case unit, e.g. "lbs".
  final String unitLabel;
  final String title;

  @override
  State<VolumeProgressionChart> createState() => _VolumeProgressionChartState();
}

class _VolumeProgressionChartState extends State<VolumeProgressionChart> {
  bool _cumulative = false;

  List<double> get _series {
    if (!_cumulative) return widget.values;
    var running = 0.0;
    return [for (final v in widget.values) running += v];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = _series;
    final trend = values.length > 2 ? _trendLine(values) : null;

    return ProgressCard(
      title: widget.title,
      caption: _cumulative
          ? 'Running total of weight × reps, ${widget.window.period.description}'
          : 'Weight × reps per ${widget.window.unit}, '
              '${widget.window.period.description}',
      trailing: FilterChip(
        key: const Key('volume_cumulative_chip'),
        label: const Text('Total'),
        tooltip: 'Show running total',
        selected: _cumulative,
        onSelected: (v) => setState(() => _cumulative = v),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: kProgressChartHeight,
            child: Semantics(
              label: '${widget.title} chart, ${values.length} '
                  '${widget.window.unit}s, latest '
                  '${ProgressMath.formatVolume(values.isEmpty ? 0 : values.last)} '
                  '${widget.unitLabel}',
              child: LineChart(_data(context, values, trend)),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.lg,
            runSpacing: Gap.xs,
            children: [
              ChartLegendItem(
                  color: scheme.primary,
                  label: 'Volume (${widget.unitLabel})'),
              if (trend != null)
                ChartLegendItem(
                    color: scheme.tertiary, label: 'Trend', dashed: true),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _data(
      BuildContext context, List<double> values, List<FlSpot>? trend) {
    final scheme = Theme.of(context).colorScheme;
    final axis = chartAxisStyle(context);
    final buckets = widget.window.buckets;
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final maxValue =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 100.0 : maxValue * 1.15;
    final single = spots.length == 1;
    final labelEvery = (buckets.length / 4).ceil().clamp(1, 1000);

    return LineChartData(
      minX: single ? -0.5 : 0,
      maxX: single ? 0.5 : (spots.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: scheme.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: maxY / 4,
            getTitlesWidget: (value, meta) {
              if (value == meta.max) return const SizedBox.shrink();
              return Text(ProgressMath.formatAxis(value), style: axis);
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final i = value.round();
              if (value != i || i < 0 || i >= buckets.length) {
                return const SizedBox.shrink();
              }
              // Anchor labels on the latest bucket so it is always shown.
              if ((buckets.length - 1 - i) % labelEvery != 0) {
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
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => scheme.inverseSurface,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (touched) => [
            for (final s in touched)
              s.barIndex == 0
                  ? LineTooltipItem(
                      '${buckets[s.x.round()].label}\n'
                      '${ProgressMath.formatVolume(s.y)} ${widget.unitLabel}',
                      TextStyle(color: scheme.onInverseSurface),
                    )
                  : null,
          ],
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
              radius: 3.5,
              color: scheme.primary,
              strokeWidth: 2,
              strokeColor: scheme.surfaceContainerLow,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: scheme.primary.withValues(alpha: 0.12),
          ),
        ),
        if (trend != null)
          LineChartBarData(
            spots: trend,
            color: scheme.tertiary,
            barWidth: 2,
            dashArray: const [6, 4],
            dotData: const FlDotData(show: false),
          ),
      ],
    );
  }

  /// Least-squares line through the points.
  static List<FlSpot> _trendLine(List<double> values) {
    final n = values.length;
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (var i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumXX += i * i;
    }
    final denom = n * sumXX - sumX * sumX;
    if (denom == 0) return const [];
    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;
    double at(int x) => (slope * x + intercept).clamp(0, double.infinity);
    return [FlSpot(0, at(0)), FlSpot((n - 1).toDouble(), at(n - 1))];
  }
}
