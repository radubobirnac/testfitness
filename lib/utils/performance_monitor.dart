import 'package:flutter/foundation.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Performance monitoring utility for StrengthWave
/// 
/// Tracks app performance metrics and provides insights for optimization
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<int>> _durations = {};
  
  /// Start timing an operation
  static void startTimer(String operation) {
    if (kDebugMode) {
      _startTimes[operation] = DateTime.now();
      AppLogger.debug('Performance: Started timing $operation');
    }
  }
  
  /// End timing an operation and log the duration
  static void endTimer(String operation) {
    if (kDebugMode && _startTimes.containsKey(operation)) {
      final startTime = _startTimes[operation]!;
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      
      // Store duration for analysis
      _durations.putIfAbsent(operation, () => []);
      _durations[operation]!.add(duration);
      
      AppLogger.debug('Performance: $operation took ${duration}ms');
      _startTimes.remove(operation);
      
      // Log warning for slow operations
      if (duration > 1000) {
        AppLogger.warning('Performance: Slow operation detected - $operation took ${duration}ms');
      }
    }
  }
  
  /// Get performance statistics for an operation
  static Map<String, dynamic> getStats(String operation) {
    if (!_durations.containsKey(operation) || _durations[operation]!.isEmpty) {
      return {'error': 'No data available for $operation'};
    }
    
    final durations = _durations[operation]!;
    final total = durations.reduce((a, b) => a + b);
    final average = total / durations.length;
    final min = durations.reduce((a, b) => a < b ? a : b);
    final max = durations.reduce((a, b) => a > b ? a : b);
    
    return {
      'operation': operation,
      'count': durations.length,
      'average_ms': average.round(),
      'min_ms': min,
      'max_ms': max,
      'total_ms': total,
    };
  }
  
  /// Get all performance statistics
  static Map<String, Map<String, dynamic>> getAllStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final operation in _durations.keys) {
      stats[operation] = getStats(operation);
    }
    return stats;
  }
  
  /// Log all performance statistics
  static void logAllStats() {
    if (kDebugMode) {
      AppLogger.info('=== Performance Statistics ===');
      final allStats = getAllStats();
      
      if (allStats.isEmpty) {
        AppLogger.info('No performance data collected yet');
        return;
      }
      
      for (final entry in allStats.entries) {
        final stats = entry.value;
        if (!stats.containsKey('error')) {
          AppLogger.info(
            '${entry.key}: ${stats['count']} calls, '
            'avg: ${stats['average_ms']}ms, '
            'min: ${stats['min_ms']}ms, '
            'max: ${stats['max_ms']}ms'
          );
        }
      }
      AppLogger.info('=== End Performance Statistics ===');
    }
  }
  
  /// Clear all performance data
  static void clearStats() {
    _startTimes.clear();
    _durations.clear();
    AppLogger.debug('Performance: Cleared all statistics');
  }
  
  /// Monitor a future operation
  static Future<T> monitorFuture<T>(String operation, Future<T> future) async {
    startTimer(operation);
    try {
      final result = await future;
      endTimer(operation);
      return result;
    } catch (e) {
      endTimer(operation);
      AppLogger.error('Performance: Error in monitored operation $operation', e);
      rethrow;
    }
  }
  
  /// Monitor a synchronous operation
  static T monitorSync<T>(String operation, T Function() function) {
    startTimer(operation);
    try {
      final result = function();
      endTimer(operation);
      return result;
    } catch (e) {
      endTimer(operation);
      AppLogger.error('Performance: Error in monitored operation $operation', e);
      rethrow;
    }
  }
}

/// Performance monitoring mixin for widgets
mixin PerformanceMonitorMixin {
  /// Monitor widget build performance
  void monitorBuild(String widgetName, VoidCallback buildFunction) {
    PerformanceMonitor.monitorSync('build_$widgetName', buildFunction);
  }
  
  /// Monitor async operations in widgets
  Future<T> monitorAsync<T>(String operationName, Future<T> operation) {
    return PerformanceMonitor.monitorFuture(operationName, operation);
  }
}
