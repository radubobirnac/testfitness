import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/screens/app_loader.dart'; // Import for global plugin instance

/// Utility class for playing audio and managing timer sounds in the app
///
/// This class uses two approaches to play sounds:
/// 1. Primary: Local notifications with custom sounds for background support
/// 2. Fallback: Direct audio playback via audioplayers for foreground operation
///
/// The notification approach is essential for playing sounds when the app is in
/// the background or when the device is locked. Android requires sound files to be
/// placed in the res/raw directory, while iOS needs them in the Runner/Resources folder.
class AudioPlayerUtil {
  // Singleton pattern
  static final AudioPlayerUtil _instance = AudioPlayerUtil._internal();
  factory AudioPlayerUtil() => _instance;
  AudioPlayerUtil._internal() {
    _configureAudioPlayers();
  }

  // Configure audio players for background playback
  void _configureAudioPlayers() {
    // Configure end player for background playback
    _timerEndPlayer.setReleaseMode(ReleaseMode.release);
    _timerEndPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  // Audio player instances (all restored)
  final AudioPlayer _timerEndPlayer = AudioPlayer();
  final AudioPlayer _timerStartPlayer = AudioPlayer();
  final AudioPlayer _timerTickPlayer = AudioPlayer();

  // Timer for periodic ticks
  Timer? _tickTimer;

  // Callback for timer completion
  Function? _onTimerComplete;

  /// Ensure audio player works after returning from background
  ///
  /// This should be called when the app is about to go to the background
  /// or when a timer is close to completion to ensure the audio will play
  /// properly when needed.
  Future<void> prepareForBackgroundAudio() async {
    try {
      // Release any previous resources and reinitialize player
      await _timerEndPlayer.stop();

      // Configure for maximum impact
      await _timerEndPlayer.setReleaseMode(ReleaseMode.release);
      await _timerEndPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _timerEndPlayer.setVolume(1.0);
    } catch (e) {
      AppLogger.audio('Error preparing audio for background', e.toString());
    }
  }

  /// Apply strong vibration pattern
  Future<void> _vibrateStrongPattern() async {
    try {
      // Create a strong vibration pattern
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.heavyImpact();

      // For even stronger effect on supported devices
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.vibrate();

      // Add a longer direct vibration as fallback
      await Future.delayed(const Duration(milliseconds: 200));
      await SystemChannels.platform
          .invokeMethod<void>('HapticFeedback.vibrate');

      // For Android devices that may need direct vibration
      if (!kIsWeb && Platform.isAndroid) {
        await _vibrateDirectAndroid();
      }
    } catch (e) {
      AppLogger.audio('Error during vibration', e.toString());
    }
  }

  /// Try to vibrate directly on Android using platform channels
  Future<void> _vibrateDirectAndroid() async {
    try {
      const platform = MethodChannel('com.testfitness/vibration');
      await platform.invokeMethod('vibrate', {'duration': 500});
    } catch (e) {
      // Fallback to builtin vibration with longer duration
      try {
        await SystemChannels.platform
            .invokeMethod('HapticFeedback.vibrate', {'duration': 500});
      } catch (e) {
        // Ignore errors - at least we tried
      }
    }
  }

  /// Apply light vibration pattern
  Future<void> _vibrateLightPattern() async {
    try {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger.audio('Error during light vibration', e.toString());
    }
  }

  /// Request notification permissions when user wants to use timer notifications
  /// This is called only when the user actually wants to use timer features
  static Future<bool> requestNotificationPermissions() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation == null) {
          AppLogger.warning(
              'Notification permissions: Android implementation unavailable');
          return false;
        }

        // Request notification permissions
        final notificationPermission =
            await androidImplementation.requestNotificationsPermission();

        // Request exact alarms permission for precise timer notifications
        final alarmPermission =
            await androidImplementation.requestExactAlarmsPermission();

        final notificationsGranted = notificationPermission ?? true;
        final exactAlarmsGranted = alarmPermission ?? true;

        AppLogger.audio(
          'Notification permission result',
          'notifications=$notificationsGranted, exactAlarms=$exactAlarmsGranted',
        );

        if (!notificationsGranted) {
          AppLogger.warning('Notification permission denied');
          return false;
        }

        if (!exactAlarmsGranted) {
          AppLogger.warning(
              'Exact alarm permission not granted; will use inexact scheduling');
        }

