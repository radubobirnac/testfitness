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
      ];
}
