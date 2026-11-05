import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';

int _n = 0;

/// Session of [reps] at [weight]; [rpe] rates each set (null = unrated).
Workout _session(
  String id,
  DateTime date,
  double weight,
  List<int> reps, {
  List<double?>? rpe,
}) {
  return Workout(
    id: id,
    name: id,
    completedDate: date,
    isCompleted: true,
    sets: [
      for (var i = 0; i < reps.length; i++)
        WorkoutSet(
          id: 'set-${_n++}',
          exerciseId: 'bench',
          reps: reps[i],
          weight: weight,
          isCompleted: true,
          rpe: rpe?[i],
        ),
    ],
  );
}

void main() {
  final kg = ProgressionCoach(useMetric: true);
  final d0 = DateTime(2026, 10, 1, 10);
  DateTime day(int n) => d0.add(Duration(days: n));

  group('target with RPE', () {
    test('unrated: unchanged single step', () {
      final t = kg.target('bench', [
        _session('w', day(0), 100, [8, 8, 8])
      ])!;
      expect(t.reason, TargetReason.increaseWeight);
      expect(t.weight, 102.5);
      expect(t.message, 'Hit 8 reps on every set last time — add 2.5 kg.');
    });

    test('rated <= 9: single step as before', () {
      final t = kg.target('bench', [
        _session('w', day(0), 100, [8, 8, 8], rpe: [8, 8.5, 9]),
      ])!;
      expect(t.reason, TargetReason.increaseWeight);
      expect(t.weight, 102.5);
      expect(t.message, 'Hit 8 reps on every set last time — add 2.5 kg.');
    });

    test('any working set at RPE 9.5+: repeat and own it', () {
      final t = kg.target('bench', [
        _session('w', day(0), 100, [8, 8, 8], rpe: [8, 9, 9.5]),
      ])!;
      expect(t.reason, TargetReason.repeat);
      expect(t.weight, 100);
      expect(t.weightDelta, 0);
      expect(t.message,
          'Last time was a grinder (RPE 9.5) — repeat the weight and own it.');

      final ten = kg.target('bench', [
        _session('w', day(0), 100, [8, 8], rpe: [10, null]),
      ])!;
      expect(ten.reason, TargetReason.repeat);
      expect(ten.message, contains('RPE 10'));
    });

    test('all working sets RPE <= 7: double step', () {
      final t = kg.target('bench', [
        _session('w', day(0), 100, [8, 8, 8], rpe: [6, 7, 7]),
      ])!;
      expect(t.reason, TargetReason.increaseWeight);
      expect(t.weight, 105);
      expect(t.weightDelta, 5);
      expect(t.message, contains('RPE 7 or easier'));
      expect(t.message, contains('add 5 kg'));
    });

    test('partly rated easy session: only a single step', () {
      final t = kg.target('bench', [
        _session('w', day(0), 100, [8, 8, 8], rpe: [6, 6, null]),
      ])!;
      expect(t.weight, 102.5);
    });

    test('missed reps: RPE does not change the repeat', () {
      final t = kg.target('bench', [
        _session('w', day(0), 100, [8, 8, 7], rpe: [6, 6, 6]),
      ])!;
      expect(t.reason, TargetReason.repeat);
      expect(t.weight, 100);
    });

    test('deload after 2 sessions averaging RPE 9.5+ without e1RM progress',
        () {
      final t = kg.target('bench', [
        _session('w1', day(0), 100, [8, 8, 7], rpe: [9.5, 10, 10]),
        _session('w2', day(3), 100, [8, 8, 7], rpe: [9.5, 9.5, 10]),
      ])!;
      expect(t.reason, TargetReason.deload);
      expect(t.weight, 90);
      expect(t.message, contains('RPE 9.5+'));
      expect(t.message, contains('lighter week'));
    });

    test('no effort deload when e1RM progressed', () {
      final t = kg.target('bench', [
        _session('w1', day(0), 100, [8, 8, 6], rpe: [10, 10, 10]),
        _session('w2', day(3), 105, [8, 8, 7], rpe: [9.5, 10, 10]),
      ])!;
      expect(t.reason, isNot(TargetReason.deload));
    });

    test('no effort deload when one session averaged below 9.5', () {
      final t = kg.target('bench', [
        _session('w1', day(0), 100, [8, 8, 7], rpe: [9, 9, 9.5]),
        _session('w2', day(3), 100, [8, 8, 7], rpe: [10, 10, 10]),
      ])!;
      expect(t.reason, TargetReason.repeat);
    });

    test('no effort deload without ratings (existing rules only)', () {
      final t = kg.target('bench', [
        _session('w1', day(0), 100, [8, 8, 7]),
        _session('w2', day(3), 100, [8, 8, 7]),
      ])!;
      expect(t.reason, TargetReason.repeat);
    });

    test('averageRpe ignores unrated sets', () {
      final w = _session('w', day(0), 100, [8, 8, 8], rpe: [8, null, 9]);
      expect(ProgressionCoach.averageRpe(w.sets), 8.5);
      expect(ProgressionCoach.averageRpe(_session('x', day(0), 100, [8]).sets),
          isNull);
    });
  });
}
