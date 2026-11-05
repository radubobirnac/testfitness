import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/database_service_factory.dart';
import 'package:testfitness/utils/performance_monitor.dart';

/// Repository for workout-related operations
class WorkoutRepository {
  final DatabaseInterface _databaseService =
      DatabaseServiceFactory.getDatabaseService();

  // Exercise operations

  /// Get all exercises
  Future<List<Exercise>> getExercises() async {
    return await _databaseService.getExercises();
  }

  /// Get exercise by ID
  Future<Exercise?> getExercise(String id) async {
    return await _databaseService.getExercise(id);
  }

  /// Add a new exercise
  Future<void> addExercise(Exercise exercise) async {
    await _databaseService.insertExercise(exercise);
  }

  /// Update an existing exercise
  Future<void> updateExercise(Exercise exercise) async {
    await _databaseService.updateExercise(exercise);
  }

  /// Delete an exercise
  Future<void> deleteExercise(String id) async {
    await _databaseService.deleteExercise(id);
  }

  // Workout operations

  /// Get all workouts
  Future<List<Workout>> getWorkouts() async {
    return await PerformanceMonitor.monitorFuture(
      'db_get_workouts',
      _databaseService.getWorkouts(),
    );
  }

  /// Get workout by ID
  Future<Workout?> getWorkout(String id) async {
    return await PerformanceMonitor.monitorFuture(
      'db_get_workout',
      _databaseService.getWorkout(id),
    );
  }

  /// Add a new workout
  Future<void> addWorkout(Workout workout) async {
    await PerformanceMonitor.monitorFuture(
      'db_insert_workout',
      _databaseService.insertWorkout(workout),
    );
  }

  /// Update an existing workout
  Future<void> updateWorkout(Workout workout) async {
    await PerformanceMonitor.monitorFuture(
      'db_update_workout',
      _databaseService.updateWorkout(workout),
    );
  }

  /// Delete a workout
  Future<void> deleteWorkout(String id) async {
    await _databaseService.deleteWorkout(id);
  }

  /// Get workouts scheduled for a specific date
  Future<List<Workout>> getWorkoutsForDate(DateTime date) async {
    final workouts = await getWorkouts();

    // Filter workouts by date (ignoring time)
    return workouts.where((workout) {
      if (workout.scheduledDate == null) return false;

      final workoutDate = DateTime(
        workout.scheduledDate!.year,
        workout.scheduledDate!.month,
        workout.scheduledDate!.day,
      );

      final targetDate = DateTime(date.year, date.month, date.day);

      return workoutDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  /// Get completed workouts
  Future<List<Workout>> getCompletedWorkouts() async {
    final workouts = await getWorkouts();
    return workouts.where((workout) => workout.isCompleted).toList();
  }

  /// Get incomplete workouts
  Future<List<Workout>> getIncompleteWorkouts() async {
    final workouts = await getWorkouts();
    return workouts.where((workout) => !workout.isCompleted).toList();
  }

  /// Complete a workout
  Future<void> completeWorkout(
    String id, {
    int? durationMinutes,
    DateTime? completedAt,
    bool markSetsDone = false,
  }) async {
    final workout = await getWorkout(id);
    if (workout == null) return;

    final completedWorkout = workout.complete(
      durationMinutes: durationMinutes,
      at: completedAt,
      markSetsDone: markSetsDone,
    );
    await updateWorkout(completedWorkout);
  }

  /// Mark several planned workouts as done on their own scheduled days
  /// (sets included). Returns how many were updated.
  Future<int> completeWorkoutsOnPlannedDay(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      final workout = await getWorkout(id);
      if (workout == null || workout.isCompleted) continue;
      await updateWorkout(workout.complete(
        at: workout.plannedCompletionTime,
        markSetsDone: true,
      ));
      count++;
    }
    return count;
  }

  /// Add a set to a workout
  Future<void> addSetToWorkout(String workoutId, WorkoutSet set) async {
    final workout = await getWorkout(workoutId);
    if (workout == null) return;

    final updatedWorkout = workout.addSet(set);
    await updateWorkout(updatedWorkout);
  }

  /// Update a set in a workout
  Future<void> updateSetInWorkout(
    String workoutId,
    WorkoutSet updatedSet,
  ) async {
    final workout = await getWorkout(workoutId);
    if (workout == null) return;

    final updatedWorkout = workout.updateSet(updatedSet);
    await updateWorkout(updatedWorkout);
  }

  /// Remove a set from a workout
  Future<void> removeSetFromWorkout(String workoutId, String setId) async {
    final workout = await getWorkout(workoutId);
    if (workout == null) return;

    final updatedWorkout = workout.removeSet(setId);
    await updateWorkout(updatedWorkout);
  }

  /// Complete a set in a workout
  Future<void> completeSet(String workoutId, String setId) async {
    final workout = await getWorkout(workoutId);
    if (workout == null) return;

    final setToUpdate = workout.sets.firstWhere(
      (s) => s.id == setId,
      orElse: () => throw Exception('Set not found'),
    );

    final completedSet = setToUpdate.complete();
    final updatedWorkout = workout.updateSet(completedSet);

    await updateWorkout(updatedWorkout);
  }

  /// Duplicate a workout
  ///
  /// Creates a copy of the workout with:
  /// - A new ID
  /// - All the same exercises and sets
  /// - Reset completion status (sets as incomplete)
  /// - Scheduled for tomorrow by default
  /// - Name prefixed with "Copy of " if copyNamePrefix is true
  ///
  /// Returns the ID of the newly created workout
  Future<String> duplicateWorkout(String id,
      {bool copyNamePrefix = true}) async {
    // Get the original workout
    final originalWorkout = await getWorkout(id);
    if (originalWorkout == null) {
      throw Exception('Workout not found');
    }

    // Create a new ID for the duplicate
    final newId = 'workout_${DateTime.now().millisecondsSinceEpoch}';

    // Create the duplicate workout with copied data but reset completion status
    final duplicateWorkout = Workout(
      id: newId,
      name: copyNamePrefix
          ? 'Copy of ${originalWorkout.name}'
          : originalWorkout.name,
      description: originalWorkout.description,
      // Schedule for tomorrow by default
      scheduledDate: DateTime.now().add(const Duration(days: 1)),
      isCompleted: false,
      completedDate: null,
      // Copy all sets but reset their completion status and create new IDs
      sets: originalWorkout.sets
          // Keep warm-up and superset structure; a repeat is a new session,
          // so completion and effort ratings are cleared.
          .map((set) => WorkoutSet(
                id: 'set_${DateTime.now().millisecondsSinceEpoch}_${originalWorkout.sets.indexOf(set)}',
                exerciseId: set.exerciseId,
                reps: set.reps,
                weight: set.weight,
                isCompleted: false,
                completedAt: null,
                restTimeSeconds: set.restTimeSeconds,
                notes: set.notes,
                isWarmup: set.isWarmup,
                supersetGroup: set.supersetGroup,
              ))
          .toList(),
      durationMinutes: null,
      notes: originalWorkout.notes,
    );

    // Save the duplicate workout
    await addWorkout(duplicateWorkout);

    // Return the ID of the new workout
    return newId;
  }
}
