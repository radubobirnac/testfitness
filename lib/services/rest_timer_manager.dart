import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/audio_player_util.dart';
import 'package:testfitness/services/timer_debug_log_service.dart';
import 'package:testfitness/services/foreground_timer_service.dart';

enum RestTimerStatus {
  idle,
  running,
  paused,
  completed,
}

class RestTimerState {
  final RestTimerStatus status;
  final int totalDurationMs;
  final int remainingMs;
  final int? endEpochMs;
  final int? endElapsedMs;
  final bool notificationsEnabled;
  final bool completedWhileBackgrounded;

  const RestTimerState({
    required this.status,
    required this.totalDurationMs,
    required this.remainingMs,
    this.endEpochMs,
    this.endElapsedMs,
    this.notificationsEnabled = true,
    this.completedWhileBackgrounded = false,
  });

  const RestTimerState.idle()
      : status = RestTimerStatus.idle,
        totalDurationMs = 0,
        remainingMs = 0,
        endEpochMs = null,
        endElapsedMs = null,
        notificationsEnabled = true,
        completedWhileBackgrounded = false;

  bool get isRunning => status == RestTimerStatus.running;
  bool get isPaused => status == RestTimerStatus.paused;
  bool get isCompleted => status == RestTimerStatus.completed;

  double get progress {
    if (totalDurationMs <= 0) return 0.0;
    return remainingMs / totalDurationMs;
  }

  RestTimerState copyWith({
    RestTimerStatus? status,
    int? totalDurationMs,
    int? remainingMs,
    int? endEpochMs,
    int? endElapsedMs,
    bool? notificationsEnabled,
    bool? completedWhileBackgrounded,
  }) {
    return RestTimerState(
      status: status ?? this.status,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      remainingMs: remainingMs ?? this.remainingMs,
      endEpochMs: endEpochMs ?? this.endEpochMs,
      endElapsedMs: endElapsedMs ?? this.endElapsedMs,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      completedWhileBackgrounded:
          completedWhileBackgrounded ?? this.completedWhileBackgrounded,
    );
  }
}

class _TimeSample {
  final int epochMs;
  final int? elapsedMs;

  const _TimeSample({required this.epochMs, this.elapsedMs});
}

class _RestTimerClock {
  static const MethodChannel _channel =
      MethodChannel('com.testfitness/clock');
  bool _elapsedSupported = true;

  Future<_TimeSample> now() async {
    final epochMs = DateTime.now().millisecondsSinceEpoch;
    int? elapsedMs;

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        _elapsedSupported) {
      try {
        elapsedMs = await _channel.invokeMethod<int>('elapsedRealtime');
        if (elapsedMs == null) {
          _elapsedSupported = false;
        }
      } catch (e) {
        _elapsedSupported = false;
      }
    }

    return _TimeSample(epochMs: epochMs, elapsedMs: elapsedMs);
  }
}

class RestTimerManager with WidgetsBindingObserver {
  static const String _statusKey = 'rest_timer_status';
  static const String _totalDurationMsKey = 'rest_timer_total_duration_ms';
  static const String _remainingMsKey = 'rest_timer_remaining_ms';
  static const String _endEpochMsKey = 'rest_timer_end_epoch_ms';
  static const String _endElapsedMsKey = 'rest_timer_end_elapsed_ms';
  static const String _notificationsEnabledKey =
      'rest_timer_notifications_enabled';
  static const int _notificationId = 1101;
  static const int _rebootSkewThresholdMs = 5000;

  static final RestTimerManager _instance = RestTimerManager._internal();

  factory RestTimerManager() => _instance;

  RestTimerManager._internal();

  final StreamController<RestTimerState> _controller =
      StreamController<RestTimerState>.broadcast();
  final _RestTimerClock _clock = _RestTimerClock();
  final TimerDebugLogService _debugLog = TimerDebugLogService();

  final ForegroundTimerService _foregroundTimerService =
      ForegroundTimerService();

