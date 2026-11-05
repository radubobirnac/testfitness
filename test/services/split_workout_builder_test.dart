import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/data/default_exercises.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/split_workout_builder.dart';
import 'package:testfitness/utils/muscle_map.dart';

int _counter = 0;

void main() {
  final library = buildDefaultExercises();
  Exercise ex(String name) => library.firstWhere((e) => e.name == name);
  final builder = SplitWorkoutBuilder(useMetric: true);
  final now = DateTime(2026, 11, 5, 18);
  DateTime ago({int days = 0, int hours = 0}) =>
      now.subtract(Duration(days: days, hours: hours));

  WorkoutSet done(String exerciseId, double weight, int reps,
      {bool warmup = false, bool completed = true}) {
    _counter++;
    return WorkoutSet(
      id: 's$_counter',
      exerciseId: exerciseId,
      reps: reps,
      weight: weight,
      isCompleted: completed,
      isWarmup: warmup,
    );
  }

  /// A completed workout on [date] with 3 sets of each (name, weight, reps).
  Workout session(DateTime date, List<(String, double, int)> lifts) {
    _counter++;
    return Workout(
      id: 'w$_counter',
      name: 'w$_counter',
      completedDate: date,
      isCompleted: true,
      sets: [
        for (final (name, w, r) in lifts)
          for (var i = 0; i < 3; i++) done(ex(name).id, w, r),
      ],
    );
  }

  /// Exercise names in workout order (one per exercise).
  List<String> names(Workout w) {
    final byId = {for (final e in library) e.id: e.name};
    final result = <String>[];
    for (final s in w.sets) {
      final n = byId[s.exerciseId] ?? s.exerciseId;
      if (!result.contains(n)) result.add(n);
    }
    return result;
  }

  List<WorkoutSet> setsOf(Workout w, String name) =>
      w.sets.where((s) => s.exerciseId == ex(name).id).toList();

  MuscleProfile profile(String name) => MuscleMap.of(ex(name));

  group('WorkoutSplit', () {
    test('presets in contract order', () {
      expect(WorkoutSplit.presets.map((s) => s.id), [
        'back_biceps',
        'chest_triceps',
        'legs',
        'shoulders_arms',
        'chest_back',
        'legs_core',
      ]);
      expect(WorkoutSplit.presets.first.name, 'Back & Biceps');
      expect(WorkoutSplit.presets[2].main,
          [Muscle.quads, Muscle.hamstrings, Muscle.glutes]);
      expect(WorkoutSplit.presets[2].secondary, [Muscle.calves]);
    });

    test('custom split', () {
      final s = WorkoutSplit.custom(Muscle.shoulders, Muscle.triceps);
      expect(s.id, 'custom_shoulders_triceps');
      expect(s.name, 'Shoulders & Triceps');
      expect(s.main, [Muscle.shoulders]);
      expect(s.secondary, [Muscle.triceps]);
    });
  });

  group('build without history', () {
    test('Back & Biceps: rows/pulls then curls, compound first', () {
      final plan =
          builder.build(WorkoutSplit.presets[0], const [], library, now: now);
      final w = plan.workout;
      expect(w.name, 'Back & Biceps');
      expect(w.scheduledDate, DateTime(2026, 11, 5));
      expect(w.isCompleted, isFalse);
      expect(names(w), [
        'Barbell Row',
        'Lat Pulldown',
        'Pull-up',
        'Barbell Curl',
        'Dumbbell Curl'
      ]);
      expect(w.sets.length, 15);
      expect(w.sets.every((s) => !s.isCompleted && s.weight == 0), isTrue);
      expect(setsOf(w, 'Barbell Row').map((s) => s.reps), [8, 8, 8]);
      expect(setsOf(w, 'Barbell Curl').map((s) => s.reps), [12, 12, 12]);
      expect(plan.summary, startsWith('3 back + 2 biceps exercises'));
      expect(plan.recentlyTrained, isEmpty);
    });

    test('Chest & Triceps', () {
      final w = builder
          .build(WorkoutSplit.presets[1], const [], library, now: now)
          .workout;
      final n = names(w);
      expect(n.length, 5);
      expect(
          n.take(3), ['Bench Press', 'Dumbbell Press', 'Incline Bench Press']);
      for (final name in n.skip(3)) {
        expect(profile(name).primarily(Muscle.triceps), isTrue, reason: name);
      }
    });

    test('Legs covers quads, hamstrings, glutes then calves', () {
      final plan =
          builder.build(WorkoutSplit.presets[2], const [], library, now: now);
      final n = names(plan.workout);
      expect(n, [
        'Squat',
        'Romanian Deadlift',
        'Barbell Hip Thrust',
        'Standing Calf Raise Machine',
        'Barbell Calf Raise',
      ]);
      expect(plan.summary,
          startsWith('1 quads + 1 hamstrings + 1 glutes + 2 calves exercises'));
    });

    test('Chest & Back alternates and uses 5 main exercises', () {
      final n = names(builder
          .build(WorkoutSplit.presets[4], const [], library, now: now)
          .workout);
      expect(n.length, 5);
      expect(n.where((x) => profile(x).primarily(Muscle.chest)).length, 3);
      expect(n.where((x) => profile(x).primarily(Muscle.back)).length, 2);
    });

    test('custom split builds main + secondary', () {
      final n = names(builder
          .build(WorkoutSplit.custom(Muscle.shoulders, Muscle.triceps),
              const [], library,
              now: now)
          .workout);
      expect(n.length, 5);
      for (final x in n.take(3)) {
        expect(profile(x).primarily(Muscle.shoulders), isTrue, reason: x);
      }
      for (final x in n.skip(3)) {
        expect(profile(x).primarily(Muscle.triceps), isTrue, reason: x);
      }
    });

    test('explicit counts', () {
      final n = names(builder
          .build(WorkoutSplit.presets[0], const [], library,
              now: now, mainCount: 2, secondaryCount: 1)
          .workout);
      expect(n, ['Barbell Row', 'Lat Pulldown', 'Barbell Curl']);
    });

    test('deterministic', () {
      for (final split in WorkoutSplit.presets) {
        final a =
            names(builder.build(split, const [], library, now: now).workout);
        final b =
            names(builder.build(split, const [], library, now: now).workout);
        expect(a, b);
        expect(a.toSet().length, a.length, reason: 'duplicates in ${split.id}');
      }
    });
  });

  group('build with history', () {
    test('prefers history, most recent first; compound still first', () {
      final history = [
        session(ago(days: 3), [('Barbell Row', 60, 8)]),
        session(ago(days: 1), [('Pullover Machine', 40, 12)]),
        session(ago(days: 2), [('Hammer Curl', 14, 10)]),
      ];
      final plan =
          builder.build(WorkoutSplit.presets[0], history, library, now: now);
      final n = names(plan.workout);
      expect(n, [
        'Barbell Row',
        'Lat Pulldown',
        'Pullover Machine',
        'Hammer Curl',
        'Barbell Curl',
      ]);
      // Coach target: hit 8 on every set at 60 → add 2.5.
      expect(setsOf(plan.workout, 'Barbell Row').map((s) => (s.weight, s.reps)),
          [(62.5, 8), (62.5, 8), (62.5, 8)]);
      expect(
          setsOf(plan.workout, 'Hammer Curl').first.weight,
          ProgressionCoach(useMetric: true)
              .target(ex('Hammer Curl').id, history)!
              .weight);
      expect(setsOf(plan.workout, 'Lat Pulldown').first.weight, 0);
      expect(plan.summary, contains('targets from your history for 3 of 5'));
      expect(plan.recentlyTrained, [Muscle.back]);
    });

    test('rows trained recently never fill the biceps slot', () {
      final history = [
        session(ago(days: 1), [
          ('Barbell Row', 60, 8),
          ('Seated Row', 50, 10),
          ('Pull-up', 0, 8),
          ('Dumbbell Row', 30, 10),
        ]),
      ];
      final n = names(builder
          .build(WorkoutSplit.presets[0], history, library, now: now)
          .workout);
      expect(n.length, 5);
      for (final x in n.skip(3)) {
        expect(profile(x).primarily(Muscle.biceps), isTrue, reason: x);
        expect(x.toLowerCase(), contains('curl'));
      }
      expect(n.toSet().length, 5);
    });

    test('close-grip bench in the chest slot is not repeated for triceps', () {
      final history = [
        session(ago(days: 4), [('Close-Grip Bench Press', 70, 6)]),
      ];
      final n = names(builder
          .build(WorkoutSplit.presets[1], history, library, now: now)
          .workout);
      expect(n.first, 'Close-Grip Bench Press');
      expect(n.where((x) => x == 'Close-Grip Bench Press').length, 1);
      expect(n.length, 5);
    });

    test('warm-ups and unfinished sets do not count as history', () {
      final w = Workout(
        id: 'warm',
        name: 'warm',
        completedDate: ago(days: 1),
        isCompleted: true,
        sets: [
          done(ex('Seated Row').id, 20, 10, warmup: true),
          done(ex('Cable Row').id, 20, 10, completed: false),
        ],
      );
      final plan =
          builder.build(WorkoutSplit.presets[0], [w], library, now: now);
      expect(names(plan.workout).take(3),
          ['Barbell Row', 'Lat Pulldown', 'Pull-up']);
      expect(plan.recentlyTrained, isEmpty);
    });
  });

  group('preferences', () {
    test('focus reps apply to exercises without a coach target', () {
      final history = [
        session(ago(days: 3), [('Barbell Row', 60, 8)])
      ];
      final plan = builder.build(WorkoutSplit.presets[0], history, library,
          now: now, preferences: const WorkoutPreferences(focus: 'strength'));
      expect(setsOf(plan.workout, 'Barbell Row').first.reps, 8);
      expect(setsOf(plan.workout, 'Lat Pulldown').first.reps, 5);
      expect(setsOf(plan.workout, 'Barbell Curl').first.reps, 5);
    });

    test('exercise count follows session length (~60/40)', () {
      int count(int minutes, WorkoutSplit split) => names(builder
              .build(split, const [], library,
                  now: now,
                  preferences: WorkoutPreferences(durationMinutes: minutes))
              .workout)
          .length;
      final bb = WorkoutSplit.presets[0];
      expect(count(27, bb), 3);
      expect(count(45, bb), 5);
      expect(count(72, bb), 8);

      final short = names(builder
          .build(bb, const [], library,
              now: now,
              preferences: const WorkoutPreferences(durationMinutes: 27))
          .workout);
      expect(short, ['Barbell Row', 'Lat Pulldown', 'Barbell Curl']);

      // Explicit counts win over preferences.
      final explicit = builder.build(bb, const [], library,
          now: now,
          mainCount: 1,
          secondaryCount: 1,
          preferences: const WorkoutPreferences(durationMinutes: 72));
      expect(names(explicit.workout).length, 2);
    });

    test('excludeCore drops core exercises unless the split targets core', () {
      final hybrid = Exercise(
          id: 'hybrid', name: 'Mystery Move', muscleGroup: 'Back, Core');
      final exercises = [...library, hybrid];
      final history = [
        Workout(
          id: 'h',
          name: 'h',
          completedDate: ago(days: 2),
          isCompleted: true,
          sets: [for (var i = 0; i < 3; i++) done('hybrid', 20, 10)],
        ),
      ];
      final split = WorkoutSplit.presets[0];
      final normal = builder.build(split, history, exercises, now: now);
      expect(normal.workout.sets.first.exerciseId, 'hybrid');

      final noCore = builder.build(split, history, exercises,
          now: now, preferences: const WorkoutPreferences(excludeCore: true));
      expect(noCore.workout.sets.any((s) => s.exerciseId == 'hybrid'), isFalse);

      final legsCore = builder.build(WorkoutSplit.presets[5], const [], library,
          now: now, preferences: const WorkoutPreferences(excludeCore: true));
      final n = names(legsCore.workout);
      expect(n.where((x) => profile(x).primarily(Muscle.core)), isNotEmpty);
    });
  });

  group('recentlyTrained', () {
    test('primary muscles of completed working sets inside the window', () {
      final history = [
        session(ago(hours: 10), [('Barbell Row', 60, 8)]),
        session(ago(hours: 50), [('Bench Press', 80, 5)]),
        session(ago(hours: -5), [('Squat', 100, 5)]), // future: ignored
      ];
      expect(
          builder.recentlyTrained(history, library, now: now), {Muscle.back});
      expect(
          builder.recentlyTrained(history, library,
              now: now, within: const Duration(hours: 72)),
          {Muscle.back, Muscle.chest});
    });
  });

  group('suggest', () {
    test('no history → first preset', () {
      expect(builder.suggest(const [], library, now: now).id, 'back_biceps');
    });

    test('picks the split whose muscles are most recovered', () {
      final history = [
        session(
            ago(days: 1), [('Barbell Row', 60, 8), ('Barbell Curl', 30, 10)]),
        session(ago(days: 2),
            [('Bench Press', 80, 5), ('Triceps Pushdown', 30, 12)]),
        session(ago(days: 3), [('Overhead Press', 40, 8)]),
        session(ago(days: 5), [('Plank', 0, 1)]),
        session(ago(days: 6), [
          ('Squat', 100, 5),
          ('Romanian Deadlift', 80, 8),
          ('Barbell Calf Raise', 60, 12),
        ]),
      ];
      expect(builder.suggest(history, library, now: now).id, 'legs');
    });

    test('never-trained muscles count as most recovered', () {
      final history = [
        session(ago(days: 1), [('Squat', 100, 5), ('Bench Press', 80, 5)]),
      ];
      // Back & Biceps untouched → first preset wins.
      expect(builder.suggest(history, library, now: now).id, 'back_biceps');

      final history2 = [
        session(ago(days: 1), [('Barbell Row', 60, 8)]),
        session(ago(days: 2), [('Bench Press', 80, 5)]),
      ];
      // Back trained yesterday, chest 2 days ago, legs never.
      expect(builder.suggest(history2, library, now: now).id, 'legs');
    });
  });
}
