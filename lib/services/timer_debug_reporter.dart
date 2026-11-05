import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:testfitness/screens/app_loader.dart';
import 'package:testfitness/services/rest_timer_manager.dart';
import 'package:testfitness/services/timer_debug_log_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/audio_player_util.dart';

class TimerDebugReporter {
  final RestTimerManager _timerManager = RestTimerManager();
  final UserPreferencesService _preferences = UserPreferencesService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final TimerDebugLogService _debugLog = TimerDebugLogService();
  static const MethodChannel _powerChannel =
      MethodChannel('com.testfitness/power_status');
  bool _timezoneReady = false;

  Future<String> buildReport() async {
    final buffer = StringBuffer();
    final now = DateTime.now().toIso8601String();

    buffer.writeln('StrengthWave Timer Debug Report');
    buffer.writeln('Generated: $now');
    buffer.writeln('');

    await _appendDeviceInfo(buffer);
    await _appendPreferences(buffer);
    await _appendPermissionStatus(buffer);
    await _appendPowerStatus(buffer);
    await _appendNotificationChannel(buffer);
    await _appendTimerState(buffer);
    await _appendTimerLogs(buffer);

    return buffer.toString();
  }

  Future<void> _appendDeviceInfo(StringBuffer buffer) async {
    buffer.writeln('Device:');
    buffer.writeln('- Platform: ${Platform.operatingSystem}');
    buffer.writeln('- OS version: ${Platform.operatingSystemVersion}');

    if (Platform.isAndroid) {
      try {
        final info = await _deviceInfo.androidInfo;
        buffer.writeln('- Manufacturer: ${info.manufacturer}');
        buffer.writeln('- Model: ${info.model}');
        buffer.writeln('- Device: ${info.device}');
        buffer.writeln('- SDK: ${info.version.sdkInt}');
        buffer.writeln('- Release: ${info.version.release}');
      } catch (e) {
        AppLogger.warning('TimerDebugReporter: failed to read Android info', e);
        buffer.writeln('- Android details: unavailable');
      }
    }

    buffer.writeln('');
  }

  Future<void> _appendPreferences(StringBuffer buffer) async {
    await _preferences.initialize();
    buffer.writeln('Timer Preferences:');
    buffer.writeln(
        '- Rest timer duration (s): ${_preferences.getRestTimerDuration()}');
    buffer.writeln(
        '- Play sound on end: ${_preferences.getPlaySoundOnTimerEnd()}');
    buffer.writeln('');
  }

  Future<void> _appendPermissionStatus(StringBuffer buffer) async {
    buffer.writeln("Permissions:");
    buffer.writeln(
        "- Notifications: ${await _safeStatus(Permission.notification)}");

    if (Platform.isAndroid) {
      buffer.writeln(
          "- Exact alarms: ${await _safeStatus(Permission.scheduleExactAlarm)}");
      buffer.writeln(
          "- Ignore battery optimizations: ${await _safeStatus(Permission.ignoreBatteryOptimizations)}");
    } else if (Platform.isIOS) {
      buffer.writeln("- Exact alarms: n/a (Android only)");
      buffer.writeln("- Ignore battery optimizations: n/a (Android only)");
    } else {
      buffer.writeln("- Exact alarms: n/a");
      buffer.writeln("- Ignore battery optimizations: n/a");
    }

    buffer.writeln("");
  }

  Future<void> _appendPowerStatus(StringBuffer buffer) async {
    buffer.writeln('Power/Background Status:');

    if (kIsWeb) {
      buffer.writeln('- Platform: web');
      buffer.writeln('');
      return;
    }

    if (!Platform.isAndroid) {
      buffer.writeln('- Platform: non-Android');
      buffer.writeln('');
      return;
    }

    final status = await _getPowerStatus();
    if (status == null) {
      buffer.writeln('- Status: unavailable');
      buffer.writeln('');
      return;
    }

    buffer.writeln(
        '- Ignoring battery optimizations (native): ${status["ignoringBatteryOptimizations"]}');
    buffer.writeln('- Power save mode: ${status["powerSaveMode"]}');
    buffer.writeln('- Device idle mode: ${status["deviceIdleMode"]}');
    buffer.writeln('- Background restricted: ${status["backgroundRestricted"]}');
    buffer.writeln(
        '- App standby bucket: ${_formatStandbyBucket(status["appStandbyBucket"], status["appStandbyBucketLabel"])}');
    buffer.writeln(
        '- Foreground timer service running: ${status["foregroundServiceRunning"]}');
    buffer.writeln('');
  }