  RestTimerState _state = const RestTimerState.idle();
  SharedPreferences? _prefs;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  Timer? _tickTimer;
  bool _timezoneReady = false;
  bool _refreshInProgress = false;
  bool _wasBackgrounded = false;
  bool _isInBackground = false;
  bool _completedWhileBackgrounded = false;
  bool _notificationScheduled = false;
  bool _foregroundServiceActive = false;
  Future<void>? _initFuture;
  DateTime? _lastScheduleAttemptAt;
  String? _lastScheduleAttemptMode;
  String? _lastScheduleError;
  bool? _lastNotificationPermissionGranted;

  RestTimerStatus _status = RestTimerStatus.idle;
  int _totalDurationMs = 0;
  int _remainingMs = 0;
  int? _endEpochMs;
  int? _endElapsedMs;
  bool _notificationsEnabled = true;

  Stream<RestTimerState> get stream => _controller.stream;

  RestTimerState get state => _state;

  Map<String, String> debugSnapshot() {
    return {
      'status': _status.name,
      'totalDurationMs': _totalDurationMs.toString(),
      'remainingMs': _remainingMs.toString(),
      'endEpochMs': _endEpochMs?.toString() ?? 'null',
      'endElapsedMs': _endElapsedMs?.toString() ?? 'null',
      'notificationsEnabled': _notificationsEnabled.toString(),
      'notificationScheduled': _notificationScheduled.toString(),
      'completedWhileBackgrounded': _completedWhileBackgrounded.toString(),
      'lastScheduleAttemptAt':
          _lastScheduleAttemptAt?.toIso8601String() ?? 'null',
      'lastScheduleAttemptMode': _lastScheduleAttemptMode ?? 'null',
      'lastScheduleError': _lastScheduleError ?? 'null',
      'lastPermissionGranted':
          _lastNotificationPermissionGranted?.toString() ?? 'null',
    };
  }

  void _logDebug(String message) {
    unawaited(_debugLog.log(message));
  }

  bool get _supportsForegroundService =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureForegroundServiceRunning() async {
    if (!_supportsForegroundService) return;
    if (_status != RestTimerStatus.running) return;

    final endEpochMs = _endEpochMs;
    if (endEpochMs == null) return;

    final wasRunning = _foregroundServiceActive;
    final success = wasRunning
        ? await _foregroundTimerService.update(
            endEpochMs: endEpochMs,
            totalDurationMs: _totalDurationMs,
            remainingMs: _remainingMs,
          )
        : await _foregroundTimerService.start(
            endEpochMs: endEpochMs,
            totalDurationMs: _totalDurationMs,
            remainingMs: _remainingMs,
          );

    _foregroundServiceActive = success;
    _logDebug(
        'foreground service ${wasRunning ? "update" : "start"} success=$success');
  }

  Future<void> _stopForegroundService() async {
    if (!_supportsForegroundService) return;
    final success = await _foregroundTimerService.stop();
    _foregroundServiceActive = false;
    _logDebug('foreground service stop success=$success');
  }

  void configureNotifications(
      FlutterLocalNotificationsPlugin notificationsPlugin) {
    _notificationsPlugin = notificationsPlugin;
  }

  Future<void> initialize() {
    _initFuture ??= _initializeInternal();
    return _initFuture!;
  }

  Future<void> _initializeInternal() async {
    _prefs = await SharedPreferences.getInstance();
    WidgetsBinding.instance.addObserver(this);
    _logDebug('initialize');
    await _restoreState();
    _logDebug(
        'restore status=${_status.name} remainingMs=$_remainingMs totalMs=$_totalDurationMs');
    _emitState();
  }

