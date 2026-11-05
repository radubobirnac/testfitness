import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Training experience the user picked during first-run setup. Informational
/// for now (e.g. beginners get warm-up / RPE tips).
enum ExperienceLevel { beginner, intermediate, advanced }

/// Service for managing user preferences
class UserPreferencesService {
  // Keys for preferences (public so AppBloc / RestPreferencesService read
  // the same storage).
  static const String restTimerDurationKey = 'rest_timer_duration';
  static const String useMetricUnitsKey = 'use_metric_units';
  static const String playSoundOnTimerEndKey = 'play_sound_on_timer_end';
  static const String smartRestEnabledKey = 'smart_rest_enabled';
  static const String workoutPreferencesKey = 'workout_preferences_v1';
  static const String _restTimerDurationKey = restTimerDurationKey;
  static const String _useMetricUnitsKey = useMetricUnitsKey;
  static const String _playSoundOnTimerEndKey = playSoundOnTimerEndKey;
  static const String _workoutPrefsMigratedKey =
      'workout_preferences_migrated_v1';
  static const String _userProfileKey = 'user_profile';
  // Bar & plates are stored per unit so switching units never shows a
  // 20 "lb" bar or 45 "kg" plates.
  static const String _barWeightKgKey = 'bar_weight_kg';
  static const String _barWeightLbKey = 'bar_weight_lb';
  static const String _availablePlatesKgKey = 'available_plates_kg';
  static const String _availablePlatesLbKey = 'available_plates_lb';
  static const String _experienceLevelKey = 'experience_level';

  // Default values
  static const int _defaultRestTimerDuration = 90; // Default 90 seconds
  static const bool _defaultUseMetricUnits = false; // Default to imperial (Lbs)
  static const bool _defaultPlaySoundOnTimerEnd =
      true; // Default to playing sound
  static const bool defaultSmartRestEnabled = true;

  /// Workout-suggestion preferences used by the coach (and AI, if a key is
  /// set). Values here are the defaults.
  static const Map<String, dynamic> defaultWorkoutPreferences = {
    'defaultBodyParts': 2,
    'defaultDurationMinutes': 45,
    'excludeCore': false,
    'workoutFocus': 'balanced',
    'preferredBodyParts': <String>[],
  };

  /// Values offered by the "Workout Focus" dropdown.
  static const List<String> workoutFocusValues = [
    'balanced', 'strength', 'endurance', 'upper', 'lower', //
  ];

