import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/services/database/database_impl.dart';

/// Stub class to maintain compatibility with existing code
/// This class simply forwards all calls to the new conditional implementation
class WebDatabaseService {
  // Forward to the new implementation
  final _impl = DatabaseImpl();

  WebDatabaseService._internal();

  static final WebDatabaseService _instance = WebDatabaseService._internal();

  factory WebDatabaseService() => _instance;

  /// Initialize the database with default data
  Future<void> initialize() async => await _impl.initialize();

  /// Get all exercises
  Future<List<Exercise>> getExercises() async => await _impl.getExercises();

  /// Get exercise by ID
  Future<Exercise?> getExercise(String id) async => await _impl.getExercise(id);

  /// Insert a new exercise
  Future<void> insertExercise(Exercise exercise) async =>
      await _impl.insertExercise(exercise);

  /// Update an exercise
  Future<void> updateExercise(Exercise exercise) async =>
      await _impl.updateExercise(exercise);

  /// Delete an exercise
  Future<void> deleteExercise(String id) async =>
      await _impl.deleteExercise(id);

  /// Get all workouts with their sets
  Future<List<Workout>> getWorkouts() async => await _impl.getWorkouts();

  /// Get workout by ID with its sets
  Future<Workout?> getWorkout(String id) async => await _impl.getWorkout(id);

  /// Insert a new workout with its sets
  Future<void> insertWorkout(Workout workout) async =>
      await _impl.insertWorkout(workout);

  /// Update a workout and its sets
  Future<void> updateWorkout(Workout workout) async =>
      await _impl.updateWorkout(workout);

  /// Delete a workout and its sets
  Future<void> deleteWorkout(String id) async => await _impl.deleteWorkout(id);
}
