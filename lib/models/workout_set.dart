import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:testfitness/utils/error_handler.dart';

/// Represents a single set of an exercise in a workout
class WorkoutSet extends Equatable {
  final String id;
  final String exerciseId;
  final int reps;
  final double weight;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? restTimeSeconds;
  final String? notes;

  /// Warm-up sets are logged but ignored by the progression coach, records,
  /// summary totals and "last time" hints.
  final bool isWarmup;

  /// Effort rating (RPE 1–10 in half steps; 10 = max effort, 8 = two reps
  /// left in the tank). Null = not rated.
  final double? rpe;

  /// Superset id shared by every set of the exercises performed back to back
  /// as one superset. Null = not in a superset.
  final String? supersetGroup;

  const WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.reps,
    required this.weight,
    this.isCompleted = false,
    this.completedAt,
    this.restTimeSeconds,
    this.notes,
    this.isWarmup = false,
    this.rpe,
    this.supersetGroup,
  });

  /// Create a new workout set with a generated ID
  factory WorkoutSet.create({
    required String exerciseId,
    required int reps,
    required double weight,
    bool isCompleted = false,
    DateTime? completedAt,
    int? restTimeSeconds,
    String? notes,
    bool isWarmup = false,
    double? rpe,
    String? supersetGroup,
  }) {
    return WorkoutSet(
      id: const Uuid().v4(),
      exerciseId: exerciseId,
      reps: reps,
      weight: weight,
      isCompleted: isCompleted,
      completedAt: completedAt,
      restTimeSeconds: restTimeSeconds,
      notes: notes,
      isWarmup: isWarmup,
      rpe: parseRpe(rpe),
      supersetGroup: parseSupersetGroup(supersetGroup),
    );
  }

  /// Create a copy of this workout set with modified properties
  WorkoutSet copyWith({
    String? exerciseId,
    int? reps,
    double? weight,
    bool? isCompleted,
    DateTime? completedAt,
    int? restTimeSeconds,
    String? notes,
    bool? isWarmup,
    double? rpe,
    bool clearRpe = false,
    String? supersetGroup,
    bool clearSupersetGroup = false,
  }) {
    return WorkoutSet(
      id: id,
      exerciseId: exerciseId ?? this.exerciseId,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      restTimeSeconds: restTimeSeconds ?? this.restTimeSeconds,
      notes: notes ?? this.notes,
      isWarmup: isWarmup ?? this.isWarmup,
      rpe: clearRpe ? null : (rpe != null ? parseRpe(rpe) : this.rpe),
      supersetGroup: clearSupersetGroup
          ? null
          : (supersetGroup != null
              ? parseSupersetGroup(supersetGroup)
              : this.supersetGroup),
    );
  }

  /// Mark this set as completed
  WorkoutSet complete() {
    return copyWith(isCompleted: true, completedAt: DateTime.now());
  }

  /// Convert workout set to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'reps': reps,
      'weight': weight,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'restTimeSeconds': restTimeSeconds,
      'notes': notes,
      'isWarmup': isWarmup ? 1 : 0,
      'rpe': rpe,
      'supersetGroup': supersetGroup,
    };
  }

  /// Create a workout set from a database map
  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    try {
      // Generate a new UUID if id is missing
      final id = map['id'] ?? const Uuid().v4();

      // Ensure exerciseId is never null (use empty string as fallback)
      final exerciseId = map['exerciseId'] ?? '';

      // Default to 8 reps if missing or invalid
      final reps = map['reps'] is int ? map['reps'] : 8;

      // Default to 0.0 weight if missing or invalid
      final weight =
          map['weight'] is num ? (map['weight'] as num).toDouble() : 0.0;

      // Handle isCompleted with proper fallback
      final isCompleted = map['isCompleted'] == 1 || map['isCompleted'] == true;

      // Handle completedAt date safely
      DateTime? completedAt;
      if (map['completedAt'] != null) {
        try {
          completedAt = DateTime.fromMillisecondsSinceEpoch(map['completedAt']);
        } catch (e) {
          // If date conversion fails, leave as null
          ErrorHandler.handleParsingError(
              e, null, 'WorkoutSet.fromMap completedAt');
        }
      }

      return WorkoutSet(
        id: id,
        exerciseId: exerciseId,
        reps: reps,
        weight: weight,
        isCompleted: isCompleted,
        completedAt: completedAt,
        restTimeSeconds: map['restTimeSeconds'],
        notes: map['notes'],
        isWarmup: parseWarmupFlag(map['isWarmup'] ?? map['is_warmup']),
        rpe: parseRpe(map['rpe']),
        supersetGroup:
            parseSupersetGroup(map['supersetGroup'] ?? map['superset_group']),
      );
    } catch (e) {
      ErrorHandler.handleParsingError(e, null, 'WorkoutSet.fromMap');
      // Return a minimal valid WorkoutSet if parsing fails
      return WorkoutSet(
        id: const Uuid().v4(),
        exerciseId: '',
        reps: 8,
        weight: 0.0,
        isCompleted: false,
      );
    }
  }

  /// Tolerant parse of a stored warm-up flag: 1/0, bool, "true"/"1"/"yes";
  /// anything missing or unrecognised is false.
  static bool parseWarmupFlag(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == '1' || v == 'true' || v == 'yes' || v == 'y';
    }
    return false;
  }

  /// Tolerant parse of a stored RPE: a number (or numeric string) between 1
  /// and 10, snapped to the nearest half step. Anything else is null.
  static double? parseRpe(Object? value) {
    double? v;
    if (value is num) {
      v = value.toDouble();
    } else if (value is String) {
      v = double.tryParse(value.trim().replaceAll(',', '.'));
    }
    if (v == null || v.isNaN || v < 1 || v > 10) return null;
    return (v * 2).round() / 2;
  }

  /// Tolerant parse of a stored superset id: a non-blank string, else null.
  static String? parseSupersetGroup(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  List<Object?> get props => [
        id,
        exerciseId,
        reps,
        weight,
        isCompleted,
        completedAt,
        restTimeSeconds,
        notes,
        isWarmup,
        rpe,
        supersetGroup,
      ];
}

