import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/database_service.dart';

/// Mobile/Desktop database service implementation that uses SQLite
/// This implementation is used on non-web platforms
class DatabaseServiceImpl implements DatabaseInterface {
  static final DatabaseServiceImpl _instance = DatabaseServiceImpl._internal();
  final DatabaseService _sqliteService = DatabaseService();

  factory DatabaseServiceImpl() => _instance;

  DatabaseServiceImpl._internal();

  @override
  Future<void> initialize() async {
    // SQLite database is initialized automatically when first accessed
    // This method is included for interface compatibility
    await _sqliteService.database;
  }

  @override
  Future<List<Exercise>> getExercises() async {
    return await _sqliteService.getExercises();
  }

  @override
  Future<Exercise?> getExercise(String id) async {
    return await _sqliteService.getExercise(id);
  }

  @override
  Future<void> insertExercise(Exercise exercise) async {
    await _sqliteService.insertExercise(exercise);
  }

  @override
  Future<void> updateExercise(Exercise exercise) async {
    await _sqliteService.updateExercise(exercise);
  }

  @override
  Future<void> deleteExercise(String id) async {
    await _sqliteService.deleteExercise(id);
  }

  @override
  Future<List<Workout>> getWorkouts() async {
    return await _sqliteService.getWorkouts();
  }

  @override
  Future<Workout?> getWorkout(String id) async {
    return await _sqliteService.getWorkout(id);
  }

  @override
  Future<void> insertWorkout(Workout workout) async {
    await _sqliteService.insertWorkout(workout);
  }

  @override
  Future<void> updateWorkout(Workout workout) async {
    await _sqliteService.updateWorkout(workout);
  }

  @override
  Future<void> deleteWorkout(String id) async {
    await _sqliteService.deleteWorkout(id);
  }

  @override
  Future<List<FitnessMetric>> getMetrics() async {
    return await _sqliteService.getMetrics();
  }

  @override
  Future<List<FitnessMetric>> getMetricsByType(MetricType type) async {
    return await _sqliteService.getMetricsByType(type);
  }

  @override
  Future<List<FitnessMetric>> getMetricsByDateRange(
      DateTime start, DateTime end) async {
    return await _sqliteService.getMetricsByDateRange(start, end);
  }

  @override
  Future<List<FitnessMetric>> getMetricsByTypeAndDateRange(
    MetricType type,
    DateTime start,
    DateTime end,
  ) async {
    return await _sqliteService.getMetricsByTypeAndDateRange(
      type,
      start,
      end,
    );
  }

  @override
  Future<FitnessMetric?> getLatestMetricByType(MetricType type) async {
    return await _sqliteService.getLatestMetricByType(type);
  }

  @override
  Future<void> insertMetric(FitnessMetric metric) async {
    await _sqliteService.insertMetric(metric);
  }

  @override
  Future<void> updateMetric(FitnessMetric metric) async {
    await _sqliteService.updateMetric(metric);
  }

  @override
  Future<void> deleteMetric(String id) async {
    await _sqliteService.deleteMetric(id);
  }
}
