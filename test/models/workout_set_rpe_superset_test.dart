import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/database_service.dart';

void main() {
  final base = WorkoutSet(
    id: 's1',
    exerciseId: 'e1',
    reps: 5,
    weight: 100,
    isCompleted: true,
    completedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );

  group('WorkoutSet.rpe / supersetGroup', () {
    test('default to null', () {
      expect(base.rpe, isNull);
      expect(base.supersetGroup, isNull);
      final created = WorkoutSet.create(exerciseId: 'e', reps: 1, weight: 1);
      expect(created.rpe, isNull);
      expect(created.supersetGroup, isNull);
    });

    test('map round-trip keeps both', () {
      final set = base.copyWith(rpe: 8.5, supersetGroup: 'g1');
      final map = set.toMap();
      expect(map['rpe'], 8.5);
      expect(map['supersetGroup'], 'g1');
      final back = WorkoutSet.fromMap(map);
      expect(back.rpe, 8.5);
      expect(back.supersetGroup, 'g1');
      expect(back, set);
    });

    test('map round-trip of an unrated, ungrouped set', () {
      final back = WorkoutSet.fromMap(base.toMap());
      expect(back.rpe, isNull);
      expect(back.supersetGroup, isNull);
      expect(back, base);
    });

    test('missing fields read as null', () {
      final map = base.toMap()
        ..remove('rpe')
        ..remove('supersetGroup');
      final back = WorkoutSet.fromMap(map);
      expect(back.rpe, isNull);
      expect(back.supersetGroup, isNull);
    });

    test('tolerant parsing: strings, snake_case column, bad values', () {
      Map<String, dynamic> with_(String key, Object? value) => (base.toMap()
        ..remove('rpe')
        ..remove('supersetGroup'))
        ..[key] = value;
      expect(WorkoutSet.fromMap(with_('rpe', 9)).rpe, 9.0);
      expect(WorkoutSet.fromMap(with_('rpe', '7.5')).rpe, 7.5);
      expect(WorkoutSet.fromMap(with_('rpe', '8,5')).rpe, 8.5);
      expect(WorkoutSet.fromMap(with_('rpe', 8.3)).rpe, 8.5);
      expect(WorkoutSet.fromMap(with_('rpe', 11)).rpe, isNull);
      expect(WorkoutSet.fromMap(with_('rpe', 0)).rpe, isNull);
      expect(WorkoutSet.fromMap(with_('rpe', 'hard')).rpe, isNull);
      expect(WorkoutSet.fromMap(with_('rpe', '')).rpe, isNull);
      expect(WorkoutSet.fromMap(with_('superset_group', 'g9')).supersetGroup,
          'g9');
      expect(WorkoutSet.fromMap(with_('supersetGroup', '  ')).supersetGroup,
          isNull);
    });

    test('copyWith keeps, replaces and clears', () {
      final set = base.copyWith(rpe: 9, supersetGroup: 'g');
      expect(set.copyWith(reps: 3).rpe, 9);
      expect(set.copyWith(reps: 3).supersetGroup, 'g');
      expect(set.copyWith(rpe: 7).rpe, 7);
      expect(set.copyWith(clearRpe: true).rpe, isNull);
      expect(set.copyWith(clearRpe: true).supersetGroup, 'g');
      expect(set.copyWith(clearSupersetGroup: true).supersetGroup, isNull);
      expect(set.copyWith(clearSupersetGroup: true).rpe, 9);
      expect(set == base, isFalse);
    });

    test('DB row uses the snake_case superset column and reads back', () {
      final set = base.copyWith(rpe: 10, supersetGroup: 'g1', isWarmup: false);
      final row = DatabaseService.setToRow(set, 'w1');
      expect(row['workoutId'], 'w1');
      expect(row['rpe'], 10);
      expect(row['superset_group'], 'g1');
      expect(row.containsKey('supersetGroup'), isFalse);
      expect(row['is_warmup'], 0);
      final back = WorkoutSet.fromMap(row);
      expect(back.rpe, 10);
      expect(back.supersetGroup, 'g1');
    });
  });

  group('Supersets', () {
    const order = ['a', 'b', 'c', 'd'];
    var n = 0;
    String newId() => 'new${++n}';

    setUp(() => n = 0);

    test('normalize keeps consecutive runs only', () {
      expect(Supersets.normalize(order, {'a': 'g', 'b': 'g'}),
          {'a': 'g', 'b': 'g'});
      // A run of one is dropped.
      expect(Supersets.normalize(order, {'a': 'g'}), isEmpty);
      // Non-adjacent reuse of an id: each run of one is dropped.
      expect(Supersets.normalize(order, {'a': 'g', 'c': 'g'}), isEmpty);
      // Two separate runs with one id: the second gets a fresh id.
      expect(
        Supersets.normalize(
            ['a', 'b', 'x', 'c', 'd'], {'a': 'g', 'b': 'g', 'c': 'g', 'd': 'g'},
            newId: newId),
        {'a': 'g', 'b': 'g', 'c': 'new1', 'd': 'new1'},
      );
    });

    test('the last exercise of a superset ends it and starts the rest', () {
      final groups = {'b': 'g', 'c': 'g', 'd': 'g'};
      expect(Supersets.membersOf('c', order, groups), ['b', 'c', 'd']);
      expect(Supersets.restsAfter('a', order, groups), isTrue);
      expect(Supersets.restsAfter('b', order, groups), isFalse);
      expect(Supersets.restsAfter('c', order, groups), isFalse);
      expect(Supersets.restsAfter('d', order, groups), isTrue);
      expect(Supersets.nextInGroup('b', order, groups), 'c');
      expect(Supersets.nextInGroup('d', order, groups), isNull);
      expect(Supersets.nextInGroup('a', order, groups), isNull);
    });

    test('group rest is the longest rest among its members', () {
      final rest = {'a': 60, 'b': 90, 'c': 180, 'd': 120};
      final groups = {'b': 'g', 'c': 'g', 'd': 'g'};
      int restOf(String id) => rest[id]!;
      expect(Supersets.restSecondsFor('d', order, groups, restOf), 180);
      expect(Supersets.restSecondsFor('b', order, groups, restOf), 180);
      expect(Supersets.restSecondsFor('a', order, groups, restOf), 60);
    });

    test('linkWithNext creates, joins and merges supersets', () {
      final created = Supersets.linkWithNext('a', order, {}, newId: newId);
      expect(created, {'a': 'new1', 'b': 'new1'});

      // Next already in a superset: join it.
      final joined = Supersets.linkWithNext('a', order, {'b': 'g', 'c': 'g'},
          newId: newId);
      expect(joined, {'a': 'g', 'b': 'g', 'c': 'g'});

      // This one already in a superset: the next joins it.
      final extended = Supersets.linkWithNext('b', order, {'a': 'g', 'b': 'g'},
          newId: newId);
      expect(extended, {'a': 'g', 'b': 'g', 'c': 'g'});

      // Two supersets merge.
      final merged = Supersets.linkWithNext(
          'b', order, {'a': 'g', 'b': 'g', 'c': 'h', 'd': 'h'},
          newId: newId);
      expect(merged.values.toSet(), {'h'});
      expect(merged.keys, containsAll(order));

      // Last exercise: nothing to link.
      expect(Supersets.linkWithNext('d', order, {}, newId: newId), isEmpty);
    });

    test('unlink removes an exercise and dissolves leftovers', () {
      expect(Supersets.unlink('a', order, {'a': 'g', 'b': 'g'}), isEmpty);
      expect(Supersets.unlink('a', order, {'a': 'g', 'b': 'g', 'c': 'g'}),
          {'b': 'g', 'c': 'g'});
      // Removing the middle of three leaves two singles.
      expect(Supersets.unlink('b', order, {'a': 'g', 'b': 'g', 'c': 'g'}),
          isEmpty);
    });

    test('runs and letters', () {
      expect(Supersets.runs(order, {'a': 'g', 'b': 'g', 'c': 'h', 'd': 'h'}), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
      expect(Supersets.letter(0), 'A');
      expect(Supersets.letter(1), 'B');
      expect(Supersets.letter(25), 'Z');
      expect(Supersets.letter(26), 'AA');
    });
  });
}
