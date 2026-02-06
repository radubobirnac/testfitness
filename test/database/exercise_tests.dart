import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/services/database_interface.dart';
import '../helpers/test_utilities.dart';

void main() {
  // Initialize the database for testing (especially important for desktop/mobile tests)
  setUpAll(() {
    initTestDatabase();
  });

  late DatabaseInterface db;

  setUp(() async {
    db = await getTestDatabase();
    await clearTestData(db);
  });

  group('Exercise CRUD Operations', () {
    test('Insert and retrieve exercise', () async {
      // Create test exercise
      final exercise = createTestExercise(name: 'Bench Press Test');

      // Insert exercise
      await db.insertExercise(exercise);

      // Retrieve exercise
      final retrieved = await db.getExercise(exercise.id);

      // Verify data
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Bench Press Test'));
      expect(retrieved.description, equals('Test Description'));
      expect(retrieved.muscleGroup, equals('Test Group'));
      expect(retrieved.category, equals('Test Category'));
      expect(retrieved.isCustom, isTrue);
    });

    test('Update exercise', () async {
      // Create and insert test exercise
      final exercise = createTestExercise();
      await db.insertExercise(exercise);

      // Update exercise using copyWith since properties are final
      final updatedExercise = exercise.copyWith(
        name: 'Updated Exercise',
        description: 'Updated Description',
      );
      await db.updateExercise(updatedExercise);

      // Retrieve updated exercise
      final retrieved = await db.getExercise(exercise.id);

      // Verify data
      expect(retrieved!.name, equals('Updated Exercise'));
      expect(retrieved.description, equals('Updated Description'));
    });

    test('Delete exercise', () async {
      // Create and insert test exercise
      final exercise = createTestExercise();
      await db.insertExercise(exercise);

      // Delete exercise
      await db.deleteExercise(exercise.id);

      // Try to retrieve deleted exercise
      final retrieved = await db.getExercise(exercise.id);

      // Verify exercise is deleted
      expect(retrieved, isNull);
    });

    test('Get all exercises', () async {
      // Create and insert multiple exercises
      final exercise1 = createTestExercise(name: 'Exercise 1');
      final exercise2 = createTestExercise(name: 'Exercise 2');
      final exercise3 = createTestExercise(name: 'Exercise 3');

      await db.insertExercise(exercise1);
      await db.insertExercise(exercise2);
      await db.insertExercise(exercise3);

      // Get all exercises
      final exercises = await db.getExercises();

      // Find our test exercises in the results
      final testExercises = exercises.where((e) => e.isCustom).toList();

      // Verify we can find all 3 test exercises
      expect(testExercises.length, greaterThanOrEqualTo(3));
      expect(testExercises.any((e) => e.name == 'Exercise 1'), isTrue);
      expect(testExercises.any((e) => e.name == 'Exercise 2'), isTrue);
      expect(testExercises.any((e) => e.name == 'Exercise 3'), isTrue);
    });
  });
}