  Future<void> start({
    required int durationSeconds,
    bool notificationsEnabled = true,
  }) async {
    if (durationSeconds <= 0) {
      AppLogger.warning('RestTimerManager: duration must be > 0');
      return;
    }

    await initialize();

    _logDebug(
        'start durationSeconds=$durationSeconds notificationsEnabled=$notificationsEnabled');
    _stopTicker();
    await _cancelCompletionNotification();

    final durationMs = durationSeconds * 1000;
    final sample = await _clock.now();

    _status = RestTimerStatus.running;
    _totalDurationMs = durationMs;
    _remainingMs = durationMs;
    _notificationsEnabled = notificationsEnabled;
    _endEpochMs = sample.epochMs + durationMs;
    _endElapsedMs = sample.elapsedMs != null
        ? sample.elapsedMs! + durationMs
        : null;
    _completedWhileBackgrounded = false;

    await _persistRunning();
    _startTicker();
    await _scheduleCompletionNotification();
    _logDebug('scheduled endEpochMs=$_endEpochMs endElapsedMs=$_endElapsedMs');
    await _ensureForegroundServiceRunning();
    _emitState();
  }

  Future<void> pause() async {
    await initialize();
    if (_status != RestTimerStatus.running) return;

    _logDebug('pause');
    await _refresh();
    if (_status == RestTimerStatus.completed) {
      return;
    }
    _status = RestTimerStatus.paused;
    _stopTicker();
    await _persistPaused();
    await _cancelCompletionNotification();
    await _stopForegroundService();
    _emitState();
  }

  Future<void> resume() async {
    await initialize();
    if (_status != RestTimerStatus.paused) return;

    _logDebug('resume');
    final sample = await _clock.now();

    _status = RestTimerStatus.running;
    _completedWhileBackgrounded = false;
    _endEpochMs = sample.epochMs + _remainingMs;
    _endElapsedMs = sample.elapsedMs != null
        ? sample.elapsedMs! + _remainingMs
        : null;

    await _persistRunning();
    _startTicker();
    await _scheduleCompletionNotification();
    await _ensureForegroundServiceRunning();
    _emitState();
  }

  Future<void> reset({int? durationSeconds}) async {
    await initialize();

    final durationMs = durationSeconds != null
        ? durationSeconds * 1000
        : _totalDurationMs;

    if (durationMs <= 0) {
      _logDebug('reset durationMs=$durationMs -> stop');
      await stop();
      return;
    }

    _logDebug('reset durationMs=$durationMs');
    _status = RestTimerStatus.paused;
    _totalDurationMs = durationMs;
    _remainingMs = durationMs;
    _endEpochMs = null;
    _endElapsedMs = null;
    _completedWhileBackgrounded = false;

    _stopTicker();
    await _persistPaused();
    await _cancelCompletionNotification();
    await _stopForegroundService();
    _emitState();
  }

  Future<void> stop() async {
    await initialize();

    _logDebug('stop');
    _status = RestTimerStatus.idle;
    _totalDurationMs = 0;
    _remainingMs = 0;
    _endEpochMs = null;
    _endElapsedMs = null;
    _completedWhileBackgrounded = false;

    _stopTicker();
    await _clearStorage();
    await _cancelCompletionNotification();
    await _stopForegroundService();
    _emitState();
  }

  Future<void> addTime(int seconds) async {
    await initialize();
    if (seconds <= 0) return;

    _logDebug('addTime seconds=$seconds');
    final deltaMs = seconds * 1000;
    _totalDurationMs += deltaMs;

    if (_status == RestTimerStatus.running) {
      _endEpochMs = (_endEpochMs ?? 0) + deltaMs;
      if (_endElapsedMs != null) {
        _endElapsedMs = _endElapsedMs! + deltaMs;
      }
      _remainingMs += deltaMs;
      await _persistRunning();
      await _scheduleCompletionNotification();
      await _ensureForegroundServiceRunning();
    } else {
      _remainingMs += deltaMs;
      await _persistPaused();
    }

    _emitState();
  }

