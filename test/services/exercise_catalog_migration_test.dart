import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/data/default_exercises.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/exercise_catalog_migration.dart';
import 'package:testfitness/services/exercise_seed_service.dart';
import 'package:testfitness/services/rest_preferences_service.dart';

/// In-memory exercises + workouts.
class _FakeDb implements DatabaseInterface {
  final Map<String, Exercise> exercises = {};
  final Map<String, Workout> workouts = {};

  @override
  Future<void> initialize() async {}
  @override
  Future<List<Exercise>> getExercises() async => exercises.values.toList();
  @override
  Future<Exercise?> getExercise(String id) async => exercises[id];
  @override
  Future<void> insertExercise(Exercise e) async => exercises[e.id] = e;
  @override
  Future<void> updateExercise(Exercise e) async => exercises[e.id] = e;
  @override
  Future<void> deleteExercise(String id) async => exercises.remove(id);
  @override
  Future<List<Workout>> getWorkouts() async => workouts.values.toList();
  @override
  Future<Workout?> getWorkout(String id) async => workouts[id];
  @override
  Future<void> insertWorkout(Workout w) async => workouts[w.id] = w;
  @override
  Future<void> updateWorkout(Workout w) async => workouts[w.id] = w;
  @override
  Future<void> deleteWorkout(String id) async => workouts.remove(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();

  @override
  Future<List<FitnessMetric>> getMetrics() async => [];

  Exercise byName(String name) =>
      exercises.values.singleWhere((e) => e.name == name);
  bool has(String name) => exercises.values.any((e) => e.name == name);
}

Exercise _builtIn(String id, String name,
        {String? description, String? group, String? category}) =>
    Exercise(
      id: id,
      name: name,
      description: description ?? 'old',
      muscleGroup: group ?? 'Legs',
      category: category ?? 'Machine',
    );

WorkoutSet _set(String id, String exerciseId) => WorkoutSet(
    id: id, exerciseId: exerciseId, reps: 10, weight: 50, isCompleted: true);

void main() {
  late _FakeDb db;
  late RestPreferencesService rest;
  late RoutineRepository routines;

  Future<CatalogMigrationResult> migrate() => ExerciseCatalogMigration.run(db,
      routines: routines, restPreferences: rest);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    rest =
        RestPreferencesService.withPrefs(await SharedPreferences.getInstance());
    routines = RoutineRepository();
    db = _FakeDb();
  });

  test('tables only name exercises that left the library', () {
    final names = buildDefaultExercises().map((e) => e.name.toLowerCase());
    for (final old in [
      ...ExerciseCatalogMigration.renamed.keys,
      ...ExerciseCatalogMigration.merged.keys,
      ...ExerciseCatalogMigration.retired,
    ]) {
      expect(names, isNot(contains(old)), reason: old);
    }
    for (final target in [
      ...ExerciseCatalogMigration.renamed.values,
      ...ExerciseCatalogMigration.merged.values,
    ]) {
      expect(names, contains(target.toLowerCase()), reason: target);
    }
  });

  test('a fresh library needs no migration', () async {
    for (final e in buildDefaultExercises()) {
      await db.insertExercise(e);
    }
    final result = await migrate();
    expect(result.changedAnything, isFalse);
  });

  group('old install', () {
    setUp(() async {
      for (final e in [
        _builtIn('leg-curl', 'Leg Curl'),
        _builtIn('hack-press', 'Hack Squat Press'),
        _builtIn('hack', 'Hack Squat Machine'),
        _builtIn('trainer', 'Functional Trainer'),
        _builtIn('neck', 'Neck Flexion Machine'),
        _builtIn('tbar', 'T-Bar Row', description: 'Chest-supported row'),
        const Exercise(id: 'mine', name: 'Hack Squat Press', isCustom: true),
      ]) {
        await db.insertExercise(e);
      }
      await db.insertWorkout(Workout(
        id: 'w1',
        name: 'Legs',
        isCompleted: true,
        sets: [
          _set('s1', 'leg-curl'),
          _set('s2', 'hack-press'),
          _set('s3', 'hack-press'),
          _set('s4', 'mine'),
        ],
      ));
      await db.insertWorkout(
          Workout(id: 'w2', name: 'Neck', sets: [_set('s5', 'neck')]));
      await routines.saveRoutine(Routine(
        id: 'r1',
        name: 'Legs',
        createdAt: DateTime(2026),
        exercises: const [
          RoutineExercise(exerciseId: 'hack-press', sets: 4, reps: 8),
          RoutineExercise(exerciseId: 'hack', sets: 3),
          RoutineExercise(exerciseId: 'leg-curl', sets: 3),
        ],
      ));
      await rest.setRestSeconds('hack-press', 180);
    });

    test('renames in place, keeping the id and history', () async {
      await migrate();
      expect(db.has('Leg Curl'), isFalse);
      expect(db.byName('Lying Leg Curl').id, 'leg-curl');
      expect(db.workouts['w1']!.getSetsForExercise('leg-curl'), hasLength(1));
    });

    test('merges duplicates, moving every reference first', () async {
      final result = await migrate();
      expect(result.merged, {'hack-press': 'hack'});
      expect(db.exercises.containsKey('hack-press'), isFalse);
      expect(db.workouts['w1']!.getSetsForExercise('hack').map((s) => s.id),
          ['s2', 's3']);
      expect(db.workouts['w1']!.sets, hasLength(4));

      final routine = (await routines.getRoutines()).single;
      expect(routine.exercises.map((e) => e.exerciseId), ['hack', 'leg-curl']);
      expect(routine.exercises.first.sets, 4);

      expect(rest.overrideFor('hack'), 180);
      expect(rest.overrideFor('hack-press'), isNull);
      final stored = jsonDecode((await SharedPreferences.getInstance())
          .getString(RestPreferencesService.storageKey)!) as Map;
      expect(stored, {'hack': 180});
    });

    test('never touches custom exercises', () async {
      await migrate();
      expect(db.exercises['mine']!.name, 'Hack Squat Press');
      expect(db.exercises['mine']!.isCustom, isTrue);
      expect(db.workouts['w1']!.getSetsForExercise('mine'), hasLength(1));
    });

    test('retired: unused deleted, used kept as custom', () async {
      final result = await migrate();
      expect(result.retiredDeleted, 1);
      expect(result.retiredKept, 1);
      expect(db.exercises.containsKey('trainer'), isFalse);
      expect(db.exercises['neck']!.isCustom, isTrue);
      expect(db.workouts['w2']!.sets.single.exerciseId, 'neck');
    });

    test('refreshes built-in labels from the library', () async {
      await migrate();
      final library = {for (final e in buildDefaultExercises()) e.name: e};
      expect(db.byName('T-Bar Row').description,
          library['T-Bar Row']!.description);
      expect(db.byName('Lying Leg Curl').muscleGroup,
          library['Lying Leg Curl']!.muscleGroup);
    });

    test('seeding after migration: full library, no duplicates, idempotent',
        () async {
      await ExerciseSeedService.ensureDefaultExercises(db);
      final builtInNames = db.exercises.values
          .where((e) => !e.isCustom)
          .map((e) => e.name.toLowerCase())
          .toList();
      expect(builtInNames.toSet().length, builtInNames.length);
      for (final e in buildDefaultExercises()) {
        expect(db.has(e.name), isTrue, reason: e.name);
      }

      final before = Map.of(db.exercises);
      expect((await migrate()).changedAnything, isFalse);
      expect(await ExerciseSeedService.ensureDefaultExercises(db), 0);
      expect(db.exercises, before);
    });
  });

  test('merge with a missing target renames instead', () async {
    await db.insertExercise(_builtIn('glute', 'Glute Drive Machine'));
    await migrate();
    expect(db.byName('Hip Thrust Machine').id, 'glute');
  });

  test('rename whose new name was already seeded merges into it', () async {
    await db.insertExercise(_builtIn('old', 'Dumbbell Press'));
    await db.insertExercise(_builtIn('new', 'Dumbbell Bench Press'));
    await db.insertWorkout(
        Workout(id: 'w', name: 'Chest', sets: [_set('s', 'old')]));
    final result = await migrate();
    expect(result.merged, {'old': 'new'});
    expect(db.workouts['w']!.sets.single.exerciseId, 'new');
    expect(db.has('Dumbbell Press'), isFalse);
  });

  test('same-name built-in duplicates are merged', () async {
    await db.insertExercise(_builtIn('a', 'Squat'));
    await db.insertExercise(_builtIn('b', 'Squat'));
    await db
        .insertWorkout(Workout(id: 'w', name: 'Legs', sets: [_set('s', 'b')]));
    final result = await migrate();
    expect(result.merged, {'b': 'a'});
    expect(db.workouts['w']!.sets.single.exerciseId, 'a');
  });
}