  Future<void> _appendNotificationChannel(StringBuffer buffer) async {
    buffer.writeln('Notification Channel:');

    if (!Platform.isAndroid) {
      buffer.writeln('- Platform: non-Android');
      buffer.writeln('');
      return;
    }

    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) {
      buffer.writeln('- Android notifications plugin unavailable');
      buffer.writeln('');
      return;
    }

    try {
      final channels = await android.getNotificationChannels();
      if (channels == null) {
        buffer.writeln('- Channels: unavailable');
        buffer.writeln('');
        return;
      }

      AndroidNotificationChannel? timerChannel;
      for (final channel in channels) {
        if (channel.id == 'timer_channel_id') {
          timerChannel = channel;
          break;
        }
      }

      if (timerChannel == null) {
        buffer.writeln('- timer_channel_id: missing');
        buffer.writeln('');
        return;
      }

      buffer.writeln('- id: ${timerChannel.id}');
      buffer.writeln('- name: ${timerChannel.name}');
      buffer.writeln('- description: ${timerChannel.description}');
      buffer.writeln('- importance: ${_formatEnum(timerChannel.importance)}');
      buffer.writeln('- playSound: ${timerChannel.playSound}');
      buffer.writeln('- enableVibration: ${timerChannel.enableVibration}');
      buffer.writeln('- enableLights: ${timerChannel.enableLights}');
      buffer.writeln('- showBadge: ${timerChannel.showBadge}');
    } catch (e) {
      AppLogger.warning('TimerDebugReporter: failed to read channels', e);
      buffer.writeln('- Channels: unavailable');
    }

    buffer.writeln('');
  }

  Future<void> _appendTimerState(StringBuffer buffer) async {
    await _timerManager.initialize();
    final snapshot = _timerManager.debugSnapshot();

    buffer.writeln('Rest Timer State:');
    for (final entry in snapshot.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value}');
    }
    buffer.writeln('');
  }

  Future<void> _appendTimerLogs(StringBuffer buffer) async {
    final entries = await _debugLog.getEntries();
    buffer.writeln('Recent Timer Events:');
    if (entries.isEmpty) {
      buffer.writeln('- (none)');
      buffer.writeln('');
      return;
    }
    for (final entry in entries) {
      buffer.writeln('- $entry');
    }
    buffer.writeln('');
  }

  Future<Map<String, dynamic>?> _getPowerStatus() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _powerChannel.invokeMethod<dynamic>('getPowerStatus');
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (e) {
      AppLogger.warning('TimerDebugReporter: failed to read power status', e);
    }
    return null;
  }

  String _formatStandbyBucket(Object? bucket, Object? label) {
    if (bucket == null && label == null) return 'unknown';
    if (bucket != null && label != null) {
      return '${label.toString()} (${bucket.toString()})';
    }
    return label?.toString() ?? bucket.toString();
  }

  Future<String> _safeStatus(Permission permission) async {
    try {
      final status = await permission.status;
      return _formatPermission(status);
    } catch (e) {
      return 'unknown';
    }
  }

  String _formatPermission(PermissionStatus status) {
    if (status.isGranted) return 'granted';
    if (status.isDenied) return 'denied';
    if (status.isPermanentlyDenied) return 'permanently denied';
    if (status.isRestricted) return 'restricted';
    if (status.isLimited) return 'limited';
    return status.toString();
  }

  String _formatEnum(Object? value) {
    if (value == null) return 'unknown';
    final text = value.toString();
    final dot = text.indexOf('.');
    return dot == -1 ? text : text.substring(dot + 1);
  }

  Future<void> scheduleHeadsUpTest({
    Duration delay = const Duration(seconds: 10),
  }) async {
    final permissionsGranted =
        await AudioPlayerUtil.requestNotificationPermissions();
    if (!permissionsGranted) {
      throw Exception('Notification permission denied');
    }

    if (!_timezoneReady) {
      try {
        tz_data.initializeTimeZones();
        _timezoneReady = true;
      } catch (e) {
        AppLogger.warning('TimerDebugReporter: timezone init failed', e);
      }
    }

    final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);

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

    Future<void> scheduleWithMode(AndroidScheduleMode mode) async {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        1203,
        'Timer Notification Test',
        'If you see this, timer notifications are working.',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    if (Platform.isAndroid) {
      try {
        await scheduleWithMode(AndroidScheduleMode.exactAllowWhileIdle);
      } catch (e) {
        AppLogger.warning(
            'TimerDebugReporter: exact schedule failed, retrying inexact', e);
        await scheduleWithMode(AndroidScheduleMode.inexactAllowWhileIdle);
      }
      return;
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      1203,
      'Timer Notification Test',
      'If you see this, timer notifications are working.',
      scheduledTime,
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
