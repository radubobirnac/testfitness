import 'package:testfitness/data/default_exercises.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/rest_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';

/// What [ExerciseCatalogMigration.run] changed.
class CatalogMigrationResult {
  /// Built-ins renamed in place (same id, so history follows automatically).
  final int renamed;

  /// Old exercise id → id it was merged into.
  final Map<String, String> merged;

  /// Retired built-ins deleted because nothing referenced them.
  final int retiredDeleted;

  /// Retired built-ins kept as custom exercises because they have history.
  final int retiredKept;

  /// Built-ins whose description / muscle group / category was refreshed.
  final int relabeled;

  /// Workouts whose sets were moved to a merged exercise.
  final int workoutsUpdated;

  const CatalogMigrationResult({
    this.renamed = 0,
    this.merged = const {},
    this.retiredDeleted = 0,
    this.retiredKept = 0,
    this.relabeled = 0,
    this.workoutsUpdated = 0,
  });

  bool get changedAnything =>
      renamed > 0 ||
      merged.isNotEmpty ||
      retiredDeleted > 0 ||
      retiredKept > 0 ||
      relabeled > 0;

  @override
  String toString() => 'renamed $renamed, merged ${merged.length}, '
      'retired $retiredDeleted deleted / $retiredKept kept, '
      'relabeled $relabeled, workouts updated $workoutsUpdated';
}

/// Brings an existing install's built-in exercises in line with
/// [buildDefaultExercises] without losing history.
///
/// Seeding only adds missing defaults by name, so renaming, merging or
/// relabeling a built-in needs this step. It is idempotent and runs before
/// seeding on every launch and after every backup import (old backups bring
/// old names back). Only built-ins (`isCustom == false`) are touched; the
/// user's custom exercises are never changed.
///
/// Every reference to an exercise id is moved before an exercise is deleted:
/// workout sets (database), routines and per-exercise rest overrides
/// (shared preferences).
class ExerciseCatalogMigration {
  /// Old built-in name (lower-case) → new name. Renamed in place.
  static const Map<String, String> renamed = {
    'leg curl': 'Lying Leg Curl',
    'dumbbell press': 'Dumbbell Bench Press',
    'triceps extension': 'Dumbbell Triceps Extension',
    'bicep curl machine': 'Biceps Curl Machine',
    'tricep extension machine': 'Triceps Extension Machine',
    'assisted pull up': 'Assisted Pull-up',
    'assisted chin up': 'Assisted Chin-up',
  };

  /// Duplicate built-in (lower-case) → the exercise it is merged into.
  static const Map<String, String> merged = {
    'hack squat press': 'Hack Squat Machine',
    'leg press hack squat combo': 'Hack Squat Machine',
    'seated ab crunch machine': 'Ab Crunch Machine',
    'chest-supported t-bar row machine': 'T-Bar Row Machine',
    'glute drive machine': 'Hip Thrust Machine',
    'low row machine': 'Seated Row',
    'iso-lateral high row machine': 'High Row Machine',
    'assisted pull-up/dip machine': 'Assisted Pull-up',
    'cable crossover station': 'Cable Fly',
  };

  /// Built-ins no longer in the library: deleted when unused, otherwise kept
  /// as custom exercises so their history stays.
  static const Set<String> retired = {
    'functional trainer',
    'neck flexion machine',
  };

  static String _key(String name) => name.trim().toLowerCase();

