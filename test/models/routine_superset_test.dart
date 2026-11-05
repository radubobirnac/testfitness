import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';

WorkoutSet _set(String exerciseId, {String? group, bool warmup = false}) =>
    WorkoutSet.create(
      exerciseId: exerciseId,
      reps: 8,
      weight: 50,
      isWarmup: warmup,
      supersetGroup: group,
    );

void main() {
  group('Routine supersets', () {
    final workout = Workout.create(name: 'Arms', sets: [
      _set('bench'),
      _set('bench'),
      _set('curl', group: 'g1', warmup: true),
      _set('curl', group: 'g1'),
      _set('pushdown', group: 'g1'),
      _set('curl', group: 'g1'),
      _set('pushdown', group: 'g1'),
      _set('raise'),
    ]);

    test('fromWorkout keeps the superset group', () {
      final routine = Routine.fromWorkout(workout, name: 'Arms');
      expect(routine.exercises.map((e) => e.supersetGroup).toList(),
          [null, 'g1', 'g1', null]);
      expect(routine.exercises[1].sets, 2);
    });

    test('JSON round-trip keeps it; missing reads as null', () {
      final routine = Routine.fromWorkout(workout, name: 'Arms');
      final restored = Routine.fromJson(routine.toJson());
      expect(restored.exercises, routine.exercises);
      expect(routine.exercises.first.toJson().containsKey('supersetGroup'),
          isFalse);
      expect(
          RoutineExercise.fromJson({'exerciseId': 'x', 'sets': 3})
              .supersetGroup,
          isNull);
    });

    test('toWorkout re-applies supersets with fresh group ids', () {
      final routine = Routine.fromWorkout(workout, name: 'Arms');
      final first = routine.toWorkout(const [], useMetric: true);
      final second = routine.toWorkout(const [], useMetric: true);

      String? groupOf(Workout w, String id) =>
          w.sets.firstWhere((s) => s.exerciseId == id).supersetGroup;

      for (final w in [first, second]) {
        expect(groupOf(w, 'bench'), isNull);
        expect(groupOf(w, 'raise'), isNull);
        final g = groupOf(w, 'curl');
        expect(g, isNotNull);
        expect(g, isNot('g1'));
        expect(groupOf(w, 'pushdown'), g);
        // Every set of the grouped exercises carries the id.
        expect(
            w.sets
                .where(
                    (s) => s.exerciseId == 'curl' || s.exerciseId == 'pushdown')
                .every((s) => s.supersetGroup == g),
            isTrue);
      }
      expect(groupOf(first, 'curl'), isNot(groupOf(second, 'curl')));
    });

    test('a stored group on a lone exercise is ignored', () {
      final routine = Routine(
        id: 'r',
        name: 'R',
        exercises: const [
          RoutineExercise(exerciseId: 'a', sets: 1, supersetGroup: 'g'),
          RoutineExercise(exerciseId: 'b', sets: 1),
        ],
        createdAt: DateTime(2026),
      );
      final w = routine.toWorkout(const [], useMetric: true);
      expect(w.sets.every((s) => s.supersetGroup == null), isTrue);
    });
  });
}
