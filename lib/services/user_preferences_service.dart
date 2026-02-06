import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Service for managing user preferences
class UserPreferencesService {
  // Keys for preferences
  static const String _restTimerDurationKey = 'rest_timer_duration';
  static const String _useMetricUnitsKey = 'use_metric_units';
  static const String _playSoundOnTimerEndKey = 'play_sound_on_timer_end';

  // Default values
  static const int _defaultRestTimerDuration = 90; // Default 90 seconds
  static const bool _defaultUseMetricUnits = false; // Default to imperial (Lbs)
  static const bool _defaultPlaySoundOnTimerEnd =
      true; // Default to playing sound

  /// Get the default rest timer duration
  static int get defaultRestTimerDuration => _defaultRestTimerDuration;

  /// Get the default weight unit setting
  static bool get defaultUseMetricUnits => _defaultUseMetricUnits;

  /// Get the default sound setting
  static bool get defaultPlaySoundOnTimerEnd => _defaultPlaySoundOnTimerEnd;

  // Singleton pattern
  static final UserPreferencesService _instance =
      UserPreferencesService._internal();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (!_initialized) {
      try {
        _prefs = await SharedPreferences.getInstance();
        _initialized = true;
      } catch (e, stackTrace) {
        AppLogger.error('Error initializing SharedPreferences', e, stackTrace);
      }
    }
  }

  /// Get rest timer duration in seconds
  int getRestTimerDuration() {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return _defaultRestTimerDuration;
    }
    try {
      return _prefs.getInt(_restTimerDurationKey) ?? _defaultRestTimerDuration;
    } catch (e) {
      AppLogger.error('Error getting rest timer duration', e);
      return _defaultRestTimerDuration;
    }
  }

  /// Set rest timer duration in seconds
  Future<bool> setRestTimerDuration(int seconds) async {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return false;
    }
    try {
      final success = await _prefs.setInt(_restTimerDurationKey, seconds);
      AppLogger.debug(
          'setRestTimerDuration: seconds=$seconds, success=$success');
      return success;
    } catch (e) {
      AppLogger.error('Error setting rest timer duration', e);
      return false;
    }
  }

  /// Reset to default
  Future<bool> resetRestTimerDuration() {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return Future.value(false);
    }
    try {
      return _prefs.remove(_restTimerDurationKey);
    } catch (e) {
      AppLogger.error('Error resetting rest timer duration', e);
      return Future.value(false);
    }
  }

  /// Get whether to use metric units (Kg) instead of imperial (Lbs)
  bool getUseMetricUnits() {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return _defaultUseMetricUnits;
    }
    try {
      return _prefs.getBool(_useMetricUnitsKey) ?? _defaultUseMetricUnits;
    } catch (e) {
      AppLogger.error('Error getting use metric units', e);
      return _defaultUseMetricUnits;
    }
  }

  /// Set whether to use metric units (Kg) instead of imperial (Lbs)
  Future<bool> setUseMetricUnits(bool useMetric) async {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return false;
    }
    try {
      final success = await _prefs.setBool(_useMetricUnitsKey, useMetric);
      AppLogger.debug(
          'setUseMetricUnits: useMetric=$useMetric, success=$success');
      return success;
    } catch (e) {
      AppLogger.error('Error setting use metric units', e);
      return false;
    }
  }

  /// Reset weight unit to default (imperial/Lbs)
  Future<bool> resetWeightUnit() {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return Future.value(false);
    }
    try {
      return _prefs.remove(_useMetricUnitsKey);
    } catch (e) {
      AppLogger.error('Error resetting weight unit', e);
      return Future.value(false);
    }
  }

  /// Get the current weight unit label (Kg or Lbs)
  String getWeightUnitLabel() {
    return getUseMetricUnits() ? 'Kg' : 'Lbs';
  }

  /// Get whether to play sound when timer ends
  bool getPlaySoundOnTimerEnd() {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return _defaultPlaySoundOnTimerEnd;
    }
    try {
      return _prefs.getBool(_playSoundOnTimerEndKey) ??
          _defaultPlaySoundOnTimerEnd;
    } catch (e) {
      AppLogger.error('Error getting play sound on timer end', e);
      return _defaultPlaySoundOnTimerEnd;
    }
  }

  /// Set whether to play sound when timer ends
  Future<bool> setPlaySoundOnTimerEnd(bool playSound) async {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return false;
    }
    try {
      final success = await _prefs.setBool(_playSoundOnTimerEndKey, playSound);
      AppLogger.debug(
          'setPlaySoundOnTimerEnd: playSound=$playSound, success=$success');
      return success;
    } catch (e) {
      AppLogger.error('Error setting play sound on timer end', e);
      return false;
    }
  }

  /// Reset sound setting to default (enabled)
  Future<bool> resetSoundSetting() {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return Future.value(false);
    }
    try {
      return _prefs.remove(_playSoundOnTimerEndKey);
    } catch (e) {
      AppLogger.error('Error resetting sound setting', e);
      return Future.value(false);
    }
  }

  /// Export user preferences to a portable map
  Future<Map<String, dynamic>> exportPreferences() async {
    if (!_initialized) {
      await initialize();
    }

    return {
      'restTimerDuration': getRestTimerDuration(),
      'useMetricUnits': getUseMetricUnits(),
      'playSoundOnTimerEnd': getPlaySoundOnTimerEnd(),
    };
  }

  /// Apply preferences from a portable map
  Future<void> applyPreferences(Map<String, dynamic> preferences) async {
    if (!_initialized) {
      await initialize();
    }

    if (preferences.containsKey('restTimerDuration')) {
      final value = preferences['restTimerDuration'];
      if (value is int) {
        await setRestTimerDuration(value);
      }
    }

    if (preferences.containsKey('useMetricUnits')) {
      final value = preferences['useMetricUnits'];
      if (value is bool) {
        await setUseMetricUnits(value);
      }
    }

    if (preferences.containsKey('playSoundOnTimerEnd')) {
      final value = preferences['playSoundOnTimerEnd'];
      if (value is bool) {
        await setPlaySoundOnTimerEnd(value);
      }
    }
  }
}