  Future<void> subtractTime(int seconds) async {
    await initialize();
    if (seconds <= 0) return;

    _logDebug('subtractTime seconds=$seconds');
    final deltaMs = seconds * 1000;

    if (_status == RestTimerStatus.running) {
      _endEpochMs = (_endEpochMs ?? 0) - deltaMs;
      if (_endElapsedMs != null) {
        _endElapsedMs = _endElapsedMs! - deltaMs;
      }
      await _refresh();
      if (_status != RestTimerStatus.running) {
        return;
      }
      await _persistRunning();
      await _scheduleCompletionNotification();
      await _ensureForegroundServiceRunning();
    } else if (_status == RestTimerStatus.paused) {
      _remainingMs = max(0, _remainingMs - deltaMs);
      if (_remainingMs <= 0) {
        await _complete(completedWhileBackgrounded: false);
        return;
      }
      await _persistPaused();
    }

    _emitState();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await initialize();
    _logDebug('setNotificationsEnabled enabled=$enabled');
    _notificationsEnabled = enabled;

    if (_status == RestTimerStatus.running) {
      if (enabled) {
        await _scheduleCompletionNotification();
      } else {
        await _cancelCompletionNotification();
      }
    }

    await _persistNotificationsPreference();
    _emitState();
  }

  Future<void> refresh() async {
    await initialize();
    await _refresh(fromBackground: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
      _isInBackground = true;
      _logDebug('lifecycle paused');
      if (_status == RestTimerStatus.running) {
        if (_foregroundServiceActive) {
          _logDebug('ticker kept running due to foreground service');
        } else {
          _stopTicker();
          _logDebug('ticker stopped for background');
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _logDebug('lifecycle resumed');
      if (_status == RestTimerStatus.running) {
        unawaited(_refresh(fromBackground: _wasBackgrounded));
        if (_status == RestTimerStatus.running) {
          if (_tickTimer == null) {
            _startTicker();
            _logDebug('ticker restarted after background');
          } else {
            _logDebug('ticker already running after background');
          }
        }
      }
      _wasBackgrounded = false;
    }
  }

  Future<void> _restoreState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final status = _parseStatus(prefs.getString(_statusKey));
    _totalDurationMs = prefs.getInt(_totalDurationMsKey) ?? 0;
    _remainingMs = prefs.getInt(_remainingMsKey) ?? _totalDurationMs;
    _endEpochMs = prefs.getInt(_endEpochMsKey);
    _endElapsedMs = prefs.getInt(_endElapsedMsKey);
    _notificationsEnabled =
        prefs.getBool(_notificationsEnabledKey) ?? true;

    _status = status ?? RestTimerStatus.idle;

    if (_status == RestTimerStatus.running) {
      await _refresh(fromBackground: true, emit: false);
      if (_status == RestTimerStatus.running) {
        _startTicker();
        await _scheduleCompletionNotification();
        await _ensureForegroundServiceRunning();
      }
    }
  }

  Future<void> _refresh({
    bool fromBackground = false,
    bool emit = true,
  }) async {
    if (_status != RestTimerStatus.running) {
      if (emit) {
        _emitState();
      }
      return;
    }

    if (_refreshInProgress) return;
    _refreshInProgress = true;

    final sample = await _clock.now();
    final remainingMs = _calculateRemainingMs(sample);

    if (fromBackground) {
      _logDebug(
          'refresh fromBackground remainingMs=$remainingMs endEpochMs=$_endEpochMs endElapsedMs=$_endElapsedMs');
    }

    if (remainingMs <= 0) {
      final completedInBackground = fromBackground || _isInBackground;
      await _complete(completedWhileBackgrounded: completedInBackground);
      _refreshInProgress = false;
      return;
    }

    _remainingMs = remainingMs;
    if (emit) {
      _emitState();
    }
    _refreshInProgress = false;
  }

  int _calculateRemainingMs(_TimeSample sample) {
    if (_endElapsedMs != null && sample.elapsedMs != null) {
      final startElapsedMs = _endElapsedMs! - _totalDurationMs;
      if (sample.elapsedMs! >= startElapsedMs - _rebootSkewThresholdMs) {
        return max(0, _endElapsedMs! - sample.elapsedMs!);
      }
    }

    if (_endEpochMs == null) return _remainingMs;
    return max(0, _endEpochMs! - sample.epochMs);
  }

  Future<void> _complete({required bool completedWhileBackgrounded}) async {
    bool shouldSuppressSound = false;
    if (completedWhileBackgrounded) {
      final wasActive = await _isNotificationActive();
      final wasPending = await _isNotificationPending();
      _logDebug('background completion: active=$wasActive pending=$wasPending');

      if (wasPending) {
        await _showCompletionNotification();
        _logDebug('fallback notification shown after background completion');
      }

      shouldSuppressSound = wasActive || wasPending;
    }

    _status = RestTimerStatus.completed;
    _remainingMs = 0;
    _endEpochMs = null;
    _endElapsedMs = null;
    _completedWhileBackgrounded = shouldSuppressSound;

    _logDebug(
        'complete completedWhileBackgrounded=$completedWhileBackgrounded notificationScheduled=$_notificationScheduled');
    _stopTicker();
    await _cancelCompletionNotification();
    await _stopForegroundService();
    await _clearStorage();

    _emitState();
  }

  void _startTicker() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refresh(fromBackground: false));
    });
  }

  void _stopTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _emitState() {
    _state = RestTimerState(
      status: _status,
      totalDurationMs: _totalDurationMs,
      remainingMs: _remainingMs,
      endEpochMs: _endEpochMs,
      endElapsedMs: _endElapsedMs,
      notificationsEnabled: _notificationsEnabled,
      completedWhileBackgrounded: _completedWhileBackgrounded,
    );
    _controller.add(_state);
  }

  RestTimerStatus? _parseStatus(String? value) {
    switch (value) {
      case 'running':
        return RestTimerStatus.running;
      case 'paused':
        return RestTimerStatus.paused;
      case 'completed':
        return RestTimerStatus.completed;
      case 'idle':
        return RestTimerStatus.idle;
      default:
        return null;
    }
  }

  Future<void> _persistRunning() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setString(_statusKey, 'running');
    await prefs.setInt(_totalDurationMsKey, _totalDurationMs);
    if (_endEpochMs != null) {
      await prefs.setInt(_endEpochMsKey, _endEpochMs!);
    } else {
      await prefs.remove(_endEpochMsKey);
    }
    if (_endElapsedMs != null) {
      await prefs.setInt(_endElapsedMsKey, _endElapsedMs!);
    } else {
      await prefs.remove(_endElapsedMsKey);
    }
    await prefs.setBool(_notificationsEnabledKey, _notificationsEnabled);
    await prefs.remove(_remainingMsKey);
  }

  Future<void> _persistPaused() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setString(_statusKey, 'paused');
    await prefs.setInt(_totalDurationMsKey, _totalDurationMs);
    await prefs.setInt(_remainingMsKey, _remainingMs);
    await prefs.setBool(_notificationsEnabledKey, _notificationsEnabled);
    await prefs.remove(_endEpochMsKey);
    await prefs.remove(_endElapsedMsKey);
  }

  Future<void> _persistNotificationsPreference() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(_notificationsEnabledKey, _notificationsEnabled);
  }

  Future<void> _clearStorage() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.remove(_statusKey);
    await prefs.remove(_totalDurationMsKey);
    await prefs.remove(_remainingMsKey);
    await prefs.remove(_endEpochMsKey);
    await prefs.remove(_endElapsedMsKey);
    await prefs.remove(_notificationsEnabledKey);
  }

  Future<bool> _scheduleCompletionNotification() async {
    _notificationScheduled = false;
    if (!_notificationsEnabled) {
      _logDebug('schedule skipped: notifications disabled');
      return false;
    }

    final notifications = _notificationsPlugin;
    if (notifications == null) {
      AppLogger.warning(
          'RestTimerManager: notifications plugin not configured');
      _lastScheduleAttemptAt = DateTime.now();
      _lastScheduleAttemptMode = null;
      _lastScheduleError = 'notifications plugin not configured';
      _logDebug('schedule failed: notifications plugin not configured');
      return false;
    }

    if (_endEpochMs == null) {
      _logDebug('schedule skipped: endEpochMs null');
      return false;
    }

    final permissionsGranted =
        await AudioPlayerUtil.requestNotificationPermissions();
    _lastNotificationPermissionGranted = permissionsGranted;
    if (!permissionsGranted) {
      AppLogger.warning('RestTimerManager: notification permission denied');
      _lastScheduleAttemptAt = DateTime.now();
      _lastScheduleAttemptMode = null;
      _lastScheduleError = 'notification permission denied';
      _logDebug('schedule failed: notification permission denied');
      return false;
    }

    if (!_timezoneReady) {
      try {
        tz_data.initializeTimeZones();
        _timezoneReady = true;
      } catch (e) {
        AppLogger.error('RestTimerManager: timezone init failed', e);
        _logDebug('schedule failed: timezone init failed');
        return false;
      }
    }

    final scheduledTime =
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, _endEpochMs!);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_channel_id',
      'Timer Notifications',
      channelDescription: 'Channel for timer completion sounds',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('shipbell'),
      ticker: 'Timer Complete!',
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: 'shipbell.wav',
      presentAlert: true,
      presentBadge: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    Future<bool> scheduleWithMode(AndroidScheduleMode mode) async {
      try {
        _lastScheduleAttemptAt = DateTime.now();
        await notifications.zonedSchedule(
          _notificationId,
          'Timer Complete!',
          'Time for your next set!',
          scheduledTime,
          notificationDetails,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        _lastScheduleAttemptMode = mode.name;
        _lastScheduleError = null;
        _logDebug('schedule success mode=${mode.name} at=$scheduledTime');
        return true;
      } catch (e) {
        AppLogger.warning('RestTimerManager: schedule failed', e);
        _lastScheduleAttemptMode = mode.name;
        _lastScheduleError = e.toString();
        _logDebug('schedule failed mode=${mode.name} error=$e');
        return false;
      }
    }

    var scheduled =
        await scheduleWithMode(AndroidScheduleMode.exactAllowWhileIdle);
    if (!scheduled) {
      AppLogger.warning(
          'RestTimerManager: falling back to inexact alarm scheduling');
      scheduled =
          await scheduleWithMode(AndroidScheduleMode.inexactAllowWhileIdle);
    }

    if (!scheduled) {
      return false;
    }

    _notificationScheduled = true;
    _logDebug('notification scheduled id=$_notificationId');
    return true;
  }


  Future<bool> _isNotificationPending() async {
    final notifications = _notificationsPlugin;
    if (notifications == null) return false;

    try {
      final pending = await notifications.pendingNotificationRequests();
      return pending.any((request) => request.id == _notificationId);
    } catch (e) {
      AppLogger.warning(
          'RestTimerManager: pending notification check failed', e);
      _logDebug('pending notification check failed: $e');
      return false;
    }
  }

  Future<bool> _isNotificationActive() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final notifications = _notificationsPlugin;
    if (notifications == null) return false;

    try {
      final android = notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final active = await android?.getActiveNotifications();
      if (active == null) return false;
      return active.any((notification) => notification.id == _notificationId);
    } catch (e) {
      AppLogger.warning(
          'RestTimerManager: active notification check failed', e);
      _logDebug('active notification check failed: $e');
      return false;
    }
  }

  Future<void> _showCompletionNotification() async {
    final notifications = _notificationsPlugin;
    if (notifications == null) return;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'timer_channel_id',
      'Timer Notifications',
      channelDescription: 'Channel for timer completion sounds',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('shipbell'),
      ticker: 'Timer Complete!',
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSDetails =
        DarwinNotificationDetails(
      presentSound: true,
      sound: 'shipbell.wav',
      presentAlert: true,
      presentBadge: false,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await notifications.show(
      _notificationId,
      'Timer Complete!',
      'Time for your next set!',
      notificationDetails,
    );
  }

  Future<void> _cancelCompletionNotification() async {
    final notifications = _notificationsPlugin;
    if (notifications == null) return;
    await notifications.cancel(_notificationId);
    _notificationScheduled = false;
    _logDebug('notification canceled id=$_notificationId');
  }
}
