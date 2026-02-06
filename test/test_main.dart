import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/services/database_interface.dart';
import 'helpers/test_utilities.dart';

// Main entry point for all tests
void main() {
  // Group tests that require database setup
  group('Database Tests', () {
    late DatabaseInterface db;

    setUpAll(() {
      // Initialize the database factory once before all tests
      initTestDatabase();
    });

    setUp(() async {
      // Get a fresh database instance for each test
      db = await getTestDatabase();
      await clearTestData(db);
    });

    test('Database initialization', () {
      // Simple test to verify database setup works
      expect(db, isNotNull);
    });
  });
}