  /// Body part names offered as "Preferred Body Parts" chips.
  static const List<String> workoutBodyParts = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Cardio', //
  ];

  /// Default bar weight: 20 kg Olympic bar / 45 lb bar.
  static double defaultBarWeight({required bool metric}) =>
      metric ? 20.0 : 45.0;

  /// Standard plate sizes a typical gym has (largest first). Also the
  /// default for [getAvailablePlates].
  static List<double> standardPlates({required bool metric}) => metric
      ? const [25, 20, 15, 10, 5, 2.5, 1.25]
      : const [45, 35, 25, 10, 5, 2.5];

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

  /// A separate instance backed by [prefs] (tests).
  @visibleForTesting
  UserPreferencesService.withPrefs(SharedPreferences prefs) {
    _prefs = prefs;
    _initialized = true;
  }

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Forget the attached SharedPreferences so the next [initialize] picks up
  /// a fresh (mock) instance (tests).
  @visibleForTesting
  void resetForTesting() => _initialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (!_initialized) {
      try {
        _prefs = await SharedPreferences.getInstance();
        _initialized = true;
        await migrateWorkoutPreferencesFromProfile();
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

  /// Bar weight in the given unit (defaults to the current unit setting).
  double getBarWeight({bool? metric}) {
    final useMetric = metric ?? getUseMetricUnits();
    final fallback = defaultBarWeight(metric: useMetric);
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return fallback;
    }
    try {
      final value =
          _prefs.getDouble(useMetric ? _barWeightKgKey : _barWeightLbKey);
      return (value != null && value >= 0) ? value : fallback;
    } catch (e) {
      AppLogger.error('Error getting bar weight', e);
      return fallback;
    }
  }

  /// Set bar weight in the given unit (defaults to the current unit setting).
  Future<bool> setBarWeight(double weight, {bool? metric}) async {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return false;
    }
    try {
      final useMetric = metric ?? getUseMetricUnits();
      return await _prefs.setDouble(
          useMetric ? _barWeightKgKey : _barWeightLbKey, weight);
    } catch (e) {
      AppLogger.error('Error setting bar weight', e);
      return false;
    }
  }

  /// Plate sizes available at the user's gym, largest first, in the given
  /// unit (defaults to the current unit setting). Unlimited pairs assumed.
  List<double> getAvailablePlates({bool? metric}) {
    final useMetric = metric ?? getUseMetricUnits();
    final fallback = List<double>.of(standardPlates(metric: useMetric));
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return fallback;
    }
    try {
      final stored = _prefs.getStringList(
          useMetric ? _availablePlatesKgKey : _availablePlatesLbKey);
      if (stored == null) return fallback;
      final plates = stored
          .map(double.tryParse)
          .whereType<double>()
          .where((p) => p > 0)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      return plates;
    } catch (e) {
      AppLogger.error('Error getting available plates', e);
      return fallback;
    }
  }

  /// Set the plate sizes available, in the given unit (defaults to the
  /// current unit setting).
  Future<bool> setAvailablePlates(List<double> plates, {bool? metric}) async {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return false;
    }
    try {
      final useMetric = metric ?? getUseMetricUnits();
      final sorted = plates.where((p) => p > 0).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      return await _prefs.setStringList(
          useMetric ? _availablePlatesKgKey : _availablePlatesLbKey,
          sorted.map((p) => p.toString()).toList());
    } catch (e) {
      AppLogger.error('Error setting available plates', e);
      return false;
    }
  }

  /// Experience level chosen during first-run setup, or null if never set.
  ExperienceLevel? getExperienceLevel() {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return null;
    }
    try {
      final stored = _prefs.getString(_experienceLevelKey);
      for (final level in ExperienceLevel.values) {
        if (level.name == stored) return level;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting experience level', e);
      return null;
    }
  }

  /// Store the experience level chosen during first-run setup.
  Future<bool> setExperienceLevel(ExperienceLevel level) async {
    if (!_initialized) {
      AppLogger.warning('UserPreferencesService not initialized');
      return false;
    }
    try {
      return await _prefs.setString(_experienceLevelKey, level.name);
    } catch (e) {
      AppLogger.error('Error setting experience level', e);
      return false;
    }
  }

  /// Whether rest defaults come from the exercise type (heavy barbell 2:30,
  /// compounds 2:00, machine/cable 1:30, isolation 1:00) instead of the
  /// global rest duration.
  bool getSmartRestEnabled() {
    if (!_initialized) return defaultSmartRestEnabled;
    try {
      return _prefs.getBool(smartRestEnabledKey) ?? defaultSmartRestEnabled;
    } catch (e) {
      AppLogger.error('Error getting smart rest setting', e);
      return defaultSmartRestEnabled;
    }
  }

  Future<bool> setSmartRestEnabled(bool enabled) async {
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    try {
      return await _prefs.setBool(smartRestEnabledKey, enabled);
    } catch (e) {
      AppLogger.error('Error setting smart rest setting', e);
      return false;
    }
  }

  /// Workout-suggestion preferences, always with every key present:
  /// 'defaultBodyParts' (int 1-3, default 2), 'defaultDurationMinutes' (int,
  /// default 45), 'excludeCore' (bool, default false), 'workoutFocus' (one of
  /// [workoutFocusValues], default 'balanced') and 'preferredBodyParts'
  /// (names from [workoutBodyParts], default empty).
  Map<String, dynamic> getWorkoutPreferences() {
    final stored = <String, dynamic>{};
    if (_initialized) {
      try {
        final raw = _prefs.getString(workoutPreferencesKey);
        if (raw != null) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (k is String) stored[k] = v;
            });
          }
        }
      } catch (e) {
        AppLogger.warning('Ignoring malformed workout preferences', e);
      }
    }
    return _normalizeWorkoutPreferences(stored);
  }

  /// Set one workout-suggestion preference (see [getWorkoutPreferences]).
  Future<void> setWorkoutPreference(String key, dynamic value) async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    final current = getWorkoutPreferences()..[key] = value;
    try {
      await _prefs.setString(workoutPreferencesKey,
          jsonEncode(_normalizeWorkoutPreferences(current)));
    } catch (e) {
      AppLogger.error('Error saving workout preference $key', e);
    }
  }

  static Map<String, dynamic> _normalizeWorkoutPreferences(
      Map<String, dynamic> raw) {
    final d = defaultWorkoutPreferences;
    final bodyParts = raw['defaultBodyParts'];
    final duration = raw['defaultDurationMinutes'];
    final excludeCore = raw['excludeCore'];
    final focus = raw['workoutFocus'];
    final preferred = raw['preferredBodyParts'];
    return {
      'defaultBodyParts': bodyParts is num
          ? bodyParts.round().clamp(1, 3)
          : d['defaultBodyParts'],
      'defaultDurationMinutes': duration is num && duration > 0
          ? duration.round()
          : d['defaultDurationMinutes'],
      'excludeCore': excludeCore is bool ? excludeCore : d['excludeCore'],
      'workoutFocus': focus is String && workoutFocusValues.contains(focus)
          ? focus
          : d['workoutFocus'],
      'preferredBodyParts': preferred is List
          ? preferred
              .whereType<String>()
              .where(workoutBodyParts.contains)
              .toSet()
              .toList()
          : <String>[],
    };
  }

  /// One-time copy of workout preferences that older versions kept in the
  /// saved user profile ('user_profile' JSON, `preferences` map).
  Future<void> migrateWorkoutPreferencesFromProfile() async {
    if (!_initialized) return;
    try {
      if (_prefs.getBool(_workoutPrefsMigratedKey) ?? false) return;
      if (_prefs.getString(workoutPreferencesKey) == null) {
        final profileJson = _prefs.getString(_userProfileKey);
        if (profileJson != null) {
          final profile = jsonDecode(profileJson);
          final old = profile is Map ? profile['preferences'] : null;
          if (old is Map) {
            final picked = <String, dynamic>{};
            for (final key in defaultWorkoutPreferences.keys) {
              if (old.containsKey(key)) picked[key] = old[key];
            }
            if (picked.isNotEmpty) {
              await _prefs.setString(workoutPreferencesKey,
                  jsonEncode(_normalizeWorkoutPreferences(picked)));
            }
          }
        }
      }
      await _prefs.setBool(_workoutPrefsMigratedKey, true);
    } catch (e) {
      AppLogger.warning('Could not migrate workout preferences', e);
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
