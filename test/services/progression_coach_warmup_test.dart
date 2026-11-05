import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';

int _n = 0;

WorkoutSet _set(String ex, double weight, int reps,
    {bool warmup = false, DateTime? at}) {
  _n++;
  return WorkoutSet(
    id: 'w-$_n',
    exerciseId: ex,
    reps: reps,
    weight: weight,
    isCompleted: true,
    completedAt: at,
    isWarmup: warmup,
  );
}

Workout _workout(String id, DateTime date, List<WorkoutSet> sets) => Workout(
      id: id,
      name: id,
      completedDate: date,
      scheduledDate: date,
      isCompleted: true,
      sets: sets,
    );

void main() {
  final kg = ProgressionCoach(useMetric: true);
  final lb = ProgressionCoach(useMetric: false);
  final d1 = DateTime(2026, 10, 1, 10);
  final d2 = DateTime(2026, 10, 4, 10);

  List<WorkoutSet> warmups(String ex) => [
        _set(ex, 50, 8, warmup: true),
        _set(ex, 70, 5, warmup: true),
        _set(ex, 85, 2, warmup: true),
      ];

  group('warm-ups are ignored by the coach', () {
    test('history, last session and target ignore warm-ups', () {
      final plain = [
        _workout('a', d1, [_set('sq', 100, 5), _set('sq', 100, 5)]),
      ];
      final withWarmups = [
        _workout('a', d1, [
          ...warmups('sq'),
          _set('sq', 100, 5),
          _set('sq', 100, 5),
        ]),
      ];
      final last = kg.lastSession('sq', withWarmups)!;
      expect(last.sets, hasLength(2));
      expect(last.formatSets(), '100×5, 100×5');
      expect(last.volume, 1000);

      final t1 = kg.target('sq', plain)!;
      final t2 = kg.target('sq', withWarmups)!;
      expect(t2.weight, t1.weight);
      expect(t2.reps, t1.reps);
      expect(t2.reason, t1.reason);
    });

    test('a session of only warm-ups is no history', () {
      final workouts = [_workout('a', d1, warmups('sq'))];
      expect(kg.history('sq', workouts), isEmpty);
      expect(kg.target('sq', workouts), isNull);
    });

    test('a heavy "warm-up" never sets a record', () {
      final previous = _workout('a', d1, [_set('sq', 100, 5)]);
      final current = _workout('b', d2, [
        _set('sq', 140, 1, warmup: true), // mislabelled heavy single
        _set('sq', 100, 5),
      ]);
      final records = kg.recordsIn(current, [previous, current]);
      expect(records, isEmpty);
    });

    test('warm-ups in history do not lower the bar for records', () {
      final previous = _workout('a', d1, [
        _set('sq', 120, 3, warmup: true),
        _set('sq', 100, 5),
      ]);
      final current = _workout('b', d2, [_set('sq', 110, 5)]);
      final types = kg
          .recordsIn(current, [previous, current])
          .where((r) => r.previous != null)
          .map((r) => r.type)
          .toSet();
      expect(types, contains(RecordType.heaviestWeight));
      expect(types, contains(RecordType.bestE1rm));
    });

    test('weekly volume ignores warm-ups', () {
      final now = DateTime(2026, 10, 8, 18);
      final workout = _workout('a', DateTime(2026, 10, 8, 10), [
        _set('sq', 60, 8, warmup: true),
        _set('sq', 100, 5),
      ]);
      final checkIn = kg.weeklyCheckIn([workout], const {}, now: now);
      expect(checkIn.setsThisWeek, 1);
      expect(checkIn.volumeThisWeek, 500);
    });
  });

  group('warmupSets', () {
    test('kg: 50/70/85 % rounded to 2.5 kg', () {
      expect(kg.warmupSets(100), const [
        WarmupSpec(50, 8),
        WarmupSpec(70, 5),
        WarmupSpec(85, 2),
      ]);
      // 61.5 → 62.5, 86.1 → 85, 104.55 → 105
      expect(kg.warmupSets(123), const [
        WarmupSpec(62.5, 8),
        WarmupSpec(85, 5),
        WarmupSpec(105, 2),
      ]);
    });

    test('lb: rounded to 5 lb', () {
      expect(lb.warmupSets(225), const [
        WarmupSpec(115, 8), // 112.5 → 115
        WarmupSpec(160, 5), // 157.5 → 160
        WarmupSpec(190, 2), // 191.25 → 190
      ]);
    });

    test('skips warm-ups at or below the empty bar', () {
      // 50 % of 60 = 30 > 20, 70 % = 42.5, 85 % = 50 (51 → 50)
      expect(kg.warmupSets(60).first.weight, 30);
      // 50 % of 40 = 20 = bar → skipped
      expect(kg.warmupSets(40), const [
        WarmupSpec(27.5, 5),
        WarmupSpec(35, 2),
      ]);
      expect(kg.warmupSets(20), isEmpty);
      expect(kg.warmupSets(0), isEmpty);
      // lb default bar is 45
      // 42.5 → 45 = bar → skipped; 59.5 → 60; 72.25 → 70
      expect(lb.warmupSets(85).map((w) => w.weight), [60, 70]);
    });

    test('uses a custom bar weight', () {
      expect(kg.warmupSets(60, barWeight: 15).first, const WarmupSpec(30, 8));
      expect(kg.warmupSets(60, barWeight: 30).first, const WarmupSpec(42.5, 5));
    });
  });
}
