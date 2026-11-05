import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';

int _setCounter = 0;

WorkoutSet _set(
  String exerciseId,
  double weight,
  int reps, {
  bool done = true,
  DateTime? at,
}) {
  _setCounter++;
  return WorkoutSet(
    id: 'set-$_setCounter',
    exerciseId: exerciseId,
    reps: reps,
    weight: weight,
    isCompleted: done,
    completedAt: at,
  );
}

Workout _workout(
  String id,
  DateTime? date,
  List<WorkoutSet> sets, {
  DateTime? scheduled,
}) {
  return Workout(
    id: id,
    name: id,
    completedDate: date,
    scheduledDate: scheduled,
    isCompleted: date != null,
    sets: sets,
  );
}

/// Workout of [exerciseId] with sets at [weight] for each entry of [reps].
Workout _session(
  String id,
  DateTime date,
  String exerciseId,
  double weight,
  List<int> reps,
) {
  return _workout(id, date, [for (final r in reps) _set(exerciseId, weight, r)]);
}

void main() {
  final kg = ProgressionCoach(useMetric: true);
  final lb = ProgressionCoach(useMetric: false);
  final d0 = DateTime(2026, 10, 1, 10);
  DateTime day(int n) => d0.add(Duration(days: n));

  group('basics', () {
    test('weight step and unit', () {
      expect(kg.useMetric, isTrue);
      expect(kg.weightStep, 2.5);
      expect(kg.unit, 'kg');
      expect(lb.useMetric, isFalse);
      expect(lb.weightStep, 5.0);
      expect(lb.unit, 'lb');
    });

    test('estimate1RM uses Epley with edge cases', () {
      expect(ProgressionCoach.estimate1RM(100, 0), 0);
      expect(ProgressionCoach.estimate1RM(100, -3), 0);
      expect(ProgressionCoach.estimate1RM(100, 1), 100);
      expect(ProgressionCoach.estimate1RM(100, 10), closeTo(133.333, 0.001));
      expect(ProgressionCoach.estimate1RM(0, 12), 0);
    });

    test('formatNumber drops trailing .0', () {
      expect(ProgressionCoach.formatNumber(185), '185');
      expect(ProgressionCoach.formatNumber(102.5), '102.5');
      expect(ProgressionCoach.formatNumber(1.25), '1.25');
      expect(ProgressionCoach.formatNumber(0), '0');
    });

    test('roundToStep rounds to nearest step and is never negative', () {
      expect(kg.roundToStep(101), 100);
      expect(kg.roundToStep(101.3), 102.5);
      expect(lb.roundToStep(183), 185);
      expect(lb.roundToStep(-4), 0);
    });
  });

  group('history', () {
    test('newest first, only completed sets with reps > 0', () {
      final workouts = [
        _session('w1', day(0), 'bench', 100, [8, 8]),
        _session('w3', day(4), 'bench', 105, [6]),
        _workout('w2', day(2), [
          _set('bench', 102.5, 8),
          _set('bench', 102.5, 0),
          _set('bench', 102.5, 8, done: false),
          _set('squat', 140, 5),
        ]),
      ];
      final h = kg.history('bench', workouts);
      expect(h.map((s) => s.workoutId), ['w3', 'w2', 'w1']);
      expect(h[1].sets.length, 1);
      expect(h[2].volume, 1600);
      expect(kg.lastSession('bench', workouts)!.workoutId, 'w3');
      expect(kg.lastSession('deadlift', workouts), isNull);
    });

    test('date fallback: completedAt > completedDate > scheduledDate', () {
      final workouts = [
        // completedDate is old but set completedAt is newest.
        _workout('a', day(0), [_set('bench', 100, 5, at: day(10))]),
        // completedDate only.
        _workout('b', day(5), [_set('bench', 100, 5)]),
        // scheduledDate only.
        _workout('c', null, [_set('bench', 100, 5)], scheduled: day(7)),
        // no date at all → skipped.
        _workout('d', null, [_set('bench', 100, 5)]),
      ];
      final h = kg.history('bench', workouts);
      expect(h.map((s) => s.workoutId), ['a', 'c', 'b']);
      expect(h.first.date, day(10));
      expect(h[1].date, day(7));
    });

    test('excludeWorkoutId removes that workout', () {
      final workouts = [
        _session('w1', day(0), 'bench', 100, [8]),
        _session('w2', day(2), 'bench', 105, [8]),
      ];
      final h = kg.history('bench', workouts, excludeWorkoutId: 'w2');
      expect(h.map((s) => s.workoutId), ['w1']);
      expect(
          kg.lastSession('bench', workouts, excludeWorkoutId: 'w2')!.workoutId,
          'w1');
    });

    test('topSet is highest e1RM and formatSets has no trailing .0', () {
      final w = _workout('w', day(0), [
        _set('bench', 185, 8),
        _set('bench', 185, 8),
        _set('bench', 185, 7),
        _set('bench', 102.5, 3),
      ]);
      final s = lb.lastSession('bench', [w])!;
      expect(s.topSet.weight, 185);
      expect(s.topSet.reps, 8);
      expect(s.bestE1rm, closeTo(234.333, 0.001));
      expect(s.formatSets(), '185×8, 185×8, 185×7, 102.5×3');
    });

    test('formatSets shows bodyweight sets as ×reps', () {
      final s = kg.lastSession(
          'pullup', [_session('w', day(0), 'pullup', 0, [12, 10])])!;
      expect(s.formatSets(), '×12, ×10');
    });
  });

  group('target', () {
    test('null without history', () {
      expect(kg.target('bench', []), isNull);
    });

    test('increaseWeight in kg when every working set hit goal reps', () {
      final t = kg.target(
          'bench', [_session('w', day(0), 'bench', 100, [8, 8, 8])])!;
      expect(t.reason, TargetReason.increaseWeight);
      expect(t.weight, 102.5);
      expect(t.reps, 8);
      expect(t.weightDelta, 2.5);
      expect(t.repsDelta, 0);
      expect(t.message, contains('add 2.5 kg'));
      expect(t.message, isNot(contains('.0')));
    });

    test('increaseWeight in lb uses 5 lb step', () {
      final t = lb.target(
          'bench', [_session('w', day(0), 'bench', 185, [8, 8, 8])])!;
      expect(t.reason, TargetReason.increaseWeight);
      expect(t.weight, 190);
      expect(t.weightDelta, 5);
      expect(t.message, 'Hit 8 reps on every set last time — add 5 lb.');
    });

    test('increase rounds odd weights to the step', () {
      final kgT = kg.target(
          'bench', [_session('w', day(0), 'bench', 101, [5, 5])])!;
      expect(kgT.weight, 102.5);
      expect(kgT.weightDelta, closeTo(1.5, 1e-9));
      final lbT = lb.target(
          'bench', [_session('w', day(0), 'bench', 183, [5, 5])])!;
      expect(lbT.weight, 190);
    });

    test('lighter back-off sets do not count as working sets', () {
      final w = _workout('w', day(0), [
        _set('bench', 100, 8),
        _set('bench', 100, 8),
        _set('bench', 80, 5),
      ]);
      final t = kg.target('bench', [w])!;
      expect(t.reason, TargetReason.increaseWeight);
      expect(t.weight, 102.5);
    });

    test('repeat when a working set missed goal reps', () {
      final t = kg.target(
          'bench', [_session('w', day(0), 'bench', 100, [8, 8, 7])])!;
      expect(t.reason, TargetReason.repeat);
      expect(t.weight, 100);
      expect(t.reps, 8);
      expect(t.weightDelta, 0);
      expect(t.message, contains('100 kg'));
      expect(t.message, isNot(contains('100.0')));
    });

    test('repeat rounds an off-step weight', () {
      final t = kg.target(
          'bench', [_session('w', day(0), 'bench', 101, [8, 6])])!;
      expect(t.reason, TargetReason.repeat);
      expect(t.weight, 100);
      expect(t.weightDelta, -1);
    });

    test('deload after 3 stalled sessions at same weight', () {
      final workouts = [
        _session('w1', day(0), 'bench', 100, [8, 8, 6]),
        _session('w2', day(3), 'bench', 100, [8, 7, 6]),
        _session('w3', day(6), 'bench', 100, [8, 8, 7]),
      ];
      final t = kg.target('bench', workouts)!;
      expect(t.reason, TargetReason.deload);
      expect(t.weight, 90);
      expect(t.reps, 8);
      expect(t.weightDelta, -10);
      expect(t.message, contains('lighter week'));
      expect(t.message, contains('90 kg'));
    });

    test('deload rounds to lb step', () {
      final workouts = [
        _session('w1', day(0), 'bench', 185, [5, 4]),
        _session('w2', day(3), 'bench', 185, [5, 4]),
        _session('w3', day(6), 'bench', 185, [5, 3]),
      ];
      final t = lb.target('bench', workouts)!;
      expect(t.reason, TargetReason.deload);
      expect(t.weight, 165); // 166.5 → 165
      expect(t.message, contains('165 lb'));
    });

    test('no deload when one of the last 3 sessions improved e1RM > 1%', () {
      final workouts = [
        _session('w0', day(0), 'bench', 95, [8, 8, 6]),
        _session('w1', day(3), 'bench', 100, [8, 8, 6]),
        _session('w2', day(6), 'bench', 100, [8, 7, 6]),
        _session('w3', day(9), 'bench', 100, [8, 8, 7]),
      ];
      expect(kg.target('bench', workouts)!.reason, TargetReason.repeat);
    });

    test('no deload when a recent session succeeded', () {
      final workouts = [
        _session('w1', day(0), 'bench', 100, [8, 8, 6]),
        _session('w2', day(3), 'bench', 100, [8, 8, 8]),
        _session('w3', day(6), 'bench', 102.5, [8, 8, 7]),
      ];
      expect(kg.target('bench', workouts)!.reason, TargetReason.repeat);
    });

    test('no deload with only 2 stalled sessions', () {
      final workouts = [
        _session('w1', day(0), 'bench', 100, [8, 6]),
        _session('w2', day(3), 'bench', 100, [8, 6]),
      ];
      expect(kg.target('bench', workouts)!.reason, TargetReason.repeat);
    });

    test('bodyweight → increaseReps from max reps', () {
      final t = kg.target(
          'pullup', [_session('w', day(0), 'pullup', 0, [10, 12, 11])])!;
      expect(t.reason, TargetReason.increaseReps);
      expect(t.weight, 0);
      expect(t.reps, 13);
      expect(t.weightDelta, 0);
      expect(t.repsDelta, 3);
      expect(t.message, contains('13'));
    });

    test('excludeWorkoutId ignores the in-progress workout', () {
      final workouts = [
        _session('old', day(0), 'bench', 100, [8, 8]),
        _session('current', day(2), 'bench', 102.5, [8, 5]),
      ];
      expect(kg.target('bench', workouts)!.reason, TargetReason.repeat);
      final t = kg.target('bench', workouts, excludeWorkoutId: 'current')!;
      expect(t.reason, TargetReason.increaseWeight);
      expect(t.weight, 102.5);
    });
  });

  group('recordsIn', () {
    test('first time records have null previous', () {
      final w = _session('w', day(0), 'bench', 100, [5, 5]);
      final records = kg.recordsIn(w, [w]);
      expect(records.map((r) => r.type), [
        RecordType.bestE1rm,
        RecordType.heaviestWeight,
        RecordType.mostVolume,
      ]);
      expect(records.every((r) => r.previous == null), isTrue);
      expect(records[0].value, closeTo(116.667, 0.001));
      expect(records[1].value, 100);
      expect(records[2].value, 1000);
    });

    test('beating previous bests reports previous values', () {
      final old = _session('old', day(0), 'bench', 100, [5, 5]);
      final now = _session('new', day(3), 'bench', 105, [5, 5]);
      final records = kg.recordsIn(now, [old, now]);
      expect(records.length, 3);
      final heaviest =
          records.firstWhere((r) => r.type == RecordType.heaviestWeight);
      expect(heaviest.value, 105);
      expect(heaviest.previous, 100);
      final volume = records.firstWhere((r) => r.type == RecordType.mostVolume);
      expect(volume.value, 1050);
      expect(volume.previous, 1000);
      final e1rm = records.firstWhere((r) => r.type == RecordType.bestE1rm);
      expect(e1rm.previous, closeTo(116.667, 0.001));
      expect(kg.describeRecord(heaviest),
          'New heaviest weight: 105 kg (was 100 kg).');
    });

    test('only volume record when more reps at same weight but lower e1RM', () {
      final old = _session('old', day(0), 'bench', 100, [8]);
      final now = _session('new', day(3), 'bench', 100, [6, 6]);
      final records = kg.recordsIn(now, [old, now]);
      expect(records.map((r) => r.type), [RecordType.mostVolume]);
      expect(records.single.previous, 800);
    });

    test('no records when previous bests not beaten', () {
      final old = _session('old', day(0), 'bench', 110, [5, 5, 5]);
      final now = _session('new', day(3), 'bench', 100, [5]);
      expect(kg.recordsIn(now, [old, now]), isEmpty);
    });

    test('later workouts are not counted as previous', () {
      final now = _session('new', day(0), 'bench', 100, [5]);
      final later = _session('later', day(5), 'bench', 150, [5]);
      final records = kg.recordsIn(now, [now, later]);
      expect(records.length, 3);
      expect(records.every((r) => r.previous == null), isTrue);
    });

    test('bodyweight sets do not create weight records', () {
      final w = _session('w', day(0), 'pullup', 0, [10]);
      expect(kg.recordsIn(w, [w]), isEmpty);
    });
  });

  group('trend', () {
    final now = day(60);

    test('points oldest first with change percent', () {
      final workouts = [
        _session('w2', day(50), 'bench', 110, [1]),
        _session('w1', day(40), 'bench', 100, [1]),
      ];
      final t = kg.trend('bench', workouts, now: now);
      expect(t.exerciseId, 'bench');
      expect(t.points.map((p) => p.value), [100, 110]);
      expect(t.points.first.key, day(40));
      expect(t.changePercent, closeTo(10, 1e-9));
      expect(t.plateau, isFalse);
    });

    test('window excludes old sessions; < 2 points → null change', () {
      final workouts = [
        _session('old', day(0), 'bench', 80, [1]),
        _session('w1', day(50), 'bench', 100, [1]),
      ];
      final t = kg.trend('bench', workouts, weeks: 2, now: now);
      expect(t.points.length, 1);
      expect(t.changePercent, isNull);
      expect(t.plateau, isFalse);
    });

    test('plateau when last 3 sessions not > 1% above earlier best', () {
      final workouts = [
        _session('a', day(30), 'bench', 100, [1]),
        _session('b', day(35), 'bench', 100.5, [1]),
        _session('c', day(40), 'bench', 99, [1]),
        _session('d', day(45), 'bench', 100.9, [1]),
      ];
      expect(kg.trend('bench', workouts, now: now).plateau, isTrue);
    });

    test('no plateau when progressing', () {
      final workouts = [
        _session('a', day(30), 'bench', 100, [1]),
        _session('b', day(35), 'bench', 101, [1]),
        _session('c', day(40), 'bench', 102, [1]),
        _session('d', day(45), 'bench', 103, [1]),
      ];
      expect(kg.trend('bench', workouts, now: now).plateau, isFalse);
    });

    test('no plateau with fewer than 4 sessions', () {
      final workouts = [
        _session('a', day(30), 'bench', 100, [1]),
        _session('b', day(35), 'bench', 100, [1]),
        _session('c', day(40), 'bench', 100, [1]),
      ];
      expect(kg.trend('bench', workouts, now: now).plateau, isFalse);
    });
  });

  group('weeklyCheckIn', () {
    // Wednesday 4 Nov 2026, 12:00 → week starts Monday 2 Nov.
    final now = DateTime(2026, 11, 4, 12);
    const exercises = {
      'bench': Exercise(id: 'bench', name: 'Bench Press', muscleGroup: 'Chest'),
      'squat': Exercise(id: 'squat', name: 'Back Squat', muscleGroup: 'legs'),
      'row': Exercise(id: 'row', name: 'Row', muscleGroup: 'Back, Arms'),
    };

    test('week starts Monday 00:00 and boundaries are respected', () {
      final workouts = [
        _session('mon', DateTime(2026, 11, 2), 'bench', 100, [5, 5]),
        _session('sun', DateTime(2026, 11, 1, 23, 59), 'bench', 100, [5]),
      ];
      final c = kg.weeklyCheckIn(workouts, exercises, now: now);
      expect(c.weekStart, DateTime(2026, 11, 2));
      expect(c.workoutsThisWeek, 1);
      expect(c.setsThisWeek, 2);
      expect(c.volumeThisWeek, 1000);
      expect(c.volumeLastWeek, 500);
    });

    test('weekStart on a Monday and Sunday', () {
      final monday = kg.weeklyCheckIn([], exercises,
          now: DateTime(2026, 11, 2, 0, 0));
      expect(monday.weekStart, DateTime(2026, 11, 2));
      final sunday = kg.weeklyCheckIn([], exercises,
          now: DateTime(2026, 11, 8, 23, 0));
      expect(sunday.weekStart, DateTime(2026, 11, 2));
    });

    test('empty history', () {
      final c = kg.weeklyCheckIn([], exercises, now: now);
      expect(c.workoutsThisWeek, 0);
      expect(c.setsThisWeek, 0);
      expect(c.volumeThisWeek, 0);
      expect(c.volumeLastWeek, isNull);
      expect(c.setsPerMuscleGroup, isEmpty);
      expect(c.neglectedMuscleGroups, isEmpty);
      expect(c.recordsThisWeek, isEmpty);
      expect(c.streakWeeks, 0);
      expect(c.plateaus, isEmpty);
    });

    test('sets per normalised muscle group and neglected groups', () {
      final workouts = [
        _workout('this', DateTime(2026, 11, 3, 18), [
          _set('bench', 100, 5),
          _set('bench', 100, 5),
          _set('row', 60, 10),
        ]),
        _session('old', DateTime(2026, 10, 15), 'squat', 140, [5]),
        _session('ancient', DateTime(2026, 9, 1), 'bench', 90, [5]),
      ];
      final c = kg.weeklyCheckIn(workouts, exercises, now: now);
      expect(c.setsPerMuscleGroup, {'Chest': 2, 'Back': 1, 'Arms': 1});
      expect(c.neglectedMuscleGroups, ['Legs']);
      expect(c.volumeLastWeek, isNull);
    });

    test('records this week are included', () {
      final workouts = [
        _session('old', DateTime(2026, 10, 20), 'bench', 100, [5]),
        _session('new', DateTime(2026, 11, 3), 'bench', 105, [5]),
      ];
      final c = kg.weeklyCheckIn(workouts, exercises, now: now);
      expect(c.recordsThisWeek.map((r) => r.type),
          contains(RecordType.heaviestWeight));
      expect(c.recordsThisWeek.every((r) => r.previous != null), isTrue);
    });

    test('streak counts consecutive weeks ending this week', () {
      final workouts = [
        _session('a', DateTime(2026, 11, 3), 'bench', 100, [5]),
        _session('b', DateTime(2026, 10, 27), 'bench', 100, [5]),
        _session('c', DateTime(2026, 10, 19), 'bench', 100, [5]),
        // gap week of 12 Oct
        _session('d', DateTime(2026, 10, 6), 'bench', 100, [5]),
      ];
      expect(kg.weeklyCheckIn(workouts, exercises, now: now).streakWeeks, 3);
    });

    test('streak may end last week if nothing this week yet', () {
      final workouts = [
        _session('b', DateTime(2026, 10, 27), 'bench', 100, [5]),
        _session('c', DateTime(2026, 10, 19), 'bench', 100, [5]),
      ];
      expect(kg.weeklyCheckIn(workouts, exercises, now: now).streakWeeks, 2);
    });

    test('streak is 0 when last workout was two weeks ago', () {
      final workouts = [
        _session('c', DateTime(2026, 10, 19), 'bench', 100, [5]),
      ];
      expect(kg.weeklyCheckIn(workouts, exercises, now: now).streakWeeks, 0);
    });

    test('plateaued exercises are listed', () {
      final workouts = [
        _session('a', DateTime(2026, 10, 1), 'bench', 100, [5]),
        _session('b', DateTime(2026, 10, 8), 'bench', 100, [5]),
        _session('c', DateTime(2026, 10, 15), 'bench', 100, [5]),
        _session('d', DateTime(2026, 10, 22), 'bench', 100, [5]),
        _session('e', DateTime(2026, 10, 1), 'squat', 100, [5]),
        _session('f', DateTime(2026, 10, 22), 'squat', 120, [5]),
      ];
      final c = kg.weeklyCheckIn(workouts, exercises, now: now);
      expect(c.plateaus.map((t) => t.exerciseId), ['bench']);
    });
  });

  group('suggestNextWorkout', () {
    final now = DateTime(2026, 11, 4, 12);
    const library = [
      Exercise(id: 'bench', name: 'Bench Press', muscleGroup: 'Chest'),
      Exercise(id: 'fly', name: 'Cable Fly', muscleGroup: 'Chest'),
      Exercise(id: 'squat', name: 'Back Squat', muscleGroup: 'Legs'),
      Exercise(id: 'row', name: 'Barbell Row', muscleGroup: 'Back'),
      Exercise(id: 'curl', name: 'Biceps Curl', muscleGroup: 'Arms'),
      Exercise(id: 'ohp', name: 'Overhead Press', muscleGroup: 'Shoulders'),
      Exercise(id: 'plank', name: 'Plank', muscleGroup: 'Core'),
      Exercise(id: 'pecdeck', name: 'Pec Deck', muscleGroup: 'Chest'),
    ];
    List<Workout> history() => [
          _session('h-bench', now.subtract(const Duration(hours: 24)), 'bench',
              100, [8, 8, 8]),
          _session('h-fly', now.subtract(const Duration(days: 10)), 'fly', 20,
              [12, 12]),
          _session('h-squat', now.subtract(const Duration(days: 5)), 'squat',
              140, [5, 5, 4]),
          _session('h-row', now.subtract(const Duration(days: 3)), 'row', 80,
              [8, 8]),
          _session('h-curl', now.subtract(const Duration(days: 12)), 'curl',
              15, [10, 10]),
        ];

    List<String> order(Workout w) {
      final ids = <String>[];
      for (final s in w.sets) {
        if (!ids.contains(s.exerciseId)) ids.add(s.exerciseId);
      }
      return ids;
    }

    test('most overdue recovered history first, then fillers', () {
      final w = kg.suggestNextWorkout(history(), library, now: now);
      expect(w.name, 'Next Workout');
      expect(w.scheduledDate, DateTime(2026, 11, 4));
      expect(w.isCompleted, isFalse);
      expect(w.completedDate, isNull);
      // fly & pec deck are Chest → resting (bench 24 h ago).
      expect(order(w), ['curl', 'squat', 'row', 'ohp', 'plank']);
      expect(w.sets.length, 15);
      expect(w.sets.every((s) => !s.isCompleted), isTrue);
    });

    test('history exercises use coach targets, fillers 3×8 at 0', () {
      final w = kg.suggestNextWorkout(history(), library, now: now);
      final curl = w.getSetsForExercise('curl');
      expect(curl.length, 3);
      expect(curl.every((s) => s.weight == 17.5 && s.reps == 10), isTrue);
      final squat = w.getSetsForExercise('squat');
      expect(squat.every((s) => s.weight == 140 && s.reps == 5), isTrue);
      final ohp = w.getSetsForExercise('ohp');
      expect(ohp.length, 3);
      expect(ohp.every((s) => s.weight == 0 && s.reps == 8), isTrue);
    });

    test('is deterministic', () {
      final a = kg.suggestNextWorkout(history(), library, now: now);
      final b = kg.suggestNextWorkout(history(), library, now: now);
      expect(order(a), order(b));
      expect(a.sets.map((s) => '${s.exerciseId}:${s.weight}x${s.reps}'),
          b.sets.map((s) => '${s.exerciseId}:${s.weight}x${s.reps}'));
      final shuffled = kg.suggestNextWorkout(
          history().reversed.toList(), library.reversed.toList(),
          now: now);
      expect(order(shuffled), order(a));
    });

    test('respects exerciseCount', () {
      final w = kg.suggestNextWorkout(history(), library,
          now: now, exerciseCount: 2);
      expect(order(w), ['curl', 'squat']);
    });

    test('48 h recovery boundary', () {
      final workouts = [
        _session('a', now.subtract(const Duration(hours: 47)), 'bench', 100,
            [8]),
        _session('b', now.subtract(const Duration(hours: 49)), 'squat', 140,
            [5]),
      ];
      final w = kg.suggestNextWorkout(workouts, library, now: now);
      final ids = order(w);
      expect(ids.first, 'squat');
      expect(ids, isNot(contains('bench')));
      expect(ids, isNot(contains('fly')));
      expect(ids, isNot(contains('pecdeck')));
    });

    test('fillers prefer least-trained muscle groups this week', () {
      final workouts = [
        _session('a', now.subtract(const Duration(days: 4)), 'row', 80,
            [8, 8, 8]),
      ];
      const lib = [
        Exercise(id: 'row', name: 'Barbell Row', muscleGroup: 'Back'),
        Exercise(id: 'pulldown', name: 'Lat Pulldown', muscleGroup: 'Back'),
        Exercise(id: 'plank', name: 'Plank', muscleGroup: 'Core'),
      ];
      final w = kg.suggestNextWorkout(workouts, lib, now: now, exerciseCount: 3);
      expect(order(w), ['row', 'plank', 'pulldown']);
    });

    test('with no history uses library exercises at 3×8', () {
      final w = kg.suggestNextWorkout([], library, now: now, exerciseCount: 3);
      expect(w.sets.length, 9);
      expect(w.sets.every((s) => s.reps == 8 && s.weight == 0), isTrue);
      expect(order(w).length, 3);
    });
  });
}
