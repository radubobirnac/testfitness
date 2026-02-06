import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';

class TimerDebugLogService {
  static const String _storageKey = 'timer_debug_log_entries';
  static const int _maxEntries = 200;
  static final TimerDebugLogService _instance = TimerDebugLogService._internal();

  factory TimerDebugLogService() => _instance;

  TimerDebugLogService._internal();

  SharedPreferences? _prefs;
  final List<String> _entries = [];

  Future<void> initialize() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getStringList(_storageKey);
    if (stored != null) {
      _entries
        ..clear()
        ..addAll(stored);
    }
  }

  Future<List<String>> getEntries() async {
    await initialize();
    return List.unmodifiable(_entries);
  }

  Future<void> log(String message) async {
    await initialize();
    final entry = _formatEntry(message);
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    await _prefs?.setStringList(_storageKey, _entries);
    AppLogger.debug('TimerDebug: $message');
  }

  Future<void> clear() async {
    await initialize();
    _entries.clear();
    await _prefs?.remove(_storageKey);
  }

  String _formatEntry(String message) {
    final timestamp = DateTime.now().toIso8601String();
    return '[$timestamp] $message';
  }
}
