import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';

void main() {
  group('Workout Model Tests', () {
    // Helper function to create test workout sets
    List<WorkoutSet> createTestSets({int count = 2, String? exerciseId}) {
      final sets = <WorkoutSet>[];
      final baseExerciseId = exerciseId ?? 'exercise1';

      for (var i = 0; i < count; i++) {
        sets.add(WorkoutSet(
          id: 'set${i + 1}',
          exerciseId: '$baseExerciseId${i > 0 ? "_$i" : ""}',
          reps: 10 + i,
          weight: 50.0 + (i * 5),
          isCompleted: false,
        ));
      }

      return sets;
    }

    test('Workout.fromMap correctly deserializes data with sets', () {
      final now = DateTime.now();
      final scheduledTime = now.subtract(Duration(days: 1));
      final completedTime = now;

      final map = {
        'id': 'workout1',
        'name': 'Test Workout',
        'description': 'Test Description',
        'scheduledDate': scheduledTime.millisecondsSinceEpoch,
        'completedDate': completedTime.millisecondsSinceEpoch,
        'isCompleted': 1,
        'durationMinutes': 45,
        'notes': 'Test notes',
      };

      final sets = createTestSets();
      final workout = Workout.fromMap(map, sets);

      expect(workout.id, 'workout1');
      expect(workout.name, 'Test Workout');
      expect(workout.description, 'Test Description');
      expect(workout.scheduledDate?.millisecondsSinceEpoch,
          scheduledTime.millisecondsSinceEpoch);
      expect(workout.completedDate?.millisecondsSinceEpoch,
          completedTime.millisecondsSinceEpoch);
      expect(workout.isCompleted, true);
      expect(workout.durationMinutes, 45);
      expect(workout.notes, 'Test notes');
      expect(workout.sets.length, 2);
    });

    test('Workout.toMap correctly serializes data', () {
      final now = DateTime.now();
      final scheduledTime = now.subtract(Duration(days: 1));
      final completedTime = now;

      final workout = Workout(
        id: 'workout1',
        name: 'Test Workout',
        description: 'Test Description',
        scheduledDate: scheduledTime,
        completedDate: completedTime,
        isCompleted: true,
        sets: createTestSets(),
        durationMinutes: 45,
        notes: 'Test notes',
      );

      final map = workout.toMap();

      expect(map['id'], 'workout1');
      expect(map['name'], 'Test Workout');
      expect(map['description'], 'Test Description');
      expect(map['scheduledDate'], scheduledTime.millisecondsSinceEpoch);
      expect(map['completedDate'], completedTime.millisecondsSinceEpoch);
      expect(map['isCompleted'], 1); // Should be stored as 1 for SQLite
      expect(map['durationMinutes'], 45);
      expect(map['notes'], 'Test notes');
      // Sets are not included in toMap, they're handled separately in the database
    });

    test('Workout.create generates a unique ID', () {
      final workout1 = Workout.create(name: 'Workout 1');
      final workout2 = Workout.create(name: 'Workout 2');

      // IDs should be unique
      expect(workout1.id, isNot(workout2.id));

      // Verify other properties
      expect(workout1.name, 'Workout 1');
      expect(workout1.isCompleted, false); // Default for created workouts
      expect(workout1.sets, isEmpty);
    });

    test('Workout.copyWith creates a new instance with updated values', () {
      final original = Workout(
        id: 'workout1',
        name: 'Original Workout',
        description: 'Original Description',
        scheduledDate: DateTime(2025, 4, 1),
        isCompleted: false,
        sets: createTestSets(),
      );

      final newSets = createTestSets(count: 3);
      final updated = original.copyWith(
        name: 'Updated Workout',
        description: 'Updated Description',
        isCompleted: true,
        sets: newSets,
      );

      // ID should remain the same
      expect(updated.id, original.id);

      // Updated properties should change
      expect(updated.name, 'Updated Workout');
      expect(updated.description, 'Updated Description');
      expect(updated.isCompleted, true);
      expect(updated.sets.length, 3);

      // Non-updated properties should remain the same
      expect(updated.scheduledDate, original.scheduledDate);
    });

    test('Workout.complete marks workout as completed with current time', () {
      final workout = Workout(
        id: 'workout1',
        name: 'Test Workout',
        isCompleted: false,
        sets: createTestSets(),
      );

      final beforeCompletion = DateTime.now();
      final completed = workout.complete(durationMinutes: 45);
      final afterCompletion = DateTime.now();

      expect(completed.isCompleted, true);
      expect(completed.completedDate, isNotNull);
      expect(completed.durationMinutes, 45);

      // Verify completion time is reasonable (between before and after)
      expect(completed.completedDate!.millisecondsSinceEpoch,
          greaterThanOrEqualTo(beforeCompletion.millisecondsSinceEpoch));
      expect(completed.completedDate!.millisecondsSinceEpoch,
          lessThanOrEqualTo(afterCompletion.millisecondsSinceEpoch));
    });

    test('Workout.addSet adds a set to the workout', () {
      final workout = Workout(
        id: 'workout1',
        name: 'Test Workout',
        sets: createTestSets(count: 1),
      );

      final newSet = WorkoutSet(
        id: 'new_set',
        exerciseId: 'exercise2',
        reps: 12,
        weight: 60.0,
        isCompleted: false,
      );

      final updatedWorkout = workout.addSet(newSet);

      expect(updatedWorkout.sets.length, 2);
      expect(updatedWorkout.sets.last.id, 'new_set');
      expect(updatedWorkout.sets.last.exerciseId, 'exercise2');
    });

    test('Workout.removeSet removes a set from the workout', () {
      final sets = createTestSets(count: 3);
      final workout = Workout(
        id: 'workout1',
        name: 'Test Workout',
        sets: sets,
      );

      final setIdToRemove = sets[1].id;
      final updatedWorkout = workout.removeSet(setIdToRemove);

      expect(updatedWorkout.sets.length, 2);
      expect(updatedWorkout.sets.any((s) => s.id == setIdToRemove), false);
    });

    test('Workout.updateSet updates a specific set in the workout', () {
      final sets = createTestSets(count: 2);
      final workout = Workout(
        id: 'workout1',
        name: 'Test Workout',
        sets: sets,
      );

      final updatedSet = sets[0].copyWith(
        reps: 15,
        weight: 75.0,
        isCompleted: true,
      );

      final updatedWorkout = workout.updateSet(updatedSet);

      expect(updatedWorkout.sets.length, 2);
      expect(updatedWorkout.sets[0].reps, 15);
      expect(updatedWorkout.sets[0].weight, 75.0);
      expect(updatedWorkout.sets[0].isCompleted, true);

      // The other set should remain unchanged
      expect(updatedWorkout.sets[1].id, sets[1].id);
      expect(updatedWorkout.sets[1].reps, sets[1].reps);
    });

    test('Workout.getSetsForExercise filters sets by exercise ID', () {
      final workout = Workout(
        id: 'workout1',
        name: 'Test Workout',
        sets: [
          WorkoutSet(
              id: 'set1', exerciseId: 'exercise1', reps: 10, weight: 50.0),
          WorkoutSet(
              id: 'set2', exerciseId: 'exercise1', reps: 10, weight: 50.0),
          WorkoutSet(
              id: 'set3', exerciseId: 'exercise2', reps: 12, weight: 40.0),
        ],
      );

      final exercise1Sets = workout.getSetsForExercise('exercise1');

      expect(exercise1Sets.length, 2);
      expect(exercise1Sets.every((s) => s.exerciseId == 'exercise1'), true);
    });

    test('Workout.exerciseIds returns unique exercise IDs', () {
      final workout = Workout(
        id: 'workout1',
        name: 'Test Workout',
        sets: [
          WorkoutSet(
              id: 'set1', exerciseId: 'exercise1', reps: 10, weight: 50.0),
          WorkoutSet(
              id: 'set2', exerciseId: 'exercise1', reps: 10, weight: 50.0),
          WorkoutSet(
              id: 'set3', exerciseId: 'exercise2', reps: 12, weight: 40.0),
          WorkoutSet(
              id: 'set4', exerciseId: 'exercise3', reps: 15, weight: 30.0),
        ],
      );

      final exerciseIds = workout.exerciseIds;

      expect(exerciseIds.length, 3);
      expect(exerciseIds.contains('exercise1'), true);
      expect(exerciseIds.contains('exercise2'), true);
      expect(exerciseIds.contains('exercise3'), true);
    });

    test('Handle missing or invalid fields when deserializing', () {
      // Map with minimal data
      final minimalMap = {
        'id': 'workout1',
      };

      final workout = Workout.fromMap(minimalMap, null);

      // Verify defaults for missing fields
      expect(workout.id, 'workout1');
      expect(workout.name, 'Unnamed Workout'); // Default from fromMap
      expect(workout.description, null);
      expect(workout.scheduledDate, null);
      expect(workout.completedDate, null);
      expect(workout.isCompleted, false);
      expect(workout.sets, isEmpty);
      expect(workout.durationMinutes, null);
      expect(workout.notes, null);
    });

    test('Handle error recovery in fromMap', () {
      // Invalid date values
      final invalidDatesMap = {
        'id': 'workout1',
        'name': 'Test Workout',
        'scheduledDate': 'not a timestamp', // Invalid date
        'completedDate': 'not a timestamp', // Invalid date
      };

      final workout = Workout.fromMap(invalidDatesMap, null);

      // Verify it recovers gracefully
      expect(workout.id, 'workout1');
      expect(workout.name, 'Test Workout');
      expect(workout.scheduledDate, null); // Should default to null on error
      expect(workout.completedDate, null); // Should default to null on error
    });
  });
}
