import 'package:uuid/uuid.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';

/// One exercise slot in a [Routine].
class RoutineExercise {
  final String exerciseId;
  final int sets;

  /// Rep goal used only when there is no history for the exercise;
  /// null = use the coach / last session (falling back to 8).
  final int? reps;

  const RoutineExercise({
    required this.exerciseId,
    required this.sets,
    this.reps,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets,
        if (reps != null) 'reps': reps,
      };

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    final sets = json['sets'];
    final reps = json['reps'];
    return RoutineExercise(
      exerciseId: (json['exerciseId'] ?? '').toString(),
      sets: sets is num && sets > 0 ? sets.toInt() : 3,
      reps: reps is num && reps > 0 ? reps.toInt() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RoutineExercise &&
      other.exerciseId == exerciseId &&
      other.sets == sets &&
      other.reps == reps;

  @override
  int get hashCode => Object.hash(exerciseId, sets, reps);

  @override
  String toString() => 'RoutineExercise($exerciseId, $sets × ${reps ?? '-'})';
}

/// A reusable workout template: an ordered list of exercises with set counts.
class Routine {
  final String id;
  final String name;
  final List<RoutineExercise> exercises;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  const Routine({
    required this.id,
    required this.name,
    required this.exercises,
    required this.createdAt,
    this.lastUsedAt,
  });

  Routine copyWith({
    String? name,
    List<RoutineExercise>? exercises,
    DateTime? lastUsedAt,
  }) {
    return Routine(
      id: id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.millisecondsSinceEpoch,
      };

  factory Routine.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? value) =>
        value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;

    final rawExercises = json['exercises'];
    return Routine(
      id: (json['id'] ?? const Uuid().v4()).toString(),
      name: (json['name'] ?? 'Routine').toString(),
      exercises: rawExercises is List
          ? rawExercises
              .whereType<Map>()
              .map((e) => RoutineExercise.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.exerciseId.isNotEmpty)
              .toList()
          : const [],
      createdAt: date(json['createdAt']) ?? DateTime.now(),
      lastUsedAt: date(json['lastUsedAt']),
    );
  }

  /// Builds a routine from [w]: one entry per exercise in the order it was
  /// first logged, counting that exercise's working sets (warm-ups excluded).
  /// The rep goal is the first working set's reps.
  static Routine fromWorkout(Workout w, {required String name}) {
    final order = <String>[];
    final counts = <String, int>{};
    final reps = <String, int>{};
    for (final set in w.sets) {
      if (set.isWarmup || set.exerciseId.isEmpty) continue;
      if (!counts.containsKey(set.exerciseId)) {
        order.add(set.exerciseId);
        counts[set.exerciseId] = 0;
        if (set.reps > 0) reps[set.exerciseId] = set.reps;
      }
      counts[set.exerciseId] = counts[set.exerciseId]! + 1;
    }
    return Routine(
      id: const Uuid().v4(),
      name: name,
      exercises: [
        for (final id in order)
          RoutineExercise(exerciseId: id, sets: counts[id]!, reps: reps[id]),
      ],
      createdAt: DateTime.now(),
    );
  }

  /// A new, unsaved workout for today with `sets` uncompleted sets per
  /// exercise. Weight/reps come from the coach's target, else the last
  /// session's top set, else 0 × (reps ?? 8).
  Workout toWorkout(
    List<Workout> history, {
    required bool useMetric,
    DateTime? now,
  }) {
    final coach = ProgressionCoach(useMetric: useMetric);
    final today = now ?? DateTime.now();
    final sets = <WorkoutSet>[];
    for (final e in exercises) {
      double weight;
      int reps;
      final target = coach.target(e.exerciseId, history);
      if (target != null) {
        weight = target.weight;
        reps = target.reps;
      } else {
        final last = coach.lastSession(e.exerciseId, history);
        weight = last?.topSet.weight ?? 0;
        reps = last?.topSet.reps ?? e.reps ?? 8;
      }
      for (var i = 0; i < e.sets; i++) {
        sets.add(WorkoutSet.create(
          exerciseId: e.exerciseId,
          reps: reps,
          weight: weight,
        ));
      }
    }
    return Workout.create(
      name: name,
      scheduledDate: DateTime(today.year, today.month, today.day),
      sets: sets,
    );
  }
}
