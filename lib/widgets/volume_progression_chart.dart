import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/services/weight_tracking_service.dart';

/// Chart widget specifically for volume progression tracking
class VolumeProgressionChart extends StatefulWidget {
  final List<Workout> workouts;
  final String title;

  const VolumeProgressionChart({
    super.key,
    required this.workouts,
    this.title = 'Volume Progression',
  });

  @override
  State<VolumeProgressionChart> createState() => _VolumeProgressionChartState();
}

class _VolumeProgressionChartState extends State<VolumeProgressionChart> {
  WeightTrackingPeriod _selectedPeriod = WeightTrackingPeriod.weekly;
  bool _showCumulative = false;
  bool _showTrendLine = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
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
                PopupMenuButton<WeightTrackingPeriod>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (period) {
                    setState(() {
                      _selectedPeriod = period;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: WeightTrackingPeriod.weekly,
                      child: Text('Weekly'),
                    ),
                    const PopupMenuItem(
                      value: WeightTrackingPeriod.monthly,
                      child: Text('Monthly'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Toggle buttons
            Row(
              children: [
                Expanded(
                  child: Row(
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
                      const Text('Cumulative'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: _showTrendLine,
                        onChanged: (value) {
                          setState(() {
                            _showTrendLine = value;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('Trend'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Chart
            SizedBox(
              height: 250,
              child: _buildChart(context),
            ),

            const SizedBox(height: 16),

            // Statistics
            _buildStatistics(context),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
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
              Icons.trending_up,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No volume data available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete some workouts to see your volume progression!',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final spots = data.entries.toList().asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    // Calculate trend line if enabled
    List<FlSpot>? trendSpots;
    if (_showTrendLine && spots.length > 1) {
      trendSpots = _calculateTrendLine(spots);
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: null,
          verticalInterval: null,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatWeight(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final entry = data.entries.toList()[index];
                  return Text(
                    _formatPeriodLabel(entry.key),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: spots.isEmpty
            ? 100
            : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1,
        lineBarsData: [
          // Main data line
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
          // Trend line
          if (trendSpots != null)
            LineChartBarData(
              spots: trendSpots,
              isCurved: false,
              color: Colors.orange,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: [5, 5],
            ),
        ],
      ),
    );
  }

  Widget _buildStatistics(BuildContext context) {
    final stats = WeightTrackingService.getWeightTrackingStats(widget.workouts);
    final data = WeightTrackingService.getWeightLiftedByPeriod(
        widget.workouts, _selectedPeriod);

    // Calculate progression percentage
    double progressionPercentage = 0.0;
    if (data.length >= 2) {
      final values = data.values.toList();
      final firstValue = values.first;
      final lastValue = values.last;
      if (firstValue > 0) {
        progressionPercentage = ((lastValue - firstValue) / firstValue) * 100;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Volume',
            _formatWeight(stats.totalWeightLifted),
            Icons.fitness_center,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Avg/Workout',
            _formatWeight(stats.averagePerWorkout),
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Progression',
            '${progressionPercentage.toStringAsFixed(1)}%',
            progressionPercentage >= 0
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            progressionPercentage >= 0 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _calculateTrendLine(List<FlSpot> spots) {
    if (spots.length < 2) return [];

    // Simple linear regression
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    final n = spots.length;

    for (final spot in spots) {
      sumX += spot.x;
      sumY += spot.y;
      sumXY += spot.x * spot.y;
      sumXX += spot.x * spot.x;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    return [
      FlSpot(spots.first.x, slope * spots.first.x + intercept),
      FlSpot(spots.last.x, slope * spots.last.x + intercept),
    ];
  }

  String _formatWeight(double weight) {
    if (weight >= 1000000) {
      return '${(weight / 1000000).toStringAsFixed(1)}M';
    } else if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(1)}K';
    } else {
      return weight.toStringAsFixed(0);
    }
  }

  String _formatPeriodLabel(String period) {
    if (_selectedPeriod == WeightTrackingPeriod.weekly) {
      // Format: "Week of Jan 1"
      return period.length > 8 ? period.substring(0, 8) : period;
    } else {
      // Format: "Jan 2024"
      return period.length > 8 ? period.substring(0, 8) : period;
    }
  }
}
