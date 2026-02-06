import 'package:flutter/material.dart';
import 'package:testfitness/utils/performance_monitor.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Performance monitoring screen for StrengthWave
/// 
/// Displays real-time performance metrics and allows performance testing
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Map<String, Map<String, dynamic>> _stats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _stats = PerformanceMonitor.getAllStats();
    });
  }

  void _clearStats() {
    PerformanceMonitor.clearStats();
    _refreshStats();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Performance statistics cleared'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _logStats() {
    PerformanceMonitor.logAllStats();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Performance statistics logged to console'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _runPerformanceTest() async {
    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.info('Starting performance test...');
      
      // Test database operations
      await PerformanceMonitor.monitorFuture(
        'test_database_operations',
        _testDatabaseOperations(),
      );
      
      // Test UI operations
      PerformanceMonitor.monitorSync(
        'test_ui_operations',
        _testUIOperations,
      );
      
      AppLogger.info('Performance test completed');
      _refreshStats();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Performance test completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Performance test failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Performance test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testDatabaseOperations() async {
    // Simulate database operations
    await Future.delayed(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 50));
    await Future.delayed(const Duration(milliseconds: 75));
  }

  void _testUIOperations() {
    // Simulate UI operations
    for (int i = 0; i < 1000; i++) {
      // Simulate some computation
      final result = i * i + i;
      if (result < 0) break; // Never true, just to use the variable
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStats,
            tooltip: 'Refresh Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearStats,
            tooltip: 'Clear Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _logStats,
            tooltip: 'Log to Console',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Running performance test...'),
                ],
              ),
            )
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _runPerformanceTest,
        icon: const Icon(Icons.speed),
        label: const Text('Run Test'),
      ),
    );
  }

  Widget _buildContent() {
    if (_stats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No performance data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Use the app or run a performance test to collect data',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        ..._stats.entries.map((entry) => _buildStatCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalOperations = _stats.values
        .where((stat) => !stat.containsKey('error'))
        .fold<int>(0, (sum, stat) => sum + (stat['count'] as int));
    
    final averageTime = _stats.values
        .where((stat) => !stat.containsKey('error'))
        .map((stat) => stat['average_ms'] as int)
        .fold<int>(0, (sum, avg) => sum + avg) / 
        (_stats.values.where((stat) => !stat.containsKey('error')).length);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Operations', totalOperations.toString()),
                _buildSummaryItem('Avg Time', '${averageTime.round()}ms'),
                _buildSummaryItem('Categories', _stats.length.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStatCard(String operation, Map<String, dynamic> stats) {
    if (stats.containsKey('error')) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: Text(operation),
          subtitle: Text(stats['error']),
        ),
      );
    }

    final count = stats['count'] as int;
    final avgMs = stats['average_ms'] as int;
    final minMs = stats['min_ms'] as int;
    final maxMs = stats['max_ms'] as int;

    Color performanceColor = Colors.green;
    if (avgMs > 500) {
      performanceColor = Colors.red;
    } else if (avgMs > 200) {
      performanceColor = Colors.orange;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    operation.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: performanceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${avgMs}ms',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Calls: $count'),
                Text('Min: ${minMs}ms'),
                Text('Max: ${maxMs}ms'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
