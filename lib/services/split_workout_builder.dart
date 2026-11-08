import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/utils/muscle_map.dart';

/// A muscle split: a main block (~3 exercises) and a secondary block
/// (~2 exercises).
class WorkoutSplit {
  /// 'back_biceps', 'chest_triceps', 'legs', 'shoulders_arms', 'chest_back',
  /// 'legs_core', or 'custom_<a>_<b>'.
  final String id;

  /// e.g. "Back & Biceps".
  final String name;
  final List<Muscle> main;
  final List<Muscle> secondary;

  const WorkoutSplit({
    required this.id,
    required this.name,
    required this.main,
    required this.secondary,
  });

  static const List<WorkoutSplit> presets = [
    WorkoutSplit(
      id: 'back_biceps',
      name: 'Back & Biceps',
      main: [Muscle.back],
      secondary: [Muscle.biceps],
    ),
    WorkoutSplit(
      id: 'chest_triceps',
      name: 'Chest & Triceps',
      main: [Muscle.chest],
      secondary: [Muscle.triceps],
    ),
    WorkoutSplit(
      id: 'legs',
      name: 'Legs',
      main: [Muscle.quads, Muscle.hamstrings, Muscle.glutes],
      secondary: [Muscle.calves],
    ),
    WorkoutSplit(
      id: 'shoulders_arms',
      name: 'Shoulders & Arms',
      main: [Muscle.shoulders],
      secondary: [Muscle.biceps, Muscle.triceps],
    ),
    WorkoutSplit(
      id: 'chest_back',
      name: 'Chest & Back',
      main: [Muscle.chest, Muscle.back],
      secondary: [],
    ),
    WorkoutSplit(
      id: 'legs_core',
      name: 'Legs & Core',
      main: [Muscle.quads, Muscle.hamstrings, Muscle.glutes],
      secondary: [Muscle.core],
    ),
  ];

  /// Main [a], secondary [b]. When a == b the split has no secondary block.
  factory WorkoutSplit.custom(Muscle a, Muscle b) {
    if (a == b) {
      return WorkoutSplit(
        id: 'custom_${a.name}_${b.name}',
        name: a.label,
        main: [a],
        secondary: const [],
      );
    }
    return WorkoutSplit(
      id: 'custom_${a.name}_${b.name}',
      name: '${a.label} & ${b.label}',
      main: [a],
      secondary: [b],
    );
  }

  /// Main then secondary muscles, without duplicates.
  List<Muscle> get muscles => {...main, ...secondary}.toList();

  @override
  String toString() => 'WorkoutSplit($id)';
}

/// The result of [SplitWorkoutBuilder.build].
class SplitPlan {
  /// Unsaved Workout.create(name: split.name, scheduled today,
  /// uncompleted sets).
  final Workout workout;

  /// Muscles of this split trained in the last 48 h (for a heads-up).
  final List<Muscle> recentlyTrained;

  /// e.g. "3 back + 2 biceps exercises · targets from your history".
  final String summary;

  const SplitPlan({
    required this.workout,
    required this.recentlyTrained,
    required this.summary,
  });
}

class _Pick {
  final Exercise exercise;
  final Muscle slot;
  final bool hasHistory;
  final bool compound;

  const _Pick(this.exercise, this.slot, this.hasHistory, this.compound);
}

/// Builds muscle-split workouts. Pure Dart, deterministic (no randomness).
class SplitWorkoutBuilder {
  SplitWorkoutBuilder({required bool useMetric})
      : _coach = ProgressionCoach(useMetric: useMetric);

  final ProgressionCoach _coach;

  static const int defaultMainCount = 3;
  static const int defaultSecondaryCount = 2;
  static const int setsPerExercise = 3;

  /// Well-known lifts preferred (in this order) when filling a slot from the
  /// library, so a user without history gets sensible staples.
  static const List<String> _staples = [
    'bench press',
    'dumbbell bench press',
    'incline bench press',
    'push-up',
    'cable fly',
    'barbell row',
    'lat pulldown',
    'pull-up',
    'seated row',
    'dumbbell row',
    'squat',
    'leg press',
    'romanian deadlift',
    'lying leg curl',
    'barbell hip thrust',
    'deadlift',
    'leg extension',
    'standing calf raise machine',
    'barbell calf raise',
    'overhead press',
    'lateral raise',
    'face pull',
    'barbell curl',
    'dumbbell curl',
    'hammer curl',
    'triceps pushdown',
    'skull crushers',
    'dip',
    'hanging leg raise',
    'cable crunch',
    'plank',
  ];

  /// Generic stations / niche machines never auto-picked from the library
  /// (still used when the user has history with them).
  static const Set<String> _libraryExcluded = {
    'functional trainer',
    'neck flexion machine',
  };

