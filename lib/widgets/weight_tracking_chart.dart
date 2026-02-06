import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/services/weight_tracking_service.dart';

/// Chart widget for displaying weight lifted over time with enhanced volume progression
class WeightTrackingChart extends StatefulWidget {
  final List<Workout> workouts;
  final String title;
  final WeightTrackingPeriod initialPeriod;
  final bool showVolumeProgression;

  const WeightTrackingChart({
    super.key,
    required this.workouts,
    this.title = 'Total Weight Lifted',
    this.initialPeriod = WeightTrackingPeriod.weekly,
    this.showVolumeProgression = false,
  });

  @override
  State<WeightTrackingChart> createState() => _WeightTrackingChartState();
}

class _WeightTrackingChartState extends State<WeightTrackingChart> {
  late WeightTrackingPeriod _selectedPeriod;
  bool _showCumulative = false;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final stats = WeightTrackingService.getWeightTrackingStats(widget.workouts);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and controls
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                // Period selector
                DropdownButton<WeightTrackingPeriod>(
                  value: _selectedPeriod,
                  onChanged: (period) {
                    if (period != null) {
                      setState(() {
                        _selectedPeriod = period;
                      });
                    }
                  },
                  items: WeightTrackingPeriod.values.map((period) {
                    return DropdownMenuItem(
                      value: period,
                      child: Text(_getPeriodDisplayName(period)),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Cumulative toggle
            Row(
              children: [
                Switch(
                  value: _showCumulative,
                  onChanged: (value) {
                    setState(() {
                      _showCumulative = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  _showCumulative ? 'Cumulative Total' : 'Period Totals',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Chart
            SizedBox(
              height: 200,
              child: _buildChart(context, stats),
            ),

            const SizedBox(height: 16),

            // Statistics summary
            _buildStatsSummary(context, stats),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, WeightTrackingStats stats) {
    final data = _showCumulative
        ? WeightTrackingService.getCumulativeWeightLifted(
            widget.workouts, _selectedPeriod)
        : WeightTrackingService.getWeightLiftedByPeriod(
            widget.workouts, _selectedPeriod);

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No workout data available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete some workouts to see your progress!',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = <FlSpot>[];
    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].value));
    }

    final maxY = data.values.isEmpty
        ? 1000.0
        : data.values.reduce((a, b) => a > b ? a : b);
    final minY =
        data.values.isEmpty ? 0.0 : data.values.reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedEntries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _formatAxisLabel(sortedEntries[index].key),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY / 4,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  stats.formatWeight(value, includeUnits: false),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        minX: 0,
        maxX: (sortedEntries.length - 1).toDouble(),
        minY: minY * 0.9,
        maxY: maxY * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(BuildContext context, WeightTrackingStats stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Lifted',
                  stats.formatWeight(stats.totalWeightLifted),
                  Icons.fitness_center,
                  context,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Avg/Workout',
                  stats.formatWeight(stats.averagePerWorkout),
                  Icons.trending_up,
                  context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Best Week',
                  stats.formatWeight(stats.bestWeek),
                  Icons.star,
                  context,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Heaviest Workout',
                  stats.formatWeight(stats.heaviestWorkout),
                  Icons.emoji_events,
                  context,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _getPeriodDisplayName(WeightTrackingPeriod period) {
    switch (period) {
      case WeightTrackingPeriod.daily:
        return '7 Days';
      case WeightTrackingPeriod.weekly:
        return '8 Weeks';
      case WeightTrackingPeriod.monthly:
        return '12 Months';
    }
  }

  String _formatAxisLabel(String key) {
    // Shorten labels for better display
    if (key.contains('/')) {
      return key; // Already short format like "12/25"
    } else if (key.contains(' ')) {
      final parts = key.split(' ');
      return parts[0]; // Just month name like "Jan"
    }
    return key;
  }
}
