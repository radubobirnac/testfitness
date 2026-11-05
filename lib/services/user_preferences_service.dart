import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Service for managing user preferences
class UserPreferencesService {
  // Keys for preferences
  static const String _restTimerDurationKey = 'rest_timer_duration';
  static const String _useMetricUnitsKey = 'use_metric_units';
  static const String _playSoundOnTimerEndKey = 'play_sound_on_timer_end';
  // Bar & plates are stored per unit so switching units never shows a
  // 20 "lb" bar or 45 "kg" plates.
  static const String _barWeightKgKey = 'bar_weight_kg';
  static const String _barWeightLbKey = 'bar_weight_lb';
  static const String _availablePlatesKgKey = 'available_plates_kg';
  static const String _availablePlatesLbKey = 'available_plates_lb';

  // Default values
  static const int _defaultRestTimerDuration = 90; // Default 90 seconds
  static const bool _defaultUseMetricUnits = false; // Default to imperial (Lbs)
  static const bool _defaultPlaySoundOnTimerEnd =
      true; // Default to playing sound

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
