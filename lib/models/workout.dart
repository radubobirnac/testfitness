import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/utils/error_handler.dart';

/// Represents a workout session in the fitness app
class Workout extends Equatable {
  final String id;
  final String name;
  final String? description;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final bool isCompleted;
  final List<WorkoutSet> sets;
  final int? durationMinutes;
  final String? notes;

  const Workout({
    required this.id,
    required this.name,
    this.description,
    this.scheduledDate,
    this.completedDate,
    this.isCompleted = false,
    this.sets = const [],
    this.durationMinutes,
    this.notes,
  });

  /// Create a new workout with a generated ID
  factory Workout.create({
    required String name,
    String? description,
    DateTime? scheduledDate,
    List<WorkoutSet> sets = const [],
    String? notes,
  }) {
    return Workout(
      id: const Uuid().v4(),
      name: name,
      description: description,
      scheduledDate: scheduledDate,
      sets: sets,
      notes: notes,
    );
  }

  /// Create a copy of this workout with modified properties
  Workout copyWith({
    String? name,
    String? description,
    DateTime? scheduledDate,
    DateTime? completedDate,
    bool? isCompleted,
    List<WorkoutSet>? sets,
    int? durationMinutes,
    String? notes,
  }) {
    return Workout(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      isCompleted: isCompleted ?? this.isCompleted,
      sets: sets ?? this.sets,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
    );
  }

  /// Mark this workout as completed
  /// Mark this workout as done.
  ///
  /// [at] backdates the completion (e.g. a workout done on its planned day
  /// months ago); defaults to now. With [markSetsDone], sets that weren't
  /// ticked off are marked completed at that same time, so history, the
  /// calendar and the coach count them on the right day.
  Workout complete({
    int? durationMinutes,
    DateTime? at,
    bool markSetsDone = false,
  }) {
    final when = at ?? DateTime.now();
    return copyWith(
      isCompleted: true,
      completedDate: when,
      durationMinutes: durationMinutes,
      sets: markSetsDone
          ? sets
              .map((s) => s.isCompleted
                  ? s
                  : s.copyWith(isCompleted: true, completedAt: when))
              .toList()
          : null,
    );
  }

  /// The moment to use when marking a planned workout done "on the day":
  /// its scheduled date at midday (falls back to now if unscheduled).
  DateTime get plannedCompletionTime {
    final d = scheduledDate;
    if (d == null) return DateTime.now();
    return DateTime(d.year, d.month, d.day, 12);
  }

  /// Add a set to this workout
  Workout addSet(WorkoutSet set) {
    return copyWith(sets: [...sets, set]);
  }

  /// Remove a set from this workout
  Workout removeSet(String setId) {
    return copyWith(sets: sets.where((s) => s.id != setId).toList());
  }

  /// Update a set in this workout
  Workout updateSet(WorkoutSet updatedSet) {
    return copyWith(
      sets: sets.map((s) => s.id == updatedSet.id ? updatedSet : s).toList(),
    );
  }

  /// Get all sets for a specific exercise
  List<WorkoutSet> getSetsForExercise(String exerciseId) {
    return sets.where((s) => s.exerciseId == exerciseId).toList();
  }

  /// Get unique exercise IDs in this workout
  Set<String> get exerciseIds {
    return sets.map((s) => s.exerciseId).toSet();
  }

  /// Replace an exercise with another exercise while preserving set data
  /// This swaps all sets from oldExerciseId to newExerciseId
  Workout replaceExercise(String oldExerciseId, String newExerciseId) {
    final updatedSets = sets.map((set) {
      if (set.exerciseId == oldExerciseId) {
        return set.copyWith(exerciseId: newExerciseId);
      }
      return set;
    }).toList();

    return copyWith(sets: updatedSets);
  }

  /// Convert workout to a map for database storage
  Map<String, dynamic> toMap() {
    try {
      return {
        'id': id,
        'name': name,
        'description': description,
        'scheduledDate': scheduledDate?.millisecondsSinceEpoch,
        'completedDate': completedDate?.millisecondsSinceEpoch,
        'isCompleted': isCompleted
            ? 1
            : 0, // Convert boolean to 1/0 for SQLite compatibility
        'durationMinutes': durationMinutes,
        'notes': notes,
      };
    } catch (e) {
      ErrorHandler.handleParsingError(e, null, 'Workout.toMap');
      // Return a minimal valid map if something fails
      return {
        'id': id,
        'name': name,
        'isCompleted': false,
      };
    }
  }

  /// Create a workout from a database map
  factory Workout.fromMap(Map<String, dynamic> map, List<WorkoutSet>? sets) {
    try {
      // Generate a new UUID if id is missing
      final id = map['id'] ?? const Uuid().v4();

      // Ensure name is never null (use 'Unnamed Workout' as fallback)
      final name = map['name'] ?? 'Unnamed Workout';

      // Description can be null, so no special handling needed
      final description = map['description'];

      // Handle dates safely
      DateTime? scheduledDate;
      if (map['scheduledDate'] != null) {
        try {
          scheduledDate =
              DateTime.fromMillisecondsSinceEpoch(map['scheduledDate']);
        } catch (e) {
          ErrorHandler.handleParsingError(
              e, null, 'Workout.fromMap scheduledDate');
        }
      }

      DateTime? completedDate;
      if (map['completedDate'] != null) {
        try {
          completedDate =
              DateTime.fromMillisecondsSinceEpoch(map['completedDate']);
        } catch (e) {
          ErrorHandler.handleParsingError(
              e, null, 'Workout.fromMap completedDate');
        }
      }

      // Handle isCompleted with proper fallback
      final isCompleted = map['isCompleted'] == 1 || map['isCompleted'] == true;

      // Ensure sets is never null
      final workoutSets = sets ?? [];

      // Handle durationMinutes (can be null)
      final durationMinutes =
          map['durationMinutes'] is int ? map['durationMinutes'] : null;

      return Workout(
        id: id,
        name: name,
        description: description,
        scheduledDate: scheduledDate,
        completedDate: completedDate,
        isCompleted: isCompleted,
        sets: workoutSets,
        durationMinutes: durationMinutes,
        notes: map['notes'],
      );
    } catch (e) {
      ErrorHandler.handleParsingError(e, null, 'Workout.fromMap');
      // Return a minimal valid Workout if parsing fails
      return Workout(
        id: const Uuid().v4(),
        name: 'Recovery Workout',
        isCompleted: false,
        sets: sets ?? [],
      );
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        scheduledDate,
        completedDate,
        isCompleted,
        sets,
        durationMinutes,
        notes,
      ];
}
