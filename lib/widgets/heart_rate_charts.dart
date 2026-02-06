import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/services/heart_rate_service.dart';

/// Heart rate visualization widgets for real-time and historical data
class HeartRateCharts {
  /// Create a real-time heart rate line chart
  static Widget buildRealTimeChart(
    List<HeartRateReading> readings,
    BuildContext context, {
    int? targetHeartRate,
    int? maxHeartRate,
    Duration timeWindow = const Duration(minutes: 5),
  }) {
    if (readings.isEmpty) {
      return _buildEmptyChart(context, 'No heart rate data available');
    }

    // Filter readings to time window
    final now = DateTime.now();
    final cutoff = now.subtract(timeWindow);
    final filteredReadings = readings
        .where((reading) => reading.timestamp.isAfter(cutoff))
        .toList();

    if (filteredReadings.isEmpty) {
      return _buildEmptyChart(context, 'No recent heart rate data');
    }

    // Prepare chart data
    final spots = filteredReadings.asMap().entries.map((entry) {
      final secondsAgo = now.difference(entry.value.timestamp).inSeconds;
      return FlSpot(
        -secondsAgo.toDouble(), // Negative for reverse chronological order
        entry.value.heartRate.toDouble(),
      );
    }).toList();

    // Calculate Y-axis bounds
    final heartRates = filteredReadings.map((r) => r.heartRate).toList();
    final minHR = heartRates.reduce((a, b) => a < b ? a : b);
    final maxHR = heartRates.reduce((a, b) => a > b ? a : b);
    final padding = (maxHR - minHR) * 0.1;
    final yMin = (minHR - padding).clamp(40, 220).toDouble();
    final yMax = (maxHR + padding).clamp(40, 220).toDouble();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Real-Time Heart Rate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (filteredReadings.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getHeartRateZoneColor(filteredReadings.last.heartRate, maxHeartRate),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredReadings.last.heartRate} BPM',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 20,
                    verticalInterval: 60,
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
                        reservedSize: 40,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 60,
                        getTitlesWidget: (value, meta) {
                          final secondsAgo = -value.toInt();
                          if (secondsAgo % 60 == 0) {
                            final minutesAgo = secondsAgo ~/ 60;
                            return Text(
                              '${minutesAgo}m',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  minX: -timeWindow.inSeconds.toDouble(),
                  maxX: 0,
                  minY: yMin,
                  maxY: yMax,
                  lineBarsData: [
                    // Main heart rate line
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: 0.8),
                          Colors.red,
                        ],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withValues(alpha: 0.1),
                            Colors.red.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Target heart rate line
                    if (targetHeartRate != null)
                      LineChartBarData(
                        spots: [
                          FlSpot(-timeWindow.inSeconds.toDouble(), targetHeartRate.toDouble()),
                          FlSpot(0, targetHeartRate.toDouble()),
                        ],
                        isCurved: false,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        dashArray: [5, 5],
                      ),
                  ],
                ),
              ),
            ),
            if (targetHeartRate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 2,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Target: $targetHeartRate BPM',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Create a historical heart rate chart for past sessions
  static Widget buildHistoricalChart(
    List<HeartRateSession> sessions,
    BuildContext context,
  ) {
    if (sessions.isEmpty) {
      return _buildEmptyChart(context, 'No historical heart rate data');
    }

    // Prepare chart data - show average heart rate per session
    final spots = sessions.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.averageHeartRate.toDouble(),
      );
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Heart Rate History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
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
                        reservedSize: 40,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
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
                          if (index >= 0 && index < sessions.length) {
                            return Text(
                              DateFormat('M/d').format(sessions[index].date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  minX: 0,
                  maxX: (sessions.length - 1).toDouble(),
                  minY: sessions.map((s) => s.averageHeartRate).reduce((a, b) => a < b ? a : b) - 10.0,
                  maxY: sessions.map((s) => s.averageHeartRate).reduce((a, b) => a > b ? a : b) + 10.0,
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

  static Widget _buildEmptyChart(BuildContext context, String message) {
    return Card(
      elevation: 2,
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _getHeartRateZoneColor(int heartRate, int? maxHeartRate) {
    if (maxHeartRate == null) return Colors.grey;
    
    final percentage = heartRate / maxHeartRate;
    if (percentage >= 0.95) return Colors.purple; // VO2 Max
    if (percentage >= 0.85) return Colors.red;    // Peak
    if (percentage >= 0.70) return Colors.orange; // Cardio
    if (percentage >= 0.60) return Colors.green;  // Fat Burn
    return Colors.blue; // Resting
  }
}

/// Heart rate session data for historical tracking
class HeartRateSession {
  final DateTime date;
  final int averageHeartRate;
  final int maxHeartRate;
  final int minHeartRate;
  final Duration duration;
  final String sessionType;

  HeartRateSession({
    required this.date,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.minHeartRate,
    required this.duration,
    required this.sessionType,
  });
}
