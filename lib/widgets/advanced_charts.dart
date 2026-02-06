import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/exercise_repository.dart';

/// Advanced chart widgets for progress tracking
class AdvancedCharts {
  /// Create a line chart showing workout frequency over time
  static Widget buildWorkoutFrequencyChart(
    List<Workout> completedWorkouts,
    BuildContext context,
  ) {
    final chartData = _prepareFrequencyData(completedWorkouts);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Frequency Trend',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < chartData.length) {
                            return Text(
                              chartData[index].label,
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  minX: 0,
                  maxX: (chartData.length - 1).toDouble(),
                  minY: 0,
                  maxY: chartData.isEmpty
                      ? 5
                      : chartData
                              .map((e) => e.value)
                              .reduce((a, b) => a > b ? a : b) +
                          1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
                            Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create a pie chart showing exercise distribution
  static Widget buildExerciseDistributionChart(
    List<Workout> completedWorkouts,
    BuildContext context,
  ) {
    return FutureBuilder<List<ChartDataPoint>>(
      future: _prepareExerciseDistributionWithNames(completedWorkouts),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise Distribution',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise Distribution',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No exercise data available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final exerciseData = snapshot.data!;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exercise Distribution',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: PieTouchData(
                              touchCallback:
                                  (FlTouchEvent event, pieTouchResponse) {
                                // Handle touch events if needed
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: exerciseData.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              final colors = [
                                Colors.blue,
                                Colors.green,
                                Colors.orange,
                                Colors.purple,
                                Colors.red,
                                Colors.teal,
                              ];

                              return PieChartSectionData(
                                color: colors[index % colors.length],
                                value: data.value.toDouble(),
                                title: '${data.value.toInt()}',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: exerciseData.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            final colors = [
                              Colors.blue,
                              Colors.green,
                              Colors.orange,
                              Colors.purple,
                              Colors.red,
                              Colors.teal,
                            ];

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: colors[index % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      data.label,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Prepare frequency data for the last 30 days
  static List<ChartDataPoint> _prepareFrequencyData(
      List<Workout> completedWorkouts) {
    final now = DateTime.now();
    final data = <ChartDataPoint>[];

    // Group by week for the last 8 weeks
    for (int i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final workoutsInWeek = completedWorkouts.where((workout) {
        if (workout.completedDate == null) return false;
        final date = workout.completedDate!;
        return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            date.isBefore(weekEnd.add(const Duration(days: 1)));
      }).length;

      data.add(ChartDataPoint(
        label: DateFormat('M/d').format(weekStart),
        value: workoutsInWeek.toDouble(),
      ));
    }

    return data;
  }

  /// Prepare exercise distribution data with proper exercise names
  static Future<List<ChartDataPoint>> _prepareExerciseDistributionWithNames(
      List<Workout> completedWorkouts) async {
    final exerciseCounts = <String, int>{};
    final exerciseRepository = ExerciseRepository();

    // Count exercise occurrences by ID
    for (final workout in completedWorkouts) {
      for (final exerciseId in workout.exerciseIds) {
        exerciseCounts[exerciseId] = (exerciseCounts[exerciseId] ?? 0) + 1;
      }
    }

    // Sort by count and take top 6
    final sortedEntries = exerciseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topExercises = sortedEntries.take(6).toList();

    // Convert exercise IDs to names
    final result = <ChartDataPoint>[];
    for (final entry in topExercises) {
      try {
        final exercise = await exerciseRepository.getExercise(entry.key);
        final exerciseName = exercise?.name ?? 'Unknown Exercise';

        result.add(ChartDataPoint(
          label: exerciseName.length > 15
              ? '${exerciseName.substring(0, 15)}...'
              : exerciseName,
          value: entry.value.toDouble(),
        ));
      } catch (e) {
        // Fallback to exercise ID if lookup fails
        result.add(ChartDataPoint(
          label: entry.key.length > 15
              ? '${entry.key.substring(0, 15)}...'
              : entry.key,
          value: entry.value.toDouble(),
        ));
      }
    }

    return result;
  }
}

/// Data point for charts
class ChartDataPoint {
  final String label;
  final double value;

  ChartDataPoint({required this.label, required this.value});
}
