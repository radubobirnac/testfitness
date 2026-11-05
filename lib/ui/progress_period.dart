import 'package:intl/intl.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/services/progression_coach.dart';

/// Range picked with the period selector on the Progress tab.
enum ProgressPeriod {
  fourWeeks('4W', 'last 4 weeks'),
  threeMonths('3M', 'last 3 months'),
  oneYear('1Y', 'last 12 months'),
  all('All', 'all time');

  const ProgressPeriod(this.label, this.description);

  /// Short segment label ("4W").
  final String label;

  /// Lower-case phrase for captions ("last 4 weeks").
  final String description;
}

/// One chart bucket: [start] inclusive, [end] exclusive.
class PeriodBucket {
  const PeriodBucket(this.start, this.end, this.label);

  final DateTime start;
  final DateTime end;
  final String label;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

/// The window a [ProgressPeriod] covers, split into chart buckets.
class PeriodWindow {
  const PeriodWindow({
    required this.period,
    required this.buckets,
    required this.unit,
    this.previousStart,
  });

  final ProgressPeriod period;
  final List<PeriodBucket> buckets;

  /// "week", "month" or "year": what one bucket is.
  final String unit;

  /// Start of the equally long window before this one; null for "All".
  final DateTime? previousStart;

  bool get isEmpty => buckets.isEmpty;
  DateTime get start => buckets.first.start;
  DateTime get end => buckets.last.end;

  bool contains(DateTime d) => !isEmpty && !d.isBefore(start) && d.isBefore(end);
}

/// Counts for a window of time. Only completed working sets count (same rule
/// as the weekly check-in: [ProgressionCoach.isCountable]).
class PeriodTotals {
  const PeriodTotals({
    required this.workouts,
    required this.sets,
    required this.volume,
  });

  final int workouts;
  final int sets;
  final double volume;

  static const zero = PeriodTotals(workouts: 0, sets: 0, volume: 0);
}

/// Volume and session count for one exercise in a window.
class ExerciseVolume {
  const ExerciseVolume(this.exerciseId, this.volume, this.sessions);

  final String exerciseId;
  final double volume;
  final int sessions;
}

/// Pure aggregation helpers for the Progress tab. Every function takes `now`
/// so tests are deterministic.
abstract final class ProgressMath {
  static DateTime _month(DateTime d) => DateTime(d.year, d.month);

  static PeriodWindow window(
    ProgressPeriod period,
    DateTime now, {
    DateTime? earliest,
  }) {
    final week = ProgressionCoach.startOfWeek(now);
    final weekFmt = DateFormat('MMM d');
    List<PeriodBucket> weeks(int count) => [
          for (var i = count - 1; i >= 0; i--)
            () {
              final s = DateTime(week.year, week.month, week.day - 7 * i);
              final e = DateTime(s.year, s.month, s.day + 7);
              return PeriodBucket(s, e, weekFmt.format(s));
            }(),
        ];
    List<PeriodBucket> months(DateTime from, String pattern) {
      final fmt = DateFormat(pattern);
      final result = <PeriodBucket>[];
      var s = _month(from);
      final last = _month(now);
      while (!s.isAfter(last)) {
        final e = DateTime(s.year, s.month + 1);
        result.add(PeriodBucket(s, e, fmt.format(s)));
        s = e;
      }
      return result;
    }

    switch (period) {
      case ProgressPeriod.fourWeeks:
        final b = weeks(4);
        return PeriodWindow(
          period: period,
          buckets: b,
          unit: 'week',
          previousStart: DateTime(
              b.first.start.year, b.first.start.month, b.first.start.day - 28),
        );
      case ProgressPeriod.threeMonths:
        final b = weeks(13);
        return PeriodWindow(
          period: period,
          buckets: b,
          unit: 'week',
          previousStart: DateTime(b.first.start.year, b.first.start.month,
              b.first.start.day - 91),
        );
      case ProgressPeriod.oneYear:
        final from = DateTime(now.year, now.month - 11);
        return PeriodWindow(
          period: period,
          buckets: months(from, 'MMM'),
          unit: 'month',
          previousStart: DateTime(from.year - 1, from.month),
        );
      case ProgressPeriod.all:
        if (earliest == null || earliest.isAfter(now)) {
          return PeriodWindow(period: period, buckets: const [], unit: 'month');
        }
        final monthCount = (now.year - earliest.year) * 12 +
            now.month -
            earliest.month +
            1;
        if (monthCount <= 24) {
          return PeriodWindow(
            period: period,
            buckets: months(earliest, "MMM ''yy"),
            unit: 'month',
          );
        }
        return PeriodWindow(
          period: period,
          buckets: [
            for (var y = earliest.year; y <= now.year; y++)
              PeriodBucket(DateTime(y), DateTime(y + 1), '$y'),
          ],
          unit: 'year',
        );
    }
  }

