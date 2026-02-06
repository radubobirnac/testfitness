import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/exercise.dart';

void main() {
  group('Exercise Model Tests', () {
    test('Exercise.fromMap correctly deserializes data', () {
      final map = {
        'id': 'exercise1',
        'name': 'Bench Press',
        'description': 'Chest exercise',
        'muscleGroup': 'Chest',
        'category': 'Barbell',
        'imageUrl': 'http://example.com/image.jpg',
        'isCustom': 1,
      };

      final exercise = Exercise.fromMap(map);

      expect(exercise.id, 'exercise1');
      expect(exercise.name, 'Bench Press');
      expect(exercise.description, 'Chest exercise');
      expect(exercise.muscleGroup, 'Chest');
      expect(exercise.category, 'Barbell');
      expect(exercise.imageUrl, 'http://example.com/image.jpg');
      expect(exercise.isCustom, true);
    });

    test('Exercise.toMap correctly serializes data', () {
      final exercise = Exercise(
        id: 'exercise1',
        name: 'Bench Press',
        description: 'Chest exercise',
        muscleGroup: 'Chest',
        category: 'Barbell',
        imageUrl: 'http://example.com/image.jpg',
        isCustom: true,
      );

      final map = exercise.toMap();

      expect(map['id'], 'exercise1');
      expect(map['name'], 'Bench Press');
      expect(map['description'], 'Chest exercise');
      expect(map['muscleGroup'], 'Chest');
      expect(map['category'], 'Barbell');
      expect(map['imageUrl'], 'http://example.com/image.jpg');
      expect(map['isCustom'], 1); // Should be stored as 1 for SQLite
    });

    test('Exercise.create generates a unique ID', () {
      final exercise1 = Exercise.create(name: 'Exercise 1');
      final exercise2 = Exercise.create(name: 'Exercise 2');

      // IDs should be unique
      expect(exercise1.id, isNot(exercise2.id));

      // Verify other properties
      expect(exercise1.name, 'Exercise 1');
      expect(exercise1.isCustom, true); // Default for created exercises
    });

    test('Exercise.copyWith creates a new instance with updated values', () {
      final original = Exercise(
        id: 'exercise1',
        name: 'Bench Press',
        description: 'Chest exercise',
        muscleGroup: 'Chest',
        category: 'Barbell',
        isCustom: true,
      );

      final updated = original.copyWith(
        name: 'Incline Bench Press',
        muscleGroup: 'Upper Chest',
      );

      // ID should remain the same
      expect(updated.id, original.id);

      // Updated properties should change
      expect(updated.name, 'Incline Bench Press');
      expect(updated.muscleGroup, 'Upper Chest');

      // Non-updated properties should remain the same
      expect(updated.description, original.description);
      expect(updated.category, original.category);
      expect(updated.isCustom, original.isCustom);
    });

    test('Exercise equality based on all properties', () {
      final exercise1 = Exercise(
        id: 'exercise1',
        name: 'Bench Press',
        description: 'Chest exercise',
        muscleGroup: 'Chest',
        category: 'Barbell',
        isCustom: true,
      );

      final exercise2 = Exercise(
        id: 'exercise1',
        name: 'Bench Press',
        description: 'Chest exercise',
        muscleGroup: 'Chest',
        category: 'Barbell',
        isCustom: true,
      );

      final exercise3 = Exercise(
        id: 'exercise1',
        name: 'Different Exercise', // Changed property
        description: 'Chest exercise',
        muscleGroup: 'Chest',
        category: 'Barbell',
        isCustom: true,
      );

      // Same properties should be equal (testing Equatable)
      expect(exercise1, exercise2);

      // Different properties should not be equal
      expect(exercise1, isNot(exercise3));
    });

    test('Handle null fields correctly', () {
      final exercise = Exercise(
        id: 'exercise1',
        name: 'Bench Press',
        // All other fields null
      );

      final map = exercise.toMap();
      final deserialized = Exercise.fromMap(map);

      expect(deserialized.id, 'exercise1');
      expect(deserialized.name, 'Bench Press');
      expect(deserialized.description, null);
      expect(deserialized.muscleGroup, null);
      expect(deserialized.category, null);
      expect(deserialized.imageUrl, null);
      expect(deserialized.isCustom, false); // Default
    });
  });
}
