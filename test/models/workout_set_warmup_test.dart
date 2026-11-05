import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout_set.dart';

void main() {
  group('WorkoutSet.isWarmup', () {
    final base = WorkoutSet(
      id: 's1',
      exerciseId: 'e1',
      reps: 5,
      weight: 100,
      isCompleted: true,
      completedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    test('defaults to false', () {
      expect(base.isWarmup, isFalse);
      expect(
          WorkoutSet.create(exerciseId: 'e', reps: 1, weight: 1).isWarmup,
          isFalse);
    });

    test('map round-trip keeps a warm-up flag', () {
      final warmup = base.copyWith(isWarmup: true);
      final map = warmup.toMap();
      expect(map['isWarmup'], 1);
      final back = WorkoutSet.fromMap(map);
      expect(back.isWarmup, isTrue);
      expect(back, warmup);
    });

    test('map round-trip of a working set', () {
      final back = WorkoutSet.fromMap(base.toMap());
      expect(back.isWarmup, isFalse);
      expect(back, base);
    });

    test('missing field reads as a working set', () {
      final map = base.toMap()..remove('isWarmup');
      expect(WorkoutSet.fromMap(map).isWarmup, isFalse);
    });

    test('accepts bool, 1/0 and the snake_case DB column', () {
      Map<String, dynamic> with_(String key, Object? value) =>
          (base.toMap()..remove('isWarmup'))..[key] = value;
      expect(WorkoutSet.fromMap(with_('isWarmup', true)).isWarmup, isTrue);
      expect(WorkoutSet.fromMap(with_('isWarmup', false)).isWarmup, isFalse);
      expect(WorkoutSet.fromMap(with_('isWarmup', 0)).isWarmup, isFalse);
      expect(WorkoutSet.fromMap(with_('is_warmup', 1)).isWarmup, isTrue);
      expect(WorkoutSet.fromMap(with_('is_warmup', 0)).isWarmup, isFalse);
      expect(WorkoutSet.fromMap(with_('isWarmup', null)).isWarmup, isFalse);
    });

    test('is part of equality and survives copyWith', () {
      expect(base.copyWith(isWarmup: true) == base, isFalse);
      expect(base.copyWith(isWarmup: true).copyWith(reps: 3).isWarmup, isTrue);
    });
  });
}