  /// Visits every countable set that has a date.
  static void _forEachSet(
    List<Workout> workouts,
    void Function(Workout w, double volume, String exerciseId, DateTime d) f,
  ) {
    for (final w in workouts) {
      for (final s in w.sets) {
        if (!ProgressionCoach.isCountable(s)) continue;
        final d = ProgressionCoach.setDate(s, w);
        if (d == null) continue;
        f(w, s.weight * s.reps, s.exerciseId, d);
      }
    }
  }

  /// Earliest date of any countable set.
  static DateTime? earliestDate(List<Workout> workouts) {
    DateTime? best;
    _forEachSet(workouts, (_, __, ___, d) {
      if (best == null || d.isBefore(best!)) best = d;
    });
    return best;
  }

  static PeriodTotals totals(
      List<Workout> workouts, DateTime start, DateTime end) {
    var sets = 0;
    var volume = 0.0;
    final ids = <String>{};
    _forEachSet(workouts, (w, v, _, d) {
      if (d.isBefore(start) || !d.isBefore(end)) return;
      sets++;
      volume += v;
      ids.add(w.id);
    });
    return PeriodTotals(workouts: ids.length, sets: sets, volume: volume);
  }

  /// Volume per bucket (same order as [PeriodWindow.buckets]).
  static List<double> volumePerBucket(
      List<Workout> workouts, PeriodWindow window) {
    final result = List<double>.filled(window.buckets.length, 0);
    _forEachSet(workouts, (_, v, __, d) {
      final i = window.buckets.indexWhere((b) => b.contains(d));
      if (i >= 0) result[i] += v;
    });
    return result;
  }

  /// Distinct workouts per bucket (a workout counts in the bucket of its
  /// first countable set).
  static List<int> workoutsPerBucket(
      List<Workout> workouts, PeriodWindow window) {
    final firstDate = <String, DateTime>{};
    _forEachSet(workouts, (w, _, __, d) {
      final current = firstDate[w.id];
      if (current == null || d.isBefore(current)) firstDate[w.id] = d;
    });
    final result = List<int>.filled(window.buckets.length, 0);
    for (final d in firstDate.values) {
      final i = window.buckets.indexWhere((b) => b.contains(d));
      if (i >= 0) result[i]++;
    }
    return result;
  }

  /// Sets per normalised muscle group in the window, largest first. Sets for
  /// exercises missing from [exercisesById] are skipped.
  static List<MapEntry<String, int>> setsPerMuscleGroup(
    List<Workout> workouts,
    Map<String, Exercise> exercisesById,
    PeriodWindow window,
  ) {
    final counts = <String, int>{};
    _forEachSet(workouts, (_, __, id, d) {
      if (!window.contains(d)) return;
      final exercise = exercisesById[id];
      if (exercise == null) return;
      for (final g in ProgressionCoach.muscleGroupsOf(exercise)) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    });
    return counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
  }

  /// Exercises by volume in the window, largest first.
  static List<ExerciseVolume> topExercises(
    List<Workout> workouts,
    PeriodWindow window, {
    int limit = 5,
  }) {
    final volume = <String, double>{};
    final sessions = <String, Set<String>>{};
    _forEachSet(workouts, (w, v, id, d) {
      if (!window.contains(d)) return;
      volume[id] = (volume[id] ?? 0) + v;
      sessions.putIfAbsent(id, () => <String>{}).add(w.id);
    });
    final list = [
      for (final e in volume.entries)
        ExerciseVolume(e.key, e.value, sessions[e.key]!.length),
    ]..sort((a, b) {
        final c = b.volume.compareTo(a.volume);
        return c != 0 ? c : b.sessions.compareTo(a.sessions);
      });
    return list.take(limit).toList();
  }

  /// "12,400" below 100k, "1.2M"/"240K" above.
  static String formatVolume(double v) {
    if (v >= 100000) return NumberFormat.compact().format(v);
    return NumberFormat.decimalPattern().format(v.round());
  }

  /// Compact axis label: "950", "12K", "1.2M".
  static String formatAxis(double v) {
    if (v >= 1000) return NumberFormat.compact().format(v);
    return v.round().toString();
  }

  /// Percentage change, or null when [previous] is missing or zero.
  static double? changePercent(double current, double? previous) {
    if (previous == null || previous <= 0) return null;
    return (current - previous) / previous * 100;
  }

  /// "↑ 12%" / "↓ 3%" — arrow plus number so the sign never relies on colour.
  static String formatChange(double pct) =>
      '${pct >= 0 ? '↑' : '↓'} ${pct.abs().toStringAsFixed(0)}%';
}
