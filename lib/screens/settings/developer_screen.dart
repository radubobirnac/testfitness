import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:testfitness/screens/gemini_tts_test_screen.dart';
import 'package:testfitness/screens/performance_screen.dart';
import 'package:testfitness/screens/tts_analytics_screen.dart';
import 'package:testfitness/services/timer_debug_log_service.dart';
import 'package:testfitness/services/timer_debug_reporter.dart';
import 'package:testfitness/ui/settings_group.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Settings > Developer (debug builds only): performance monitor, timer
/// debug report/log, notification tests and TTS test screens.
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  final TimerDebugReporter _timerDebugReporter = TimerDebugReporter();
  final TimerDebugLogService _timerDebugLogService = TimerDebugLogService();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: error ? TextStyle(color: colorScheme.onError) : null),
        backgroundColor: error ? colorScheme.error : null,
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _copyTimerDebugReport() async {
    try {
      final report = await _timerDebugReporter.buildReport();
      await Clipboard.setData(ClipboardData(text: report));
      _snack('Timer debug report copied to clipboard.');
    } catch (e) {
      _snack('Failed to build debug report: $e', error: true);
    }
  }

  Future<void> _showTextDialog({
    required String title,
    required String text,
    required String copiedMessage,
  }) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(copiedMessage)),
                );
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimerDebugReport() async {
    try {
      final report = await _timerDebugReporter.buildReport();
      await _showTextDialog(
        title: 'Timer Debug Report',
        text: report,
        copiedMessage: 'Timer debug report copied.',
      );
    } catch (e) {
      _snack('Failed to build debug report: $e', error: true);
    }
  }

  Future<void> _requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) {
      _snack('Battery optimization controls are Android-only.');
      return;
    }
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      _snack(status.isGranted
          ? 'Battery optimizations ignored for StrengthWave.'
          : 'Battery optimization permission not granted.');
    } catch (e) {
      _snack('Failed to request battery optimization: $e', error: true);
    }
  }

  Future<void> _showTimerDebugLog() async {
    try {
      final entries = await _timerDebugLogService.getEntries();
      await _showTextDialog(
        title: 'Timer Debug Log',
        text: entries.isEmpty
            ? 'No timer events recorded yet.'
            : entries.join('\n'),
        copiedMessage: 'Timer debug log copied.',
      );
    } catch (e) {
      _snack('Failed to load debug log: $e', error: true);
    }
  }

  Future<void> _clearTimerDebugLog() async {
    try {
      await _timerDebugLogService.clear();
      _snack('Timer debug log cleared.');
    } catch (e) {
      _snack('Failed to clear debug log: $e', error: true);
    }
  }

  Future<void> _testHeadsUpNotification() async {
    try {
      await _timerDebugReporter.scheduleHeadsUpTest();
      _snack(_isAndroid
          ? 'Heads-up test scheduled in 10s. Switch apps/lock screen now.'
          : 'Timer notification test scheduled in 10s. Lock screen now.');
    } catch (e) {
      AppLogger.error('Timer notification test scheduling failed', e);
      _snack('Failed to schedule timer notification test: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer tools')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SettingsGroup(
            title: 'Performance',
            children: [
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Open Performance Monitor'),
                subtitle:
                    const Text('App performance and database operations'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const PerformanceScreen()),
              ),
            ],
          ),
          SettingsGroup(
            title: 'Timer debug report',
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Debug Report'),
                subtitle: const Text(
                    'Notification settings, permissions and timer state'),
                onTap: _copyTimerDebugReport,
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Report'),
                onTap: _showTimerDebugReport,
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: Text(_isAndroid
                    ? 'Test Heads-Up Notification'
                    : 'Test Timer Notification'),
                subtitle: const Text('Fires in 10 seconds'),
                onTap: _testHeadsUpNotification,
              ),
              ListTile(
                leading: const Icon(Icons.battery_alert_outlined),
                title: const Text('Disable Battery Optimizations'),
                subtitle: _isAndroid
                    ? null
                    : const Text(
                        'Battery optimization controls are Android-only.'),
                enabled: _isAndroid,
                onTap: _requestIgnoreBatteryOptimizations,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Timer debug log',
            children: [
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('View Log'),
                subtitle: const Text(
                    'Persistent background log of timer events'),
                onTap: _showTimerDebugLog,
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Clear Log'),
                onTap: _clearTimerDebugLog,
              ),
            ],
          ),
          SettingsGroup(
            title: 'Text-to-speech',
            children: [
              ListTile(
                leading: const Icon(Icons.science),
                title: const Text('Test Gemini TTS'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const GeminiTTSTestScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('TTS Analytics & Cost Optimization'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(const TTSAnalyticsScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