        return true;
      }

      return true; // iOS permissions are handled during initialization
    } catch (e) {
      AppLogger.audio(
          'Error requesting notification permissions', e.toString());
      return false;
    }
  }

  /// Play the ship bell sound when the timer ends - prioritizing notification method for background support
  ///
  /// This method uses a two-tier approach:
  /// 1. First tries to show a local notification with the sound file (works in background)
  /// 2. Falls back to direct audio playback if notification fails (works in foreground)
  ///
  /// The notification is configured for maximum priority to break through Do Not Disturb
  /// and other system restrictions. On Android, it uses the alarm category for higher priority.
  Future<void> playTimerEndSound({bool useNotification = true}) async {
    try {
      // Check user preferences
      if (!UserPreferencesService().getPlaySoundOnTimerEnd()) {
        _onTimerComplete?.call(); // Call completion even if sound is off
        return;
      }

      AppLogger.audio('Attempting to play timer end sound');

      // APPROACH 1: Try notification approach first for background support
      if (useNotification) {
        try {
          // Define Android notification details with custom sound
          final AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'timer_channel_id', // Channel ID - must match channel created in app_loader.dart
            'Timer Notifications', // Channel Name
            channelDescription: 'Channel for timer completion sounds',
            importance: Importance.max,
            priority: Priority.max, // MAXIMUM priority (previously high)
            category: AndroidNotificationCategory
                .alarm, // IMPORTANT: Mark as alarm category to bypass Do Not Disturb
            fullScreenIntent: true, // Request full attention
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
                'shipbell'), // Use shipbell (filename without extension)
            ticker: 'Timer Complete!', // Ticker text for accessibility
            enableVibration: true, // Enable vibration through channel
          );

          // Define iOS notification details with custom sound
          const DarwinNotificationDetails iOSPlatformChannelSpecifics =
              DarwinNotificationDetails(
            presentSound: true, // Allow sound
            sound: 'shipbell.wav', // Match filename in Runner/Resources
            presentAlert: false, // Don't show an alert visually
            presentBadge: false, // Don't update badge count
            interruptionLevel: InterruptionLevel.timeSensitive, // Higher priority
          );

          // Create the platform channel specifics (this was missing or incorrect)
          final NotificationDetails platformChannelSpecifics =
              NotificationDetails(
                  android: androidPlatformChannelSpecifics,
                  iOS: iOSPlatformChannelSpecifics);

          // Show the notification (this plays the sound)
          await flutterLocalNotificationsPlugin.show(
            0, // Notification ID
            'Timer Complete!', // Notification Title (won't show if presentAlert=false)
            'Time for your next set!', // Notification Body (won't show if presentAlert=false)
            platformChannelSpecifics,
          );
          AppLogger.audio('Displayed notification with sound');
          // If notification succeeded, skip fallback playback.
          _vibrateStrongPattern();
          _onTimerComplete?.call();
          return;
        } catch (e) {
          AppLogger.audio('Error showing notification', e.toString());
        }
      }

      // FALLBACK APPROACH: Direct audio playback (works in foreground)
      try {
        // Set optimal playback settings for notifications
        await _timerEndPlayer.setReleaseMode(ReleaseMode.release);
        await _timerEndPlayer.setPlayerMode(PlayerMode.lowLatency);
        await _timerEndPlayer.setVolume(1.0);

        // Play the sound
        await _timerEndPlayer.play(AssetSource('audio/shipbell.wav'));
        AppLogger.audio('Fallback: Played sound using AudioPlayer');
      } catch (e2) {
        AppLogger.audio(
            'Error playing with AudioPlayer fallback', e2.toString());
      }

      // Enhanced vibration pattern for timer completion
      _vibrateStrongPattern();

      // Call completion callback if set
      _onTimerComplete?.call();
    } catch (e) {
      AppLogger.audio('Error in playTimerEndSound', e.toString());
      // Fallback or error handling if all fails
      _onTimerComplete?.call(); // Ensure completion callback still runs
    }
  }

  /// Play a sound when the timer starts (using audioplayers)
  Future<void> playTimerStartSound() async {
    try {
      await _timerStartPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _timerStartPlayer.play(AssetSource('audio/shipbell.wav'),
          volume: 0.5);
      AppLogger.audio('Played start sound');

      // Enhanced light vibration pattern
      _vibrateLightPattern();
    } catch (e) {
      AppLogger.audio('Error playing timer start sound', e.toString());
    }
  }

  /// Play a tick sound for the timer (using audioplayers)
  Future<void> playTimerTickSound() async {
    try {
      await _timerTickPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _timerTickPlayer.play(AssetSource('audio/shipbell.wav'),
          volume: 0.2);
    } catch (e) {
      AppLogger.audio('Error playing timer tick sound', e.toString());
    }
  }

  /// Start periodic tick sounds
  void startPeriodicTicks({int intervalSeconds = 5}) {
    // Stop any existing tick timer
    stopPeriodicTicks();

    // Play initial tick
    playTimerTickSound();

    // Start periodic timer
    _tickTimer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      playTimerTickSound();
    });
  }

  /// Stop periodic tick sounds
  void stopPeriodicTicks() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// Set a callback to be called when the timer completes
  void setOnTimerComplete(Function callback) {
    _onTimerComplete = callback;
  }

  /// Stop any currently playing sounds
  Future<void> stopSound() async {
    try {
      await _timerEndPlayer.stop();
      await _timerStartPlayer.stop();
      await _timerTickPlayer.stop();
      stopPeriodicTicks();
    } catch (e) {
      AppLogger.audio('Error stopping sounds', e.toString());
    }
  }

  /// Dispose all audio players
  Future<void> dispose() async {
    try {
      stopPeriodicTicks();
      await _timerEndPlayer.dispose();
      await _timerStartPlayer.dispose();
      await _timerTickPlayer.dispose();
      _onTimerComplete = null;
    } catch (e) {
      AppLogger.audio('Error disposing audio players', e.toString());
    }
  }
}
