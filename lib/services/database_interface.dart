import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/workout.dart';

/// Common interface for database services across all platforms
abstract class DatabaseInterface {
  /// Initialize the database service
  Future<void> initialize();

  /// Get all exercises
  Future<List<Exercise>> getExercises();

  /// Get exercise by ID
  Future<Exercise?> getExercise(String id);

  /// Insert a new exercise
  Future<void> insertExercise(Exercise exercise);

  /// Update an exercise
  Future<void> updateExercise(Exercise exercise);

  /// Delete an exercise
  Future<void> deleteExercise(String id);

  /// Get all workouts with their sets
  Future<List<Workout>> getWorkouts();

  /// Get workout by ID with its sets
  Future<Workout?> getWorkout(String id);

  /// Insert a new workout with its sets
  Future<void> insertWorkout(Workout workout);

  /// Update a workout and its sets
  Future<void> updateWorkout(Workout workout);

  /// Delete a workout and its sets
  Future<void> deleteWorkout(String id);
  
  /// Get all fitness metrics
  Future<List<FitnessMetric>> getMetrics();
  
  /// Get metrics of a specific type
  Future<List<FitnessMetric>> getMetricsByType(MetricType type);
  
  /// Get metrics within a date range
  Future<List<FitnessMetric>> getMetricsByDateRange(DateTime start, DateTime end);
  
  /// Get metrics of a specific type within a date range
  Future<List<FitnessMetric>> getMetricsByTypeAndDateRange(
    MetricType type, 
    DateTime start, 
    DateTime end
  );
  
  /// Get the most recent metric of a specific type
  Future<FitnessMetric?> getLatestMetricByType(MetricType type);
  
  /// Insert a new fitness metric
  Future<void> insertMetric(FitnessMetric metric);
  
  /// Update a fitness metric
  Future<void> updateMetric(FitnessMetric metric);
  
  /// Delete a fitness metric
  Future<void> deleteMetric(String id);
}
