import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Rest time between working sets, per exercise.
///
/// Each exercise uses the user's override when one is set, else a default by
/// exercise type: heavy barbell compounds 150 s, other barbell/dumbbell
/// compounds 120 s, machine/cable 90 s and isolation lifts 60 s. Overrides
/// are persisted in shared_preferences as one JSON map.
class RestPreferencesService {
  static const String storageKey = 'rest_seconds_by_exercise_v1';

  static const int heavyCompoundSeconds = 150;
  static const int compoundSeconds = 120;
  static const int machineSeconds = 90;
  static const int isolationSeconds = 60;

  /// Rest choices offered in the picker (0:30 … 5:00).
  static const List<int> choices = [
    30, 45, 60, 75, 90, 105, 120, 150, 180, 210, 240, 270, 300, //
  ];

  static final RestPreferencesService _instance =
      RestPreferencesService._internal();
  factory RestPreferencesService() => _instance;
  RestPreferencesService._internal();

  /// A separate instance backed by [prefs] (tests).
  @visibleForTesting
  RestPreferencesService.withPrefs(SharedPreferences prefs) {
    _attach(prefs);
  }

  SharedPreferences? _prefs;
  final Map<String, int> _overrides = {};

  bool get isInitialized => _prefs != null;

  /// Load persisted overrides. Safe to call repeatedly.
  Future<void> initialize() async {
    if (_prefs != null) return;
    try {
      _attach(await SharedPreferences.getInstance());
    } catch (e, stackTrace) {
      AppLogger.error('Error loading rest preferences', e, stackTrace);
    }
  }

  void _attach(SharedPreferences prefs) {
    _prefs = prefs;
    _overrides.clear();
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (key is String && value is num && value > 0) {
            _overrides[key] = value.toInt();
          }
        });
      }
    } catch (e) {
      AppLogger.warning('Ignoring malformed rest preferences', e);
    }
  }

  /// The user's override for [exerciseId], or null when using the default.
  int? overrideFor(String exerciseId) => _overrides[exerciseId];

  /// Rest seconds for [exercise]: the override, else the type default.
  int restSecondsFor(Exercise exercise) =>
      _overrides[exercise.id] ?? defaultRestSecondsFor(exercise);

  /// Set ([seconds] > 0) or clear (null) the override for [exerciseId].
  Future<void> setRestSeconds(String exerciseId, int? seconds) async {
    if (seconds == null || seconds <= 0) {
      _overrides.remove(exerciseId);
    } else {
      _overrides[exerciseId] = seconds;
    }
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      if (_overrides.isEmpty) {
        await prefs.remove(storageKey);
      } else {
        await prefs.setString(storageKey, jsonEncode(_overrides));
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error saving rest preferences', e, stackTrace);
    }
  }

  static const List<String> _isolationKeywords = [
    'curl', 'raise', 'extension', 'fly', 'flye', 'calf', 'shrug', //
    'kickback', 'pushdown', 'crusher', 'pec deck', 'face pull', 'crossover',
    'wrist', 'crunch', 'pullover', 'reverse fly',
  ];

  static const List<String> _machineKeywords = [
    'machine', 'cable', 'smith', 'pulldown', 'leg press', 'hack squat', //
  ];

  static const List<String> _heavyKeywords = [
    'squat', 'deadlift', 'bench press', 'overhead press', 'military press', //
    'push press',
  ];

  /// Default rest by exercise type, from its name and equipment category.
  static int defaultRestSecondsFor(Exercise exercise) {
    final name = exercise.name.toLowerCase();
    final category = (exercise.category ?? '').toLowerCase();
    bool nameHas(List<String> words) => words.any(name.contains);

    if (nameHas(_isolationKeywords)) return isolationSeconds;
    if (category.contains('machine') ||
        category.contains('cable') ||
        nameHas(_machineKeywords)) {
      return machineSeconds;
    }
    final isBarbell =
        category.contains('barbell') || name.contains('barbell');
    if (isBarbell && nameHas(_heavyKeywords)) return heavyCompoundSeconds;
    if (isBarbell ||
        category.contains('dumbbell') ||
        name.contains('dumbbell')) {
      return compoundSeconds;
    }
    return machineSeconds;
  }

  /// "2:30", "1:00", "0:45".
  static String format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
