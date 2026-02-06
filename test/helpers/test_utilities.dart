import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/database_service_factory.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';

// Platform detection helper
final bool isWeb = identical(0, 0.0);

// Initialize sqflite for testing
void initTestDatabase() {
  if (!isWeb) {
    // Initialize FFI for mobile/desktop tests
    sqfliteFfiInit();
    // Set the database factory to use for testing
    databaseFactory = databaseFactoryFfi;
  }
}

// Test database setup
Future<DatabaseInterface> getTestDatabase() async {
  // Make sure database is initialized for testing
  initTestDatabase();

  final db = DatabaseServiceFactory.getDatabaseService();
  await db.initialize();
  return db;
}

// Test data cleanup
Future<void> clearTestData(DatabaseInterface db) async {
  // Get all workouts and delete them
  final workouts = await db.getWorkouts();
  for (final workout in workouts) {
    await db.deleteWorkout(workout.id);
  }

  // Get all custom exercises and delete them
  final exercises = await db.getExercises();
  for (final exercise in exercises) {
    if (exercise.isCustom) {
      await db.deleteExercise(exercise.id);
    }
  }
}

// Test data generators
Exercise createTestExercise({String? name}) {
  return Exercise.create(
    name: name ?? 'Test Exercise',
    description: 'Test Description',
    muscleGroup: 'Test Group',
    category: 'Test Category',
    isCustom: true,
  );
}

// Counter for generating truly unique IDs in tests
int _testCounter = 0;

Workout createTestWorkout({String? name, List<WorkoutSet>? sets}) {
  _testCounter++;
  return Workout(
    id: 'test-${DateTime.now().millisecondsSinceEpoch}-$_testCounter',
    name: name ?? 'Test Workout',
    description: 'Test Description',
    scheduledDate: DateTime.now(),
    isCompleted: false,
    sets: sets ?? [],
  );
}

WorkoutSet createTestSet({required String exerciseId}) {
  _testCounter++;
  return WorkoutSet(
    id: 'set-${DateTime.now().millisecondsSinceEpoch}-$_testCounter',
    exerciseId: exerciseId,
    reps: 10,
    weight: 50,
    isCompleted: false,
  );
}