  static Future<CatalogMigrationResult> run(
    DatabaseInterface db, {
    RoutineRepository? routines,
    RestPreferencesService? restPreferences,
  }) async {
    final exercises = List<Exercise>.of(await db.getExercises());

    Exercise? findByName(String name, {required String excludeId}) {
      final key = _key(name);
      Exercise? custom;
      for (final e in exercises) {
        if (e.id == excludeId || _key(e.name) != key) continue;
        if (!e.isCustom) return e;
        custom ??= e;
      }
      return custom;
    }

    Future<void> replace(Exercise updated) async {
      await db.updateExercise(updated);
      final i = exercises.indexWhere((e) => e.id == updated.id);
      if (i >= 0) exercises[i] = updated;
    }

    var renamedCount = 0;
    final remap = <String, String>{};

    // Renames first, then merges (a merge target may be a renamed exercise).
    for (final table in [renamed, merged]) {
      for (final old in List<Exercise>.of(exercises)) {
        if (old.isCustom || remap.containsKey(old.id)) continue;
        final newName = table[_key(old.name)];
        if (newName == null) continue;
        final target = findByName(newName, excludeId: old.id);
        if (target == null) {
          await replace(old.copyWith(name: newName));
          renamedCount++;
        } else {
          remap[old.id] = target.id;
        }
      }
    }

    // Same-name built-in duplicates (e.g. from an old seeding bug).
    final firstByName = <String, String>{};
    for (final e in exercises) {
      if (e.isCustom || remap.containsKey(e.id)) continue;
      final existing = firstByName[_key(e.name)];
      if (existing == null) {
        firstByName[_key(e.name)] = e.id;
      } else {
        remap[e.id] = existing;
      }
    }

    final retiredExercises = exercises
        .where((e) =>
            !e.isCustom &&
            !remap.containsKey(e.id) &&
            retired.contains(_key(e.name)))
        .toList();

    var workoutsUpdated = 0;
    var retiredDeleted = 0;
    var retiredKept = 0;
    if (remap.isNotEmpty || retiredExercises.isNotEmpty) {
      final routineRepo = routines ?? RoutineRepository();
      final workouts = await db.getWorkouts();

      // Move workout sets.
      for (final workout in workouts) {
        if (!workout.sets.any((s) => remap.containsKey(s.exerciseId))) {
          continue;
        }
        var updated = workout;
        for (final entry in remap.entries) {
          updated = updated.replaceExercise(entry.key, entry.value);
        }
        await db.updateWorkout(updated);
        workoutsUpdated++;
      }

      // Move routines and rest overrides.
      final allRoutines = await routineRepo.getRoutines();
      if (remap.isNotEmpty) {
        for (final routine in allRoutines) {
          final moved = _remapRoutine(routine, remap);
          if (moved != null) await routineRepo.saveRoutine(moved);
        }
        final rest = restPreferences ?? RestPreferencesService();
        await rest.initialize();
        for (final entry in remap.entries) {
          final seconds = rest.overrideFor(entry.key);
          if (seconds == null) continue;
          if (rest.overrideFor(entry.value) == null) {
            await rest.setRestSeconds(entry.value, seconds);
          }
          await rest.setRestSeconds(entry.key, null);
        }
      }

      // Merged exercises are now unreferenced.
      for (final id in remap.keys) {
        await db.deleteExercise(id);
      }
      exercises.removeWhere((e) => remap.containsKey(e.id));

      // Retired: keep (as custom) when anything still uses them.
      final used = <String>{
        for (final w in workouts) ...w.exerciseIds,
        for (final r in allRoutines) ...r.exercises.map((e) => e.exerciseId),
      };
      for (final e in retiredExercises) {
        if (used.contains(e.id)) {
          await replace(e.copyWith(isCustom: true));
          retiredKept++;
        } else {
          await db.deleteExercise(e.id);
          exercises.removeWhere((x) => x.id == e.id);
          retiredDeleted++;
        }
      }
    }

    // Refresh labels of built-ins from the library.
    var relabeled = 0;
    final defaults = {for (final d in buildDefaultExercises()) _key(d.name): d};
    for (final e in List<Exercise>.of(exercises)) {
      if (e.isCustom) continue;
      final d = defaults[_key(e.name)];
      if (d == null) continue;
      if (e.name != d.name ||
          e.description != d.description ||
          e.muscleGroup != d.muscleGroup ||
          e.category != d.category) {
        await replace(e.copyWith(
          name: d.name,
          description: d.description,
          muscleGroup: d.muscleGroup,
          category: d.category,
        ));
        relabeled++;
      }
    }

    final result = CatalogMigrationResult(
      renamed: renamedCount,
      merged: Map.unmodifiable(remap),
      retiredDeleted: retiredDeleted,
      retiredKept: retiredKept,
      relabeled: relabeled,
      workoutsUpdated: workoutsUpdated,
    );
    if (result.changedAnything) {
      AppLogger.database('Exercise catalog migration', result.toString());
    }
    return result;
  }

  /// [routine] with exercise ids remapped (first occurrence kept when two
  /// slots end up on the same exercise), or null when nothing changed.
  static Routine? _remapRoutine(Routine routine, Map<String, String> remap) {
    if (!routine.exercises.any((e) => remap.containsKey(e.exerciseId))) {
      return null;
    }
    final seen = <String>{};
    final exercises = <RoutineExercise>[];
    for (final e in routine.exercises) {
      final id = remap[e.exerciseId] ?? e.exerciseId;
      if (!seen.add(id)) continue;
      exercises.add(RoutineExercise(
        exerciseId: id,
        sets: e.sets,
        reps: e.reps,
        supersetGroup: e.supersetGroup,
      ));
    }
    return routine.copyWith(exercises: exercises);
  }
}
