import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/database_service_factory.dart';

/// Repository for fitness metric operations
class MetricsRepository {
  final DatabaseInterface _databaseService =
      DatabaseServiceFactory.getDatabaseService();

  /// Get all metrics
  Future<List<FitnessMetric>> getMetrics() async {
    return await _databaseService.getMetrics();
  }

  /// Get metrics of a specific type
  Future<List<FitnessMetric>> getMetricsByType(MetricType type) async {
    return await _databaseService.getMetricsByType(type);
  }

  /// Get metrics within a date range
  Future<List<FitnessMetric>> getMetricsByDateRange(
      DateTime start, DateTime end) async {
    return await _databaseService.getMetricsByDateRange(start, end);
  }

  /// Get metrics of a specific type within a date range
  Future<List<FitnessMetric>> getMetricsByTypeAndDateRange(
      MetricType type, DateTime start, DateTime end) async {
    return await _databaseService.getMetricsByTypeAndDateRange(
        type, start, end);
  }

  /// Get the most recent metric of a specific type
  Future<FitnessMetric?> getLatestMetricByType(MetricType type) async {
    return await _databaseService.getLatestMetricByType(type);
  }

  /// Add a new metric
  Future<void> addMetric(FitnessMetric metric) async {
    await _databaseService.insertMetric(metric);
  }

  /// Update an existing metric
  Future<void> updateMetric(FitnessMetric metric) async {
    await _databaseService.updateMetric(metric);
  }

  /// Delete a metric
  Future<void> deleteMetric(String id) async {
    await _databaseService.deleteMetric(id);
  }

  /// Get metrics for a chart (returns data formatted for UI display)
  Future<List<Map<String, dynamic>>> getMetricsForChart(
      MetricType type, DateTime start, DateTime end) async {
    final metrics = await getMetricsByTypeAndDateRange(type, start, end);
    
    // Sort metrics by date, oldest first for proper chart display
    metrics.sort((a, b) => a.date.compareTo(b.date));
    
    return metrics.map((metric) {
      return {
        'id': metric.id,
        'date': metric.date,
        'value': metric.value,
        'label': metric.displayName,
        'unit': metric.unit ?? '',
      };
    }).toList();
  }

  /// Get metrics trends (calculate changes over time)
  Future<Map<String, dynamic>> getMetricTrends(MetricType type) async {
    final metrics = await getMetricsByType(type);
    
    if (metrics.isEmpty) {
      return {
        'current': null,
        'previous': null,
        'change': 0.0,
        'percentChange': 0.0,
        'trend': 'neutral'
      };
    }
    
    // Sort by date, newest first
    metrics.sort((a, b) => b.date.compareTo(a.date));
    
    final current = metrics.isNotEmpty ? metrics.first : null;
    final previous = metrics.length > 1 ? metrics[1] : null;
    
    if (current == null || previous == null) {
      return {
        'current': current,
        'previous': previous,
        'change': 0.0,
        'percentChange': 0.0,
        'trend': 'neutral'
      };
    }
    
    final change = current.value - previous.value;
    final percentChange = previous.value != 0 
        ? (change / previous.value) * 100 
        : 0.0;
    
    String trend;
    // For weight and other measurements where decreasing might be the goal,
    // the interpretation might need to be reversed based on user preferences
    if (change > 0) {
      trend = 'up';
    } else if (change < 0) {
      trend = 'down';
    } else {
      trend = 'neutral';
    }
    
    return {
      'current': current,
      'previous': previous,
      'change': change,
      'percentChange': percentChange,
      'trend': trend
    };
  }
} 