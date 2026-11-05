import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/utils/exercise_metadata.dart';

/// Why the coach picked a particular target for the next session.
enum TargetReason { increaseWeight, increaseReps, repeat, deload }

/// Kinds of personal record the coach detects.
enum RecordType { bestE1rm, heaviestWeight, mostVolume }

/// One workout's worth of completed sets for a single exercise.
class SessionSummary {
  final String workoutId;
  final DateTime date;

  /// Completed working sets (reps > 0, no warm-ups) for this exercise in that workout, logged order.
  final List<WorkoutSet> sets;

  /// Set with the highest estimated 1RM.
  final WorkoutSet topSet;
  final double bestE1rm;

  /// Sum of weight * reps.
  final double volume;

  const SessionSummary({
    required this.workoutId,
    required this.date,
    required this.sets,
    required this.topSet,
    required this.bestE1rm,
    required this.volume,
  });

  /// e.g. "185×8, 185×8, 185×7" — weights without trailing ".0";
  /// bodyweight sets as "×12".
  String formatSets() {
    return sets.map((s) {
      if (s.weight <= 0) return '×${s.reps}';
      return '${ProgressionCoach.formatNumber(s.weight)}×${s.reps}';
    }).join(', ');
  }

  @override
  String toString() => 'SessionSummary($workoutId, $date, ${formatSets()})';
}

/// What the coach recommends for the next session of an exercise.
class ProgressionTarget {
  final double weight;
  final int reps;
  final TargetReason reason;

  /// target.weight - last session working weight.
  final double weightDelta;

  /// target.reps - last session goal reps.
  final int repsDelta;

  /// Short plain-language, unit-aware reason.
  final String message;

  const ProgressionTarget({
    required this.weight,
    required this.reps,
    required this.reason,
    required this.weightDelta,
    required this.repsDelta,
    required this.message,
  });

  @override
  String toString() =>
      'ProgressionTarget($weight × $reps, $reason, Δw=$weightDelta, Δr=$repsDelta)';
}

/// A personal record achieved in a workout.
class PersonalRecord {
  final String exerciseId;
  final RecordType type;

  /// e1RM / weight / volume.
  final double value;

  /// Previous best, null if first time.
  final double? previous;

  /// The set that set it (for volume: the top set).
  final WorkoutSet set;

  const PersonalRecord({
    required this.exerciseId,
    required this.type,
    required this.value,
    required this.previous,
    required this.set,
  });

  @override
  String toString() =>
      'PersonalRecord($exerciseId, $type, $value, previous: $previous)';
}

/// Best e1RM per session over a time window.
class ExerciseTrend {
  final String exerciseId;

  /// Best e1RM per session, oldest first, within window.
  final List<MapEntry<DateTime, double>> points;

  /// First→last point in window, null if < 2 points.
  final double? changePercent;
  final bool plateau;

  const ExerciseTrend({
    required this.exerciseId,
    required this.points,
    required this.changePercent,
    required this.plateau,
  });
}

/// Weekly summary for the coach check-in card.
class WeeklyCheckIn {
  /// Monday 00:00 local of `now`'s week.
  final DateTime weekStart;

  /// Workouts with >= 1 completed set this week.
  final int workoutsThisWeek;
  final int setsThisWeek;
  final double volumeThisWeek;

  /// Null if no sets last week.
  final double? volumeLastWeek;

  /// This week, normalised group names.
  final Map<String, int> setsPerMuscleGroup;

  /// Trained in last 30 days but not in last 7.
  final List<String> neglectedMuscleGroups;
  final List<PersonalRecord> recordsThisWeek;

  /// Consecutive weeks (ending this or last week) with >= 1 workout.
  final int streakWeeks;
  final List<ExerciseTrend> plateaus;

  const WeeklyCheckIn({
    required this.weekStart,
    required this.workoutsThisWeek,
    required this.setsThisWeek,
    required this.volumeThisWeek,
    required this.volumeLastWeek,
    required this.setsPerMuscleGroup,
    required this.neglectedMuscleGroups,
    required this.recordsThisWeek,
    required this.streakWeeks,
    required this.plateaus,
  });
}

/// One generated warm-up set.
class WarmupSpec {
  final double weight;
  final int reps;

  const WarmupSpec(this.weight, this.reps);

  @override
  bool operator ==(Object other) =>
      other is WarmupSpec && other.weight == weight && other.reps == reps;

  @override
  int get hashCode => Object.hash(weight, reps);

  @override
  String toString() => 'WarmupSpec($weight × $reps)';
}

/// A completed set paired with its resolved date and owning workout.
class _DatedSet {
  final WorkoutSet set;
  final DateTime date;
  final String workoutId;

  const _DatedSet(this.set, this.date, this.workoutId);
}

/// Pure-Dart double-progression coach. No I/O, no randomness.
class ProgressionCoach {
  ProgressionCoach({required bool useMetric}) : _useMetric = useMetric;

  final bool _useMetric;

  bool get useMetric => _useMetric;

  /// 2.5 kg or 5 lb.
  double get weightStep => _useMetric ? 2.5 : 5.0;

  /// 'kg' or 'lb'.
  String get unit => _useMetric ? 'kg' : 'lb';

  /// Epley: reps <= 0 → 0; reps == 1 → weight; else weight * (1 + reps / 30).
  static double estimate1RM(double weight, int reps) {
    if (reps <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  /// Formats a number without a trailing ".0" (e.g. 100 → "100",
  /// 102.5 → "102.5", 1.25 → "1.25").
  static String formatNumber(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }

  /// Weight with unit, e.g. "102.5 kg".
  String formatWeight(double weight) => '${formatNumber(weight)} $unit';

  /// Rounds to the nearest [weightStep]; never negative.
  double roundToStep(double weight) {
    final rounded = (weight / weightStep).round() * weightStep;
    return rounded < 0 ? 0 : rounded;
  }

  /// Date used for a set: set.completedAt ?? workout.completedDate ??
  /// workout.scheduledDate.
  static DateTime? setDate(WorkoutSet set, Workout workout) =>
      set.completedAt ?? workout.completedDate ?? workout.scheduledDate;

  /// Normalised muscle-group names for an exercise (same labels as the
  /// exercise library filters).
  static List<String> muscleGroupsOf(Exercise exercise) =>
      ExerciseMetadata.resolveBodyParts(exercise);

  /// A completed working set with reps. Warm-up sets never count towards
  /// history, targets, records, trends or weekly volume.
  static bool isCountable(WorkoutSet set) =>
      set.isCompleted && set.reps > 0 && !set.isWarmup;

  static bool _isCountable(WorkoutSet set) => isCountable(set);

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  /// Newest first. A set's date = set.completedAt ?? workout.completedDate ??
  /// workout.scheduledDate; sets with no date are skipped. A session's date is
  /// the earliest date among its sets.
  List<SessionSummary> history(
    String exerciseId,
    List<Workout> workouts, {
    String? excludeWorkoutId,
  }) {
    final sessions = <SessionSummary>[];
    for (final workout in workouts) {
      if (excludeWorkoutId != null && workout.id == excludeWorkoutId) continue;
      final summary = _summarise(workout, exerciseId);
      if (summary != null) sessions.add(summary);
    }
    sessions.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.workoutId.compareTo(a.workoutId);
    });
    return sessions;
  }

  SessionSummary? lastSession(
    String exerciseId,
    List<Workout> workouts, {
    String? excludeWorkoutId,
  }) {
    final sessions =
        history(exerciseId, workouts, excludeWorkoutId: excludeWorkoutId);
    return sessions.isEmpty ? null : sessions.first;
  }

  SessionSummary? _summarise(Workout workout, String exerciseId) {
    final sets = <WorkoutSet>[];
    DateTime? earliest;
    for (final set in workout.sets) {
      if (set.exerciseId != exerciseId || !_isCountable(set)) continue;
      final date = setDate(set, workout);
      if (date == null) continue;
      sets.add(set);
      if (earliest == null || date.isBefore(earliest)) earliest = date;
    }
    if (sets.isEmpty || earliest == null) return null;
    return _buildSummary(workout.id, earliest, sets);
  }

  static SessionSummary _buildSummary(
      String workoutId, DateTime date, List<WorkoutSet> sets) {
    var top = sets.first;
    var best = estimate1RM(top.weight, top.reps);
    var volume = 0.0;
    for (final set in sets) {
      final e1rm = estimate1RM(set.weight, set.reps);
      if (e1rm > best || (e1rm == best && set.weight > top.weight)) {
        best = e1rm;
        top = set;
      }
      volume += set.weight * set.reps;
    }
    return SessionSummary(
      workoutId: workoutId,
      date: date,
      sets: List.unmodifiable(sets),
      topSet: top,
      bestE1rm: best,
      volume: volume,
    );
  }

  // ---------------------------------------------------------------------------
  // Targets
  // ---------------------------------------------------------------------------

  /// Null when there is no history for the exercise.
  ProgressionTarget? target(
    String exerciseId,
    List<Workout> workouts, {
    String? excludeWorkoutId,
  }) {
    final sessions =
        history(exerciseId, workouts, excludeWorkoutId: excludeWorkoutId);
    if (sessions.isEmpty) return null;

    final last = sessions.first;
    final w = last.topSet.weight;
    final working = last.sets.where((s) => s.weight == w).toList();
    final goal = working.first.reps;

    // Bodyweight: add a rep.
    if (w <= 0) {
      final maxReps =
          last.sets.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
      final reps = maxReps + 1;
      return ProgressionTarget(
        weight: 0,
        reps: reps,
        reason: TargetReason.increaseReps,
        weightDelta: 0,
        repsDelta: reps - goal,
        message: 'Best set last time was $maxReps reps — go for $reps.',
      );
    }

    final stalled = _shouldDeload(sessions);
    final grinding = !stalled && _shouldDeloadForEffort(sessions);
    if (stalled || grinding) {
      var deloadWeight = roundToStep(w * 0.9);
      if (deloadWeight >= w) deloadWeight = roundToStep(w - weightStep);
      final lighter = 'take a lighter week at '
          '${formatWeight(deloadWeight)} × $goal, then build back up.';
      return ProgressionTarget(
        weight: deloadWeight,
        reps: goal,
        reason: TargetReason.deload,
        weightDelta: deloadWeight - w,
        repsDelta: 0,
        message: stalled
            ? 'Stalled for 3 sessions — $lighter'
            : 'Two all-out sessions in a row (RPE 9.5+) without progress — '
                '$lighter',
      );
    }

    if (_hitAllWorkingSets(last)) {
      final rpes = working.map((s) => s.rpe).toList();
      final rated = rpes.whereType<double>().toList();
      final hardest =
          rated.isEmpty ? null : rated.reduce((a, b) => a > b ? a : b);

      // A grinder: reps were hit but only just. Own the weight first.
      if (hardest != null && hardest >= 9.5) {
        final repeatWeight = roundToStep(w);
        return ProgressionTarget(
          weight: repeatWeight,
          reps: goal,
          reason: TargetReason.repeat,
          weightDelta: repeatWeight - w,
          repsDelta: 0,
          message: 'Last time was a grinder (RPE ${formatNumber(hardest)}) — '
              'repeat the weight and own it.',
        );
      }

      // Every working set rated RPE 7 or easier: take a double step.
      final easy =
          rated.length == rpes.length && hardest != null && hardest <= 7;
      final steps = easy ? 2 : 1;
      var next = roundToStep(w + steps * weightStep);
      if (next <= w) next = roundToStep(w + (steps + 1) * weightStep);
      final delta = next - w;
      return ProgressionTarget(
        weight: next,
        reps: goal,
        reason: TargetReason.increaseWeight,
        weightDelta: delta,
        repsDelta: 0,
        message: easy
            ? 'Hit $goal reps on every set at RPE ${formatNumber(hardest)} '
                'or easier — that was light, add ${formatWeight(delta)}.'
            : 'Hit $goal reps on every set last time — '
                'add ${formatWeight(delta)}.',
      );
    }

    final repeatWeight = roundToStep(w);
    return ProgressionTarget(
      weight: repeatWeight,
      reps: goal,
      reason: TargetReason.repeat,
      weightDelta: repeatWeight - w,
      repsDelta: 0,
      message: 'Stay at ${formatWeight(repeatWeight)} and aim for '
          '$goal reps on every set.',
    );
  }

  /// True when every working set (sets at the top-set weight) reached the
  /// goal reps (reps of the first working set).
  static bool _hitAllWorkingSets(SessionSummary session) {
    final w = session.topSet.weight;
    final working = session.sets.where((s) => s.weight == w).toList();
    final goal = working.first.reps;
    return working.every((s) => s.reps >= goal);
  }

  /// Last 3 sessions all "repeat" (missed reps) at the same or higher weight
  /// over time, and none improved best e1RM by > 1% over the session before.
  bool _shouldDeload(List<SessionSummary> newestFirst) {
    if (newestFirst.length < 3) return false;
    final recent = newestFirst.take(3).toList();
    for (var i = 0; i < recent.length; i++) {
      final session = recent[i];
      if (session.topSet.weight <= 0) return false;
      if (_hitAllWorkingSets(session)) return false;
      if (i + 1 < recent.length &&
          session.topSet.weight < recent[i + 1].topSet.weight) {
        return false;
      }
      if (i + 1 < newestFirst.length) {
        final before = newestFirst[i + 1];
        if (session.bestE1rm > before.bestE1rm * 1.01) return false;
      }
    }
    return true;
  }

  /// Average RPE of the rated sets in [sets], or null when none is rated.
  static double? averageRpe(Iterable<WorkoutSet> sets) {
    final rated = sets.map((s) => s.rpe).whereType<double>().toList();
    if (rated.isEmpty) return null;
    return rated.reduce((a, b) => a + b) / rated.length;
  }

  /// The last 2 sessions both averaged RPE >= 9.5 (over their rated sets) and
  /// the newest did not improve best e1RM by > 1% over the one before.
  bool _shouldDeloadForEffort(List<SessionSummary> newestFirst) {
    if (newestFirst.length < 2) return false;
    final newest = newestFirst[0];
    final previous = newestFirst[1];
    if (newest.topSet.weight <= 0) return false;
    for (final session in [newest, previous]) {
      final avg = averageRpe(session.sets);
      if (avg == null || avg < 9.5) return false;
    }
    return newest.bestE1rm <= previous.bestE1rm * 1.01;
  }

  // ---------------------------------------------------------------------------
  // Trends
  // ---------------------------------------------------------------------------

  ExerciseTrend trend(
    String exerciseId,
    List<Workout> workouts, {
    int weeks = 8,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final cutoff = reference.subtract(Duration(days: weeks * 7));
    final sessions = history(exerciseId, workouts)
        .where((s) => !s.date.isBefore(cutoff) && !s.date.isAfter(reference))
        .toList()
        .reversed
        .toList();
    final points = sessions.map((s) => MapEntry(s.date, s.bestE1rm)).toList();

    double? change;
    if (points.length >= 2 && points.first.value > 0) {
      change =
          (points.last.value - points.first.value) / points.first.value * 100;
    }

    var plateau = false;
    if (points.length >= 4) {
      final earlier = points.sublist(0, points.length - 3);
      final recent = points.sublist(points.length - 3);
      final earlierBest =
          earlier.map((p) => p.value).reduce((a, b) => a > b ? a : b);
      final recentBest =
          recent.map((p) => p.value).reduce((a, b) => a > b ? a : b);
      plateau = earlierBest > 0 && recentBest <= earlierBest * 1.01;
    }

    return ExerciseTrend(
      exerciseId: exerciseId,
      points: List.unmodifiable(points),
      changePercent: change,
      plateau: plateau,
    );
  }

  // ---------------------------------------------------------------------------
  // Records
  // ---------------------------------------------------------------------------

  /// Records set in `workout` compared with all sets dated before it in
  /// `allWorkouts` (excluding `workout` itself). The workout's reference date
  /// is the earliest date of its completed sets, falling back to
  /// completedDate ?? scheduledDate; with no date at all, every other workout
  /// counts as "before". First-time records have `previous == null`.
  List<PersonalRecord> recordsIn(Workout workout, List<Workout> allWorkouts) {
    final records = <PersonalRecord>[];

    final exerciseOrder = <String>[];
    for (final set in workout.sets) {
      if (_isCountable(set) && !exerciseOrder.contains(set.exerciseId)) {
        exerciseOrder.add(set.exerciseId);
      }
    }
    if (exerciseOrder.isEmpty) return records;

    DateTime? refDate;
    for (final set in workout.sets) {
      if (!_isCountable(set)) continue;
      final date = setDate(set, workout);
      if (date != null && (refDate == null || date.isBefore(refDate))) {
        refDate = date;
      }
    }
    refDate ??= workout.completedDate ?? workout.scheduledDate;

    final others = allWorkouts.where((w) => w.id != workout.id).toList();

    for (final exerciseId in exerciseOrder) {
      final current = workout.sets
          .where((s) => s.exerciseId == exerciseId && _isCountable(s))
          .toList();

      // Previous sets & sessions strictly before the reference date.
      final previousSets = <WorkoutSet>[];
      double? prevVolume;
      for (final other in others) {
        final sessionSets = <WorkoutSet>[];
        DateTime? sessionDate;
        for (final set in other.sets) {
          if (set.exerciseId != exerciseId || !_isCountable(set)) continue;
          final date = setDate(set, other);
          if (date == null) continue;
          if (refDate != null && !date.isBefore(refDate)) continue;
          previousSets.add(set);
          sessionSets.add(set);
          if (sessionDate == null || date.isBefore(sessionDate)) {
            sessionDate = date;
          }
        }
        if (sessionSets.isNotEmpty) {
          final v =
              sessionSets.fold<double>(0, (a, s) => a + s.weight * s.reps);
          if (prevVolume == null || v > prevVolume) prevVolume = v;
        }
      }
      final hasHistory = previousSets.isNotEmpty;

      final summary =
          _buildSummary(workout.id, refDate ?? DateTime(0), current);

      // Best e1RM.
      double? prevE1rm;
      double? prevHeaviest;
      for (final set in previousSets) {
        final e = estimate1RM(set.weight, set.reps);
        if (prevE1rm == null || e > prevE1rm) prevE1rm = e;
        if (prevHeaviest == null || set.weight > prevHeaviest) {
          prevHeaviest = set.weight;
        }
      }

      if (summary.bestE1rm > 0 &&
          (!hasHistory || summary.bestE1rm > prevE1rm!)) {
        records.add(PersonalRecord(
          exerciseId: exerciseId,
          type: RecordType.bestE1rm,
          value: summary.bestE1rm,
          previous: hasHistory ? prevE1rm : null,
          set: summary.topSet,
        ));
      }

      // Heaviest weight (ties broken by more reps).
      var heaviest = current.first;
      for (final set in current) {
        if (set.weight > heaviest.weight ||
            (set.weight == heaviest.weight && set.reps > heaviest.reps)) {
          heaviest = set;
        }
      }
      if (heaviest.weight > 0 &&
          (!hasHistory || heaviest.weight > prevHeaviest!)) {
        records.add(PersonalRecord(
          exerciseId: exerciseId,
          type: RecordType.heaviestWeight,
          value: heaviest.weight,
          previous: hasHistory ? prevHeaviest : null,
          set: heaviest,
        ));
      }

      // Most volume in a single session.
      if (summary.volume > 0 && (!hasHistory || summary.volume > prevVolume!)) {
        records.add(PersonalRecord(
          exerciseId: exerciseId,
          type: RecordType.mostVolume,
          value: summary.volume,
          previous: hasHistory ? prevVolume : null,
          set: summary.topSet,
        ));
      }
    }
    return records;
  }

  /// Short, friendly description of a record, e.g.
  /// "New heaviest weight: 105 kg (was 100 kg)."
  String describeRecord(PersonalRecord record) {
    final value = formatWeight(record.value);
    final was = record.previous == null
        ? ''
        : ' (was ${formatWeight(record.previous!)})';
    switch (record.type) {
      case RecordType.bestE1rm:
        return 'New best estimated 1RM: $value$was.';
      case RecordType.heaviestWeight:
        return 'New heaviest weight: $value$was.';
      case RecordType.mostVolume:
        return 'Most volume in a session: $value$was.';
    }
  }

  // ---------------------------------------------------------------------------
  // Weekly check-in
  // ---------------------------------------------------------------------------

  /// Monday 00:00 local of the week containing [date].
  static DateTime startOfWeek(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  List<_DatedSet> _datedSets(List<Workout> workouts) {
    final result = <_DatedSet>[];
    for (final workout in workouts) {
      for (final set in workout.sets) {
        if (!_isCountable(set)) continue;
        final date = setDate(set, workout);
        if (date == null) continue;
        result.add(_DatedSet(set, date, workout.id));
      }
    }
    return result;
  }

  WeeklyCheckIn weeklyCheckIn(
    List<Workout> workouts,
    Map<String, Exercise> exercisesById, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final weekStart = startOfWeek(reference);
    final nextWeekStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final lastWeekStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day - 7);

    bool inRange(DateTime d, DateTime start, DateTime end) =>
        !d.isBefore(start) && d.isBefore(end);

    final dated = _datedSets(workouts);

    var setsThisWeek = 0;
    var volumeThisWeek = 0.0;
    var setsLastWeek = 0;
    var volumeLastWeek = 0.0;
    final workoutIdsThisWeek = <String>{};
    final perGroup = <String, int>{};

    for (final d in dated) {
      if (inRange(d.date, weekStart, nextWeekStart)) {
        setsThisWeek++;
        volumeThisWeek += d.set.weight * d.set.reps;
        workoutIdsThisWeek.add(d.workoutId);
        final exercise = exercisesById[d.set.exerciseId];
        if (exercise != null) {
          for (final group in muscleGroupsOf(exercise)) {
            perGroup[group] = (perGroup[group] ?? 0) + 1;
          }
        }
      } else if (inRange(d.date, lastWeekStart, weekStart)) {
        setsLastWeek++;
        volumeLastWeek += d.set.weight * d.set.reps;
      }
    }

    // Neglected groups: trained in last 30 days but not in last 7.
    final last7 = reference.subtract(const Duration(days: 7));
    final last30 = reference.subtract(const Duration(days: 30));
    final recentGroups = <String>{};
    final monthGroups = <String>{};
    for (final d in dated) {
      if (d.date.isAfter(reference) || d.date.isBefore(last30)) continue;
      final exercise = exercisesById[d.set.exerciseId];
      if (exercise == null) continue;
      final groups = muscleGroupsOf(exercise);
      monthGroups.addAll(groups);
      if (!d.date.isBefore(last7)) recentGroups.addAll(groups);
    }
    final neglected = monthGroups.difference(recentGroups).toList()..sort();

    // Records this week.
    final weekWorkouts =
        workouts.where((w) => workoutIdsThisWeek.contains(w.id)).toList()
          ..sort((a, b) {
            final da = _earliestDate(a) ?? weekStart;
            final db = _earliestDate(b) ?? weekStart;
            final c = da.compareTo(db);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
    final records = <PersonalRecord>[];
    for (final workout in weekWorkouts) {
      final dateBySetId = {
        for (final s in workout.sets) s.id: setDate(s, workout),
      };
      for (final record in recordsIn(workout, workouts)) {
        final date = dateBySetId[record.set.id];
        if (date != null && inRange(date, weekStart, nextWeekStart)) {
          records.add(record);
        }
      }
    }

    // Streak of consecutive weeks with >= 1 workout.
    final activeWeeks = <DateTime>{
      for (final d in dated)
        if (!d.date.isAfter(reference)) startOfWeek(d.date),
    };
    var streak = 0;
    var cursor = activeWeeks.contains(weekStart) ? weekStart : lastWeekStart;
    while (activeWeeks.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    }

    // Plateaus among exercises trained within the trend window.
    final trendCutoff = reference.subtract(const Duration(days: 8 * 7));
    final exerciseIds = <String>{
      for (final d in dated)
        if (!d.date.isBefore(trendCutoff) && !d.date.isAfter(reference))
          d.set.exerciseId,
    }.toList()
      ..sort();
    final plateaus = <ExerciseTrend>[];
    for (final id in exerciseIds) {
      final t = trend(id, workouts, now: reference);
      if (t.plateau) plateaus.add(t);
    }

    return WeeklyCheckIn(
      weekStart: weekStart,
      workoutsThisWeek: workoutIdsThisWeek.length,
      setsThisWeek: setsThisWeek,
      volumeThisWeek: volumeThisWeek,
      volumeLastWeek: setsLastWeek == 0 ? null : volumeLastWeek,
      setsPerMuscleGroup: perGroup,
      neglectedMuscleGroups: neglected,
      recordsThisWeek: records,
      streakWeeks: streak,
      plateaus: plateaus,
    );
  }

  static DateTime? _earliestDate(Workout workout) {
    DateTime? earliest;
    for (final set in workout.sets) {
      if (!_isCountable(set)) continue;
      final date = setDate(set, workout);
      if (date != null && (earliest == null || date.isBefore(earliest))) {
        earliest = date;
      }
    }
    return earliest;
  }

  // ---------------------------------------------------------------------------
  // Warm-ups
  // ---------------------------------------------------------------------------

  /// Warm-up ramp percentages and reps before a working set.
  static const List<(double, int)> warmupRamp = [(0.5, 8), (0.7, 5), (0.85, 2)];

  /// Warm-up sets before a working set of [workingWeight]: ~50% × 8,
  /// 70% × 5, 85% × 2, rounded to the nearest 2.5 kg / 5 lb. A warm-up is
  /// skipped when it would be at or below the empty bar ([barWeight], default
  /// 20 kg / 45 lb), at or above the working weight, or not heavier than the
  /// previous warm-up. Lightest first.
  List<WarmupSpec> warmupSets(double workingWeight, {double? barWeight}) {
    final bar = barWeight ?? (_useMetric ? 20.0 : 45.0);
    final result = <WarmupSpec>[];
    for (final (percent, reps) in warmupRamp) {
      final weight = roundToStep(workingWeight * percent);
      if (weight <= bar || weight >= workingWeight) continue;
      if (result.isNotEmpty && weight <= result.last.weight) continue;
      result.add(WarmupSpec(weight, reps));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Next workout
  // ---------------------------------------------------------------------------

  /// Unsaved Workout (Workout.create) named 'Next Workout', scheduled today,
  /// with uncompleted sets at target weights.
  ///
  /// 1. Exercises with history whose muscle groups weren't trained in the
  ///    last 48 h, most overdue first (3 sets at the coach target).
  /// 2. Then untrained library exercises for the least-trained muscle groups
  ///    over the last 7 days (3 × 8 at weight 0).
  /// 3. If nothing qualified at all, the most overdue exercises with history
  ///    are used regardless of recovery so the workout is never empty.
  /// Ties are broken by exercise name then id — no randomness.
  Workout suggestNextWorkout(
    List<Workout> workouts,
    List<Exercise> exercises, {
    DateTime? now,
    int exerciseCount = 5,
  }) {
    final reference = now ?? DateTime.now();
    final recoveryCutoff = reference.subtract(const Duration(hours: 48));
    final weekCutoff = reference.subtract(const Duration(days: 7));
    final byId = {for (final e in exercises) e.id: e};

    final dated =
        _datedSets(workouts).where((d) => !d.date.isAfter(reference)).toList();

    final lastTrained = <String, DateTime>{};
    final recentGroups = <String>{};
    final recentExerciseIds = <String>{};
    final groupSetsThisWeek = <String, int>{};
    for (final d in dated) {
      final id = d.set.exerciseId;
      final prev = lastTrained[id];
      if (prev == null || d.date.isAfter(prev)) lastTrained[id] = d.date;
      final exercise = byId[id];
      final groups =
          exercise == null ? const <String>[] : muscleGroupsOf(exercise);
      if (d.date.isAfter(recoveryCutoff)) {
        recentExerciseIds.add(id);
        recentGroups.addAll(groups);
      }
      if (!d.date.isBefore(weekCutoff)) {
        for (final g in groups) {
          groupSetsThisWeek[g] = (groupSetsThisWeek[g] ?? 0) + 1;
        }
      }
    }

    int byName(Exercise a, Exercise b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return c != 0 ? c : a.id.compareTo(b.id);
    }

    bool recovered(Exercise e) {
      if (recentExerciseIds.contains(e.id)) return false;
      return !muscleGroupsOf(e).any(recentGroups.contains);
    }

    final withHistory =
        exercises.where((e) => lastTrained.containsKey(e.id)).toList()
          ..sort((a, b) {
            final c = lastTrained[a.id]!.compareTo(lastTrained[b.id]!);
            return c != 0 ? c : byName(a, b);
          });

    final selected = <Exercise>[];
    for (final e in withHistory) {
      if (selected.length >= exerciseCount) break;
      if (recovered(e)) selected.add(e);
    }

    final fillers = <Exercise>[];
    if (selected.length < exerciseCount) {
      int load(Exercise e) {
        final groups = muscleGroupsOf(e);
        if (groups.isEmpty) return 1 << 30;
        return groups
            .map((g) => groupSetsThisWeek[g] ?? 0)
            .reduce((a, b) => a < b ? a : b);
      }

      final candidates = exercises
          .where((e) => !lastTrained.containsKey(e.id) && recovered(e))
          .toList()
        ..sort((a, b) {
          final c = load(a).compareTo(load(b));
          return c != 0 ? c : byName(a, b);
        });
      for (final e in candidates) {
        if (selected.length + fillers.length >= exerciseCount) break;
        fillers.add(e);
      }
    }

    if (selected.isEmpty && fillers.isEmpty) {
      selected.addAll(withHistory.take(exerciseCount));
    }

    final sets = <WorkoutSet>[];
    for (final e in selected) {
      final t = target(e.id, workouts);
      double weight;
      int reps;
      if (t != null) {
        weight = t.weight;
        reps = t.reps;
      } else {
        final last = lastSession(e.id, workouts);
        weight = last?.topSet.weight ?? 0;
        reps = last?.topSet.reps ?? 8;
      }
      for (var i = 0; i < 3; i++) {
        sets.add(
            WorkoutSet.create(exerciseId: e.id, reps: reps, weight: weight));
      }
    }
    for (final e in fillers) {
      for (var i = 0; i < 3; i++) {
        sets.add(WorkoutSet.create(exerciseId: e.id, reps: 8, weight: 0));
      }
    }

    final notes = StringBuffer();
    if (recentGroups.isEmpty) {
      notes.write('Fully recovered — picked your most overdue lifts.');
    } else {
      final groups = recentGroups.toList()..sort();
      notes.write('Resting ${groups.join(', ')} (trained in the last 48 h).');
    }
    if (fillers.isNotEmpty) {
      notes.write(' Added new exercises for under-trained muscles.');
    }

    return Workout.create(
      name: 'Next Workout',
      scheduledDate: DateTime(reference.year, reference.month, reference.day),
      sets: sets,
      notes: notes.toString(),
    );
  }
}
