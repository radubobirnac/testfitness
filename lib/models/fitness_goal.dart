import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Types of fitness goals
enum GoalType {
  workoutFrequency, // e.g., "3 workouts per week"
  totalWorkouts, // e.g., "50 workouts this year"
  exerciseSpecific, // e.g., "Bench press 200 lbs"
  consistency, // e.g., "Workout 5 days in a row"
  duration, // e.g., "Workout for 60 minutes"
}

/// Goal status
enum GoalStatus {
  active,
  completed,
  paused,
  failed,
}

/// Fitness goal model
class FitnessGoal extends Equatable {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final GoalStatus status;
  final DateTime createdDate;
  final DateTime targetDate;
  final double targetValue;
  final double currentValue;
  final String unit; // e.g., "workouts", "lbs", "minutes"
  final Map<String, dynamic> metadata; // Additional goal-specific data

  const FitnessGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.createdDate,
    required this.targetDate,
    required this.targetValue,
    this.currentValue = 0.0,
    required this.unit,
    this.metadata = const {},
  });

  /// Create a new goal
  factory FitnessGoal.create({
    required String title,
    required String description,
    required GoalType type,
    required DateTime targetDate,
    required double targetValue,
    required String unit,
    Map<String, dynamic>? metadata,
  }) {
    return FitnessGoal(
      id: const Uuid().v4(),
      title: title,
      description: description,
      type: type,
      status: GoalStatus.active,
      createdDate: DateTime.now(),
      targetDate: targetDate,
      targetValue: targetValue,
      unit: unit,
      metadata: metadata ?? {},
    );
  }

  /// Calculate progress percentage
  double get progressPercentage {
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue * 100).clamp(0.0, 100.0);
  }

  /// Check if goal is completed
  bool get isCompleted => currentValue >= targetValue;

  /// Check if goal is overdue
  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;

  /// Days remaining to achieve goal
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(targetDate)) return 0;
    return targetDate.difference(now).inDays;
  }

  /// Update progress
  FitnessGoal updateProgress(double newValue) {
    final updatedStatus =
        newValue >= targetValue ? GoalStatus.completed : status;

    return copyWith(
      currentValue: newValue,
      status: updatedStatus,
    );
  }

  /// Copy with modifications
  FitnessGoal copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    GoalStatus? status,
    DateTime? createdDate,
    DateTime? targetDate,
    double? targetValue,
    double? currentValue,
    String? unit,
    Map<String, dynamic>? metadata,
  }) {
    return FitnessGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
      targetDate: targetDate ?? this.targetDate,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'createdDate': createdDate.millisecondsSinceEpoch,
      'targetDate': targetDate.millisecondsSinceEpoch,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'metadata': metadata,
    };
  }

  /// Create from map
  factory FitnessGoal.fromMap(Map<String, dynamic> map) {
    return FitnessGoal(
      id: map['id'] ?? const Uuid().v4(),
      title: map['title'] ?? 'Untitled Goal',
      description: map['description'] ?? '',
      type: GoalType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => GoalType.workoutFrequency,
      ),
      status: GoalStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => GoalStatus.active,
      ),
      createdDate: DateTime.fromMillisecondsSinceEpoch(
        map['createdDate'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      targetDate: DateTime.fromMillisecondsSinceEpoch(
        map['targetDate'] ??
            DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      ),
      targetValue: (map['targetValue'] ?? 0.0).toDouble(),
      currentValue: (map['currentValue'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? 'units',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        status,
        createdDate,
        targetDate,
        targetValue,
        currentValue,
        unit,
        metadata,
      ];
}

/// Predefined goal templates
class GoalTemplates {
  static List<FitnessGoal> getTemplates() {
    final now = DateTime.now();
    final oneMonth = now.add(const Duration(days: 30));
    final threeMonths = now.add(const Duration(days: 90));

    return [
      FitnessGoal.create(
        title: "Workout 3 times per week",
        description: "Maintain a consistent workout schedule",
        type: GoalType.workoutFrequency,
        targetDate: oneMonth,
        targetValue: 12, // 3 workouts × 4 weeks
        unit: "workouts",
      ),
      FitnessGoal.create(
        title: "Complete 50 workouts",
        description: "Reach 50 total completed workouts",
        type: GoalType.totalWorkouts,
        targetDate: threeMonths,
        targetValue: 50,
        unit: "workouts",
      ),
      FitnessGoal.create(
        title: "7-day workout streak",
        description: "Workout for 7 consecutive days",
        type: GoalType.consistency,
        targetDate: now.add(const Duration(days: 14)),
        targetValue: 7,
        unit: "days",
      ),
      FitnessGoal.create(
        title: "60-minute workouts",
        description: "Complete workouts lasting at least 60 minutes",
        type: GoalType.duration,
        targetDate: oneMonth,
        targetValue: 10, // 10 long workouts
        unit: "workouts",
        metadata: {"minDuration": 60},
      ),
    ];
  }
}

/// Goal progress calculator
class GoalProgressCalculator {
  /// Calculate progress for workout frequency goals
  static double calculateWorkoutFrequencyProgress(
    FitnessGoal goal,
    List<dynamic> completedWorkouts,
  ) {
    if (goal.type != GoalType.workoutFrequency) return goal.currentValue;

    final now = DateTime.now();

    final actualWorkouts = completedWorkouts.where((w) {
      final completedDate = w.completedDate;
      return completedDate != null &&
          completedDate.isAfter(goal.createdDate) &&
          completedDate.isBefore(now);
    }).length;

    return actualWorkouts.toDouble();
  }

  /// Calculate progress for total workout goals
  static double calculateTotalWorkoutProgress(
    FitnessGoal goal,
    List<dynamic> completedWorkouts,
  ) {
    if (goal.type != GoalType.totalWorkouts) return goal.currentValue;

    final workoutsAfterGoalCreation = completedWorkouts.where((w) {
      final completedDate = w.completedDate;
      return completedDate != null && completedDate.isAfter(goal.createdDate);
    }).length;

    return workoutsAfterGoalCreation.toDouble();
  }

  /// Calculate progress for consistency goals
  static double calculateConsistencyProgress(
    FitnessGoal goal,
    List<dynamic> completedWorkouts,
  ) {
    if (goal.type != GoalType.consistency) return goal.currentValue;

    // Find the longest current streak
    final sortedWorkouts = completedWorkouts
        .where((w) => w.completedDate != null)
        .toList()
      ..sort((a, b) => b.completedDate!.compareTo(a.completedDate!));

    if (sortedWorkouts.isEmpty) return 0.0;

    int currentStreak = 1;
    DateTime lastDate = sortedWorkouts.first.completedDate!;

    for (int i = 1; i < sortedWorkouts.length; i++) {
      final currentDate = sortedWorkouts[i].completedDate!;
      final daysDiff = lastDate.difference(currentDate).inDays;

      if (daysDiff == 1) {
        currentStreak++;
        lastDate = currentDate;
      } else {
        break;
      }
    }

    return currentStreak.toDouble();
  }
}
