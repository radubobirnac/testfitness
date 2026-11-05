import 'dart:convert';
import 'dart:html' show window;

import 'package:testfitness/data/default_exercises.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Web database service that uses localStorage for persistence
/// This implementation is only used on web platforms
class DatabaseImpl implements DatabaseInterface {
  static final DatabaseImpl _instance = DatabaseImpl._internal();

  factory DatabaseImpl() => _instance;

  DatabaseImpl._internal();

  // In-memory storage
  final List<Exercise> _exercises = [];
  final List<Workout> _workouts = [];
  final Map<String, List<WorkoutSet>> _workoutSets = {};
  final List<FitnessMetric> _metrics = [];

  // LocalStorage keys
  static const String _exercisesKey = 'testfitness_exercises';
  static const String _workoutsKey = 'testfitness_workouts';
  static const String _workoutSetsKey = 'testfitness_workout_sets';
  static const String _metricsKey = 'testfitness_metrics';

  /// Initialize the database with default data
  @override
  Future<void> initialize() async {
    // Clear any existing data
    _exercises.clear();
    _workouts.clear();
    _workoutSets.clear();
    _metrics.clear();

    // Try to load data from localStorage first
    _loadFromLocalStorage();

    // If no exercises were loaded, insert defaults
    if (_exercises.isEmpty) {
      _insertDefaultExercises();
      _saveExercisesToLocalStorage();
    }
  }

  // Load data from localStorage
  void _loadFromLocalStorage() {
    try {
      // Load exercises
      final exercisesJson = window.localStorage[_exercisesKey];
      if (exercisesJson != null) {
        final List<dynamic> exercisesList = jsonDecode(exercisesJson);
        _exercises.addAll(
          exercisesList.map((e) => Exercise.fromMap(e)).toList(),
        );
      }

      // Load workouts
      final workoutsJson = window.localStorage[_workoutsKey];
      if (workoutsJson != null) {
        final List<dynamic> workoutsList = jsonDecode(workoutsJson);
        for (final workoutMap in workoutsList) {
          final workout = Workout(
            id: workoutMap['id'],
            name: workoutMap['name'],
            description: workoutMap['description'],
            scheduledDate: workoutMap['scheduledDate'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    workoutMap['scheduledDate'])
                : null,
            completedDate: workoutMap['completedDate'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    workoutMap['completedDate'])
                : null,
            // Workout.toMap stores 1/0; older data may hold a bool.
            isCompleted: workoutMap['isCompleted'] == true ||
                workoutMap['isCompleted'] == 1,
            durationMinutes: workoutMap['durationMinutes'],
            notes: workoutMap['notes'],
            sets: [], // Sets are loaded separately
          );
          _workouts.add(workout);
        }
      }

      // Load workout sets (WorkoutSet.fromMap tolerates a missing isWarmup
      // field in data saved before warm-ups existed: it reads as false)
      final workoutSetsJson = window.localStorage[_workoutSetsKey];
      if (workoutSetsJson != null) {
        final Map<String, dynamic> workoutSetsMap = jsonDecode(workoutSetsJson);
        workoutSetsMap.forEach((workoutId, setsJson) {
          final List<dynamic> setsList = setsJson;
          _workoutSets[workoutId] =
              setsList.map((s) => WorkoutSet.fromMap(s)).toList();
        });
      }

      // Load fitness metrics
      final metricsJson = window.localStorage[_metricsKey];
      if (metricsJson != null) {
        final List<dynamic> metricsList = jsonDecode(metricsJson);
        _metrics.addAll(
          metricsList
              .map((m) => FitnessMetric.tryFromMap(
                  Map<String, dynamic>.from(m as Map<dynamic, dynamic>)))
              .whereType<FitnessMetric>(),
        );
      }

      AppLogger.database(
          'Loaded from localStorage: ${_exercises.length} exercises, ${_workouts.length} workouts, ${_metrics.length} metrics');
    } catch (e) {
      AppLogger.error('Error loading from localStorage', e);
    }
  }

  // Save exercises to localStorage
  void _saveExercisesToLocalStorage() {
    try {
      final exercisesJson =
          jsonEncode(_exercises.map((e) => e.toMap()).toList());
      window.localStorage[_exercisesKey] = exercisesJson;
    } catch (e) {
      AppLogger.error('Error saving exercises to localStorage', e);
    }
  }

  // Save workouts to localStorage
  void _saveWorkoutsToLocalStorage() {
    try {
      final workoutsJson = jsonEncode(_workouts.map((w) => w.toMap()).toList());
      window.localStorage[_workoutsKey] = workoutsJson;

      // Save workout sets
      final Map<String, dynamic> workoutSetsMap = {};
      _workoutSets.forEach((workoutId, sets) {
        workoutSetsMap[workoutId] = sets.map((s) => s.toMap()).toList();
      });
      window.localStorage[_workoutSetsKey] = jsonEncode(workoutSetsMap);
    } catch (e) {
      AppLogger.error('Error saving workouts to localStorage', e);
    }
  }

  // Save fitness metrics to localStorage
  void _saveMetricsToLocalStorage() {
    try {
      final metricsJson = jsonEncode(_metrics.map((m) => m.toMap()).toList());
      window.localStorage[_metricsKey] = metricsJson;
    } catch (e) {
      AppLogger.error('Error saving metrics to localStorage', e);
    }
  }

  /// Insert default exercises
  void _insertDefaultExercises() {
    final defaultExercises = buildDefaultExercises();

    AppLogger.database(
        'Adding ${defaultExercises.length} default exercises to web database');
    AppLogger.database(
        'Categories: ${defaultExercises.map((e) => e.category).toSet()}');
    _exercises.addAll(defaultExercises);
  }