  /// Completed working sets (no warm-ups) with a date not after [reference].
  Iterable<(WorkoutSet, DateTime)> _datedSets(
      List<Workout> history, DateTime reference) sync* {
    for (final workout in history) {
      for (final set in workout.sets) {
        if (!ProgressionCoach.isCountable(set)) continue;
        final date = ProgressionCoach.setDate(set, workout);
        if (date == null || date.isAfter(reference)) continue;
        yield (set, date);
      }
    }
  }

  /// Most recent date each fine muscle (primary only) was trained.
  Map<Muscle, DateTime> _lastTrainedByMuscle(
      List<Workout> history, List<Exercise> exercises, DateTime reference) {
    final byId = {for (final e in exercises) e.id: e};
    final profiles = <String, MuscleProfile>{};
    final result = <Muscle, DateTime>{};
    for (final (set, date) in _datedSets(history, reference)) {
      final exercise = byId[set.exerciseId];
      if (exercise == null) continue;
      final profile =
          profiles.putIfAbsent(exercise.id, () => MuscleMap.of(exercise));
      for (final m in profile.primary) {
        final prev = result[m];
        if (prev == null || date.isAfter(prev)) result[m] = date;
      }
    }
    return result;
  }

  /// Muscles (fine) with ≥1 completed working set in the window.
  Set<Muscle> recentlyTrained(
    List<Workout> history,
    List<Exercise> exercises, {
    Duration within = const Duration(hours: 48),
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final cutoff = reference.subtract(within);
    return {
      for (final entry
          in _lastTrainedByMuscle(history, exercises, reference).entries)
        if (entry.value.isAfter(cutoff)) entry.key,
    };
  }

  /// Preset whose muscles are most recovered (longest since trained;
  /// never-trained counts as most recovered), ties by preset order.
  WorkoutSplit suggest(
    List<Workout> history,
    List<Exercise> exercises, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final last = _lastTrainedByMuscle(history, exercises, reference);

    // Most recent training date among the split's muscles; null = none
    // trained (fully recovered).
    DateTime? newest(WorkoutSplit split) {
      DateTime? result;
      for (final m in split.muscles) {
        final d = last[m];
        if (d != null && (result == null || d.isAfter(result))) result = d;
      }
      return result;
    }

    var best = WorkoutSplit.presets.first;
    var bestDate = newest(best);
    for (final split in WorkoutSplit.presets.skip(1)) {
      if (bestDate == null) break;
      final d = newest(split);
      if (d == null || d.isBefore(bestDate)) {
        best = split;
        bestDate = d;
      }
    }
    return best;
  }

  /// ~3 main + ~2 secondary exercises (override with counts), compound
  /// first, no duplicates, history first (coach targets), then library
  /// staples. 3 working sets each.
  SplitPlan build(
    WorkoutSplit split,
    List<Workout> history,
    List<Exercise> exercises, {
    WorkoutPreferences? preferences,
    DateTime? now,
    int? mainCount,
    int? secondaryCount,
  }) {
    final reference = now ?? DateTime.now();
    final splitMuscles = split.muscles;

    // Counts.
    var nMain = mainCount ?? defaultMainCount;
    var nSecondary = secondaryCount ?? defaultSecondaryCount;
    if (preferences != null && mainCount == null && secondaryCount == null) {
      final total = preferences.exerciseCount;
      if (split.secondary.isEmpty) {
        nMain = total;
      } else {
        nSecondary = (total * 0.4).round().clamp(1, total - 1);
        nMain = (total - nSecondary).clamp(1, total);
      }
    } else if (split.secondary.isEmpty && secondaryCount == null) {
      // No secondary block: its share goes to the main muscles.
      nMain += nSecondary;
    }
    if (split.secondary.isEmpty) nSecondary = 0;
    if (nMain < 0) nMain = 0;
    if (nSecondary < 0) nSecondary = 0;

    // Profiles and history.
    final profiles = {for (final e in exercises) e.id: MuscleMap.of(e)};
    final lastTrained = <String, DateTime>{};
    for (final (set, date) in _datedSets(history, reference)) {
      final prev = lastTrained[set.exerciseId];
      if (prev == null || date.isAfter(prev)) {
        lastTrained[set.exerciseId] = date;
      }
    }

    final splitTargetsCore = splitMuscles.contains(Muscle.core);
    final excludeCore =
        (preferences?.excludeCore ?? false) && !splitTargetsCore;
    final pool = exercises.where((e) {
      final p = profiles[e.id]!;
      if (p.primary.isEmpty) return false;
      if (excludeCore && p.primary.contains(Muscle.core)) return false;
      return true;
    }).toList();

    int byName(Exercise a, Exercise b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return c != 0 ? c : a.id.compareTo(b.id);
    }

    int stapleRank(Exercise e) {
      final i = _staples.indexOf(e.name.trim().toLowerCase());
      return i < 0 ? _staples.length : i;
    }

    // Candidates for a slot: history (most recent first), then library.
    List<Exercise> candidates(Muscle m, {required bool isMain}) {
      final matching = pool.where((e) => profiles[e.id]!.primarily(m)).toList();
      final withHistory =
          matching.where((e) => lastTrained.containsKey(e.id)).toList()
            ..sort((a, b) {
              final c = lastTrained[b.id]!.compareTo(lastTrained[a.id]!);
              return c != 0 ? c : byName(a, b);
            });
      final library = matching
          .where((e) =>
              !lastTrained.containsKey(e.id) &&
              !_libraryExcluded.contains(e.name.trim().toLowerCase()))
          .toList()
        ..sort((a, b) {
          final pa = profiles[a.id]!, pb = profiles[b.id]!;
          // The muscle is what the exercise is mainly known for.
          final fa = pa.primary.first == m ? 0 : 1;
          final fb = pb.primary.first == m ? 0 : 1;
          if (fa != fb) return fa - fb;
          final s = stapleRank(a).compareTo(stapleRank(b));
          if (s != 0) return s;
          // Main block: compound first; secondary block: isolation first.
          final ca = pa.compound == isMain ? 0 : 1;
          final cb = pb.compound == isMain ? 0 : 1;
          if (ca != cb) return ca - cb;
          return byName(a, b);
        });
      return [...withHistory, ...library];
    }

    final chosen = <String>{};

    List<_Pick> pickBlock(List<Muscle> muscles, int count,
        {required bool isMain}) {
      if (muscles.isEmpty || count <= 0) return const [];
      final queues = [
        for (final m in muscles) candidates(m, isMain: isMain),
      ];
      final cursors = List<int>.filled(muscles.length, 0);
      final picks = <_Pick>[];
      var turn = 0;
      var idleTurns = 0;
      while (picks.length < count && idleTurns < muscles.length) {
        final i = turn % muscles.length;
        turn++;
        final queue = queues[i];
        while (cursors[i] < queue.length &&
            chosen.contains(queue[cursors[i]].id)) {
          cursors[i]++;
        }
        if (cursors[i] >= queue.length) {
          idleTurns++;
          continue;
        }
        idleTurns = 0;
        final e = queue[cursors[i]++];
        chosen.add(e.id);
        picks.add(_Pick(e, muscles[i], lastTrained.containsKey(e.id),
            profiles[e.id]!.compound));
      }
      // Compound before isolation, otherwise keep pick order.
      return [
        ...picks.where((p) => p.compound),
        ...picks.where((p) => !p.compound),
      ];
    }

    final mainPicks = pickBlock(split.main, nMain, isMain: true);
    final secondaryPicks =
        pickBlock(split.secondary, nSecondary, isMain: false);
    final picks = [...mainPicks, ...secondaryPicks];

    // Sets.
    final focusReps = preferences?.focusReps;
    final sets = <WorkoutSet>[];
    for (final pick in picks) {
      final e = pick.exercise;
      double weight;
      int reps;
      final target = _coach.target(e.id, history);
      if (target != null) {
        weight = target.weight;
        reps = target.reps;
      } else {
        final last = _coach.lastSession(e.id, history);
        if (last != null) {
          weight = last.topSet.weight;
          reps = last.topSet.reps;
          if (focusReps != null && focusReps != reps) {
            if (weight > 0) {
              final e1rm = ProgressionCoach.estimate1RM(weight, reps);
              weight = _coach.roundToStep(e1rm / (1 + focusReps / 30));
            }
            reps = focusReps;
          }
        } else {
          weight = 0;
          reps = focusReps ?? (pick.compound ? 8 : 12);
        }
      }
      for (var i = 0; i < setsPerExercise; i++) {
        sets.add(
            WorkoutSet.create(exerciseId: e.id, reps: reps, weight: weight));
      }
    }

    // Recently trained muscles of this split.
    final recent = recentlyTrained(history, exercises, now: reference);
    final recentList = [
      for (final m in splitMuscles)
        if (recent.contains(m)) m
    ];

    final summary = _summary(split, picks);
    return SplitPlan(
      workout: Workout.create(
        name: split.name,
        scheduledDate: DateTime(reference.year, reference.month, reference.day),
        sets: sets,
        notes: summary,
      ),
      recentlyTrained: List.unmodifiable(recentList),
      summary: summary,
    );
  }

  static String _summary(WorkoutSplit split, List<_Pick> picks) {
    if (picks.isEmpty) return 'No matching exercises in your library';
    final parts = <String>[];
    for (final m in split.muscles) {
      final n = picks.where((p) => p.slot == m).length;
      if (n > 0) parts.add('$n ${m.label.toLowerCase()}');
    }
    final total = picks.length;
    final withHistory = picks.where((p) => p.hasHistory).length;
    final noun = total == 1 ? 'exercise' : 'exercises';
    final String tail;
    if (withHistory == 0) {
      tail = 'new exercises — pick a comfortable starting weight';
    } else if (withHistory == total) {
      tail = 'targets from your history';
    } else {
      tail = 'targets from your history for $withHistory of $total';
    }
    return '${parts.join(' + ')} $noun · $tail';
  }
}
