import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';

WorkoutSet _set(
  String exerciseId, {
  int reps = 8,
  double weight = 100,
  bool warmup = false,
  bool completed = false,
  DateTime? at,
}) {
  return WorkoutSet.create(
    exerciseId: exerciseId,
    reps: reps,
    weight: weight,
    isWarmup: warmup,
    isCompleted: completed,
    completedAt: at,
  );
}

void main() {
  group('Routine.fromWorkout', () {
    test('counts working sets per exercise in logged order', () {
      final workout = Workout.create(name: 'Push Day', sets: [
        _set('bench', warmup: true, reps: 10, weight: 40),
        _set('bench', reps: 5),
        _set('ohp', reps: 8),
        _set('bench', reps: 5),
        _set('dips', warmup: true),
        _set('bench', reps: 5),
        _set('ohp', reps: 8),
        _set('dips', reps: 12),
      ]);

      final routine = Routine.fromWorkout(workout, name: 'Push');

      expect(routine.name, 'Push');
      expect(routine.lastUsedAt, isNull);
      expect(routine.exercises, const [
        RoutineExercise(exerciseId: 'bench', sets: 3, reps: 5),
        RoutineExercise(exerciseId: 'ohp', sets: 2, reps: 8),
        RoutineExercise(exerciseId: 'dips', sets: 1, reps: 12),
      ]);
    });

    test('exercise with only warm-up sets is dropped', () {
      final workout = Workout.create(name: 'W', sets: [
        _set('a', warmup: true),
        _set('b'),
      ]);
      final routine = Routine.fromWorkout(workout, name: 'W');
      expect(routine.exercises.map((e) => e.exerciseId), ['b']);
    });
  });

  test('JSON round-trip', () {
    final routine = Routine(
      id: 'r1',
      name: 'Pull Day',
      exercises: const [
        RoutineExercise(exerciseId: 'row', sets: 4, reps: 8),
        RoutineExercise(exerciseId: 'curl', sets: 3),
      ],
      createdAt: DateTime(2026, 1, 2, 3, 4),
      lastUsedAt: DateTime(2026, 2, 3),
    );

    final restored = Routine.fromJson(routine.toJson());

    expect(restored.id, 'r1');
    expect(restored.name, 'Pull Day');
    expect(restored.exercises, routine.exercises);
    expect(restored.createdAt, routine.createdAt);
    expect(restored.lastUsedAt, routine.lastUsedAt);
    expect(restored.exercises[1].reps, isNull);
  });

  test('toWorkout builds uncompleted sets per exercise, dated today', () {
    final routine = Routine(
      id: 'r',
      name: 'Legs',
      exercises: const [
        RoutineExercise(exerciseId: 'squat', sets: 3),
        RoutineExercise(exerciseId: 'new', sets: 2, reps: 12),
      ],
      createdAt: DateTime(2026),
    );
    final history = [
      Workout.create(
        name: 'old',
        scheduledDate: DateTime(2026, 11, 1),
        sets: [
          _set('squat',
              reps: 5,
              weight: 100,
              completed: true,
              at: DateTime(2026, 11, 1, 10)),
        ],
      ),
    ];

    final workout = routine.toWorkout(history,
        useMetric: true, now: DateTime(2026, 11, 5, 18, 30));

    expect(workout.name, 'Legs');
    expect(workout.scheduledDate, DateTime(2026, 11, 5));
    expect(workout.isCompleted, isFalse);
    expect(workout.sets.map((s) => s.exerciseId),
        ['squat', 'squat', 'squat', 'new', 'new']);
    expect(workout.sets.every((s) => !s.isCompleted), isTrue);
    // No history: 0 x routine reps.
    expect(workout.sets.last.weight, 0);
    expect(workout.sets.last.reps, 12);
    // History: weight comes from the coach / last session.
    expect(workout.sets.first.weight, greaterThan(0));
  });
}