  // CRUD operations for exercises

  @override
  Future<List<Exercise>> getExercises() async {
    return List.from(_exercises);
  }

  @override
  Future<Exercise?> getExercise(String id) async {
    try {
      return _exercises.firstWhere((exercise) => exercise.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> insertExercise(Exercise exercise) async {
    _exercises.add(exercise);
    _saveExercisesToLocalStorage();
  }

  @override
  Future<void> updateExercise(Exercise exercise) async {
    final index = _exercises.indexWhere((e) => e.id == exercise.id);
    if (index != -1) {
      _exercises[index] = exercise;
      _saveExercisesToLocalStorage();
    }
  }

  @override
  Future<void> deleteExercise(String id) async {
    _exercises.removeWhere((exercise) => exercise.id == id);
    _saveExercisesToLocalStorage();
  }

  // CRUD operations for workouts

  @override
  Future<List<Workout>> getWorkouts() async {
    try {
      final workouts = List<Workout>.from(_workouts);
      final result = <Workout>[];

      for (var i = 0; i < workouts.length; i++) {
        try {
          final workout = workouts[i];
          final sets = _workoutSets[workout.id] ?? [];

          // Use the fromMap factory with robust deserialization
          final workoutMap = {
            'id': workout.id,
            'name': workout.name,
            'description': workout.description,
            'scheduledDate': workout.scheduledDate?.millisecondsSinceEpoch,
            'completedDate': workout.completedDate?.millisecondsSinceEpoch,
            'isCompleted': workout.isCompleted,
            'durationMinutes': workout.durationMinutes,
            'notes': workout.notes,
          };

          final reconstructedWorkout =
              Workout.fromMap(workoutMap, List.from(sets));
          result.add(reconstructedWorkout);
        } catch (e) {
          AppLogger.error('Error processing workout at index $i', e);
          // Skip this workout and continue with others
        }
      }

      return result;
    } catch (e) {
      AppLogger.error('Error in getWorkouts', e);
      // Return empty list as fallback
      return [];
    }
  }

  @override
  Future<Workout?> getWorkout(String id) async {
    try {
      final workout = _workouts.firstWhere((workout) => workout.id == id);
      final sets = _workoutSets[id] ?? [];

      // Use the fromMap factory with robust deserialization
      final workoutMap = {
        'id': workout.id,
        'name': workout.name,
        'description': workout.description,
        'scheduledDate': workout.scheduledDate?.millisecondsSinceEpoch,
        'completedDate': workout.completedDate?.millisecondsSinceEpoch,
        'isCompleted': workout.isCompleted,
        'durationMinutes': workout.durationMinutes,
        'notes': workout.notes,
      };

      return Workout.fromMap(workoutMap, List.from(sets));
    } catch (e) {
      AppLogger.error('Error getting workout with ID $id', e);
      return null;
    }
  }

  @override
  Future<void> insertWorkout(Workout workout) async {
    AppLogger.database(
        'Inserting workout: ${workout.name} with ${workout.sets.length} sets');
    _workouts.add(workout);
    _workoutSets[workout.id] = List.from(workout.sets);

    // Save to localStorage
    _saveWorkoutsToLocalStorage();
    AppLogger.database(
        'Workout saved to localStorage. Total workouts: ${_workouts.length}');
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    final index = _workouts.indexWhere((w) => w.id == workout.id);
    if (index != -1) {
      _workouts[index] = workout;
      _workoutSets[workout.id] = List.from(workout.sets);

      // Save to localStorage
      _saveWorkoutsToLocalStorage();
    }
  }

  @override
  Future<void> deleteWorkout(String id) async {
    _workouts.removeWhere((workout) => workout.id == id);
    _workoutSets.remove(id);

    // Save to localStorage
    _saveWorkoutsToLocalStorage();
  }

  // Fitness metric methods

  @override
  Future<List<FitnessMetric>> getMetrics() async {
    return _metrics;
  }

  @override
  Future<List<FitnessMetric>> getMetricsByType(MetricType type) async {
    return _metrics.where((metric) => metric.type == type).toList();
  }

  @override
  Future<List<FitnessMetric>> getMetricsByDateRange(
      DateTime start, DateTime end) async {
    return _metrics.where((metric) {
      return metric.date.isAfter(start.subtract(const Duration(days: 1))) &&
          metric.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Future<List<FitnessMetric>> getMetricsByTypeAndDateRange(
      MetricType type, DateTime start, DateTime end) async {
    return _metrics.where((metric) {
      return metric.type == type &&
          metric.date.isAfter(start.subtract(const Duration(days: 1))) &&
          metric.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Future<FitnessMetric?> getLatestMetricByType(MetricType type) async {
    final metrics = _metrics.where((metric) => metric.type == type).toList();
    if (metrics.isEmpty) return null;

    metrics.sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
    return metrics.first;
  }

  @override
  Future<void> insertMetric(FitnessMetric metric) async {
    _metrics.add(metric);
    _saveMetricsToLocalStorage();
  }

  @override
  Future<void> updateMetric(FitnessMetric metric) async {
    final index = _metrics.indexWhere((m) => m.id == metric.id);
    if (index != -1) {
      _metrics[index] = metric;
      _saveMetricsToLocalStorage();
    }
  }

  @override
  Future<void> deleteMetric(String id) async {
    _metrics.removeWhere((metric) => metric.id == id);
    _saveMetricsToLocalStorage();
  }
}
