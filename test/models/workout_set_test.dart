import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout_set.dart';

void main() {
  group('WorkoutSet Model Tests', () {
    test('WorkoutSet.fromMap correctly deserializes data', () {
      final now = DateTime.now();
      final map = {
        'id': 'set1',
        'exerciseId': 'exercise1',
        'reps': 10,
        'weight': 45.5,
        'isCompleted': 1,
        'completedAt': now.millisecondsSinceEpoch,
        'restTimeSeconds': 60,
        'notes': 'Test notes',
      };

      final workoutSet = WorkoutSet.fromMap(map);

      expect(workoutSet.id, 'set1');
      expect(workoutSet.exerciseId, 'exercise1');
      expect(workoutSet.reps, 10);
      expect(workoutSet.weight, 45.5);
      expect(workoutSet.isCompleted, true);
      expect(workoutSet.completedAt?.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
      expect(workoutSet.restTimeSeconds, 60);
      expect(workoutSet.notes, 'Test notes');
    });

    test('WorkoutSet.toMap correctly serializes data', () {
      final now = DateTime.now();
      final workoutSet = WorkoutSet(
        id: 'set1',
        exerciseId: 'exercise1',
        reps: 10,
        weight: 45.5,
        isCompleted: true,
        completedAt: now,
        restTimeSeconds: 60,
        notes: 'Test notes',
      );

      final map = workoutSet.toMap();

      expect(map['id'], 'set1');
      expect(map['exerciseId'], 'exercise1');
      expect(map['reps'], 10);
      expect(map['weight'], 45.5);
      expect(map['isCompleted'], 1); // Should be stored as 1 for SQLite
      expect(map['completedAt'], now.millisecondsSinceEpoch);
      expect(map['restTimeSeconds'], 60);
      expect(map['notes'], 'Test notes');
    });

    test('WorkoutSet.create generates a unique ID', () {
      final set1 = WorkoutSet.create(
        exerciseId: 'exercise1',
        reps: 10,
        weight: 45.5,
      );
      final set2 = WorkoutSet.create(
        exerciseId: 'exercise1',
        reps: 12,
        weight: 50.0,
      );

      // IDs should be unique
      expect(set1.id, isNot(set2.id));

      // Verify other properties
      expect(set1.exerciseId, 'exercise1');
      expect(set1.reps, 10);
      expect(set1.weight, 45.5);
      expect(set1.isCompleted, false); // Default for created sets
    });

    test('WorkoutSet.copyWith creates a new instance with updated values', () {
      final original = WorkoutSet(
        id: 'set1',
        exerciseId: 'exercise1',
        reps: 10,
        weight: 45.5,
        isCompleted: false,
      );

      final updated = original.copyWith(
        reps: 12,
        weight: 50.0,
        isCompleted: true,
      );

      // ID should remain the same
      expect(updated.id, original.id);

      // Updated properties should change
      expect(updated.reps, 12);
      expect(updated.weight, 50.0);
      expect(updated.isCompleted, true);

      // Non-updated properties should remain the same
      expect(updated.exerciseId, original.exerciseId);
    });

    test('WorkoutSet.complete marks the set as completed with current time',
        () {
      final set = WorkoutSet(
        id: 'set1',
        exerciseId: 'exercise1',
        reps: 10,
        weight: 45.5,
        isCompleted: false,
      );

      final beforeCompletion = DateTime.now();
      final completed = set.complete();
      final afterCompletion = DateTime.now();

      expect(completed.isCompleted, true);
      expect(completed.completedAt, isNotNull);

      // Verify completion time is reasonable (between before and after)
      expect(completed.completedAt!.millisecondsSinceEpoch,
          greaterThanOrEqualTo(beforeCompletion.millisecondsSinceEpoch));
      expect(completed.completedAt!.millisecondsSinceEpoch,
          lessThanOrEqualTo(afterCompletion.millisecondsSinceEpoch));
    });

    test('WorkoutSet equality based on all properties', () {
      final now = DateTime.now();
      final set1 = WorkoutSet(
        id: 'set1',
        exerciseId: 'exercise1',
        reps: 10,
        weight: 45.5,
        isCompleted: true,
        completedAt: now,
        restTimeSeconds: 60,
        notes: 'Test notes',
      );

      final set2 = WorkoutSet(
        id: 'set1',
        exerciseId: 'exercise1',
        reps: 10,
        weight: 45.5,
        isCompleted: true,
        completedAt: now,
        restTimeSeconds: 60,
        notes: 'Test notes',
      );

      final set3 = WorkoutSet(
        id: 'set1',
        exerciseId: 'exercise1',
        reps: 12, // Different reps
        weight: 45.5,
        isCompleted: true,
        completedAt: now,
        restTimeSeconds: 60,
        notes: 'Test notes',
      );

      // Same properties should be equal (testing Equatable)
      expect(set1, set2);

      // Different properties should not be equal
      expect(set1, isNot(set3));
    });

    test('Handle missing or invalid fields when deserializing', () {
      // Map with minimal data
      final minimalMap = {
        'id': 'set1',
      };

      final workoutSet = WorkoutSet.fromMap(minimalMap);

      // Verify defaults for missing fields
      expect(workoutSet.id, 'set1');
      expect(workoutSet.exerciseId, '');
      expect(workoutSet.reps, 8); // Default from fromMap
      expect(workoutSet.weight, 0.0); // Default from fromMap
      expect(workoutSet.isCompleted, false);
      expect(workoutSet.completedAt, null);
      expect(workoutSet.restTimeSeconds, null);
      expect(workoutSet.notes, null);
    });

    test('Handle non-numeric weight correctly', () {
      final map = {
        'id': 'set1',
        'exerciseId': 'exercise1',
        'reps': 10,
        'weight': 'not a number', // Invalid weight
        'isCompleted': 0,
      };

      final workoutSet = WorkoutSet.fromMap(map);

      // Weight should default to 0.0
      expect(workoutSet.weight, 0.0);
    });
  });
}
