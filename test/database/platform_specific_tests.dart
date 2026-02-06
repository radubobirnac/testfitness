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

  group('Platform-Specific Tests', () {
    test('Database persistence across restarts', () async {
      if (isWeb) {
        // Web-specific test for localStorage persistence
        final exercise = createTestExercise(name: 'Web Persistence Test');
        await db.insertExercise(exercise);

        // "Restart" by creating a new database connection
        final newDb = await getTestDatabase();
        final retrieved = await newDb.getExercise(exercise.id);

        expect(retrieved?.name, equals('Web Persistence Test'));
      } else {
        // Mobile-specific test for SQLite persistence
        final exercise = createTestExercise(name: 'Mobile Persistence Test');
        await db.insertExercise(exercise);

        // "Restart" by creating a new database connection
        final newDb = await getTestDatabase();
        final retrieved = await newDb.getExercise(exercise.id);

        expect(retrieved?.name, equals('Mobile Persistence Test'));
      }
    });

    test('Special character handling', () async {
      // Test with special characters that might cause issues in JSON/SQL
      final exercise = createTestExercise(
        name: "Test with 'quotes' and \"double quotes\" and emoji 🏋️‍♂️",
      );
      await db.insertExercise(exercise);

      final retrieved = await db.getExercise(exercise.id);
      expect(retrieved?.name,
          equals("Test with 'quotes' and \"double quotes\" and emoji 🏋️‍♂️"));
    });

    test('Platform-specific storage mechanism reports correctly', () async {
      if (isWeb) {
        // For web, we should be using localStorage mechanism
        print('Running on Web platform with localStorage persistence');
      } else {
        // For mobile, we should be using SQLite
        print('Running on Mobile platform with SQLite persistence');
      }

      // This test is mainly for reporting purposes
      // but we'll also verify basic functionality
      final exercise = createTestExercise();
      await db.insertExercise(exercise);
      final retrieved = await db.getExercise(exercise.id);
      expect(retrieved, isNotNull);
    });
  });
}