/// Pure helpers for supersets: exercises performed back to back, resting only
/// after the last one. A superset is a run of consecutive exercises (in
/// workout order) whose sets share one [WorkoutSet.supersetGroup] id.
///
/// `order` is the exercise ids in workout order; `groupOf` maps an exercise id
/// to its group id (missing/null = not in a superset).
class Supersets {
  Supersets._();

  static String _uuid() => const Uuid().v4();

  /// Only consecutive runs of 2+ exercises sharing an id count. A run of one
  /// is dropped, and an id reused by a later non-adjacent run gets a fresh id
  /// from [newId]. The result only holds grouped exercises.
  static Map<String, String> normalize(
    List<String> order,
    Map<String, String?> groupOf, {
    String Function()? newId,
  }) {
    final result = <String, String>{};
    final seen = <String>{};
    var i = 0;
    while (i < order.length) {
      final id = groupOf[order[i]];
      if (id == null || id.isEmpty) {
        i++;
        continue;
      }
      var j = i + 1;
      while (j < order.length && groupOf[order[j]] == id) {
        j++;
      }
      if (j - i >= 2) {
        final runId = seen.contains(id) ? (newId ?? _uuid)() : id;
        seen.add(runId);
        for (var k = i; k < j; k++) {
          result[order[k]] = runId;
        }
      }
      seen.add(id);
      i = j;
    }
    return result;
  }

  /// The superset runs (each 2+ exercise ids, in order).
  static List<List<String>> runs(
      List<String> order, Map<String, String?> groupOf) {
    final normalized = normalize(order, groupOf);
    final result = <List<String>>[];
    String? current;
    for (final id in order) {
      final group = normalized[id];
      if (group == null) {
        current = null;
        continue;
      }
      if (group != current) {
        result.add([]);
        current = group;
      }
      result.last.add(id);
    }
    return result;
  }

  /// Members of the superset containing [exerciseId], in order; empty when
  /// it is not in a superset.
  static List<String> membersOf(
    String exerciseId,
    List<String> order,
    Map<String, String?> groupOf,
  ) {
    for (final run in runs(order, groupOf)) {
      if (run.contains(exerciseId)) return run;
    }
    return const [];
  }

  /// True when completing a set of [exerciseId] should start the rest timer:
  /// it is not in a superset, or it is the superset's last exercise.
  static bool restsAfter(
    String exerciseId,
    List<String> order,
    Map<String, String?> groupOf,
  ) {
    final members = membersOf(exerciseId, order, groupOf);
    return members.isEmpty || members.last == exerciseId;
  }

  /// The exercise to do after [exerciseId] within its superset, or null
  /// when it is the last one (or not in a superset).
  static String? nextInGroup(
    String exerciseId,
    List<String> order,
    Map<String, String?> groupOf,
  ) {
    final members = membersOf(exerciseId, order, groupOf);
    final i = members.indexOf(exerciseId);
    if (i < 0 || i + 1 >= members.length) return null;
    return members[i + 1];
  }

  /// Rest after a round of [exerciseId]'s superset: the longest rest among
  /// its members (just [exerciseId]'s own rest outside a superset).
  static int restSecondsFor(
    String exerciseId,
    List<String> order,
    Map<String, String?> groupOf,
    int Function(String exerciseId) restOf,
  ) {
    final members = membersOf(exerciseId, order, groupOf);
    if (members.isEmpty) return restOf(exerciseId);
    var longest = 0;
    for (final id in members) {
      final seconds = restOf(id);
      if (seconds > longest) longest = seconds;
    }
    return longest;
  }

  /// Links [exerciseId] with the exercise after it. If either is already in
  /// a superset the other joins it (two supersets merge); otherwise a new
  /// id is created. No-op for the last exercise.
  static Map<String, String> linkWithNext(
    String exerciseId,
    List<String> order,
    Map<String, String?> groupOf, {
    String Function()? newId,
  }) {
    final groups = normalize(order, groupOf, newId: newId);
    final i = order.indexOf(exerciseId);
    if (i < 0 || i + 1 >= order.length) return groups;
    final next = order[i + 1];
    final target = groups[next] ?? groups[exerciseId] ?? (newId ?? _uuid)();
    final mine = groups[exerciseId];
    if (mine != null && mine != target) {
      for (final key in groups.keys.toList()) {
        if (groups[key] == mine) groups[key] = target;
      }
    }
    groups[exerciseId] = target;
    groups[next] = target;
    return normalize(order, groups, newId: newId);
  }

  /// Takes [exerciseId] out of its superset. Members left alone (or split
  /// off on their own) leave the superset too.
  static Map<String, String> unlink(
    String exerciseId,
    List<String> order,
    Map<String, String?> groupOf, {
    String Function()? newId,
  }) {
    final groups = Map<String, String?>.of(groupOf)..remove(exerciseId);
    return normalize(order, groups, newId: newId);
  }

  /// "A", "B", … "Z", "AA", … for the n-th superset (0-based).
  static String letter(int index) {
    var n = index;
    var text = '';
    do {
      text = String.fromCharCode(65 + n % 26) + text;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return text;
  }
}
