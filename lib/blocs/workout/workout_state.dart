import 'package:equatable/equatable.dart';
import 'package:testfitness/models/workout.dart';

/// Represents the current state of workout management
class WorkoutState extends Equatable {
  final List<Workout> workouts;
  final List<Workout> filteredWorkouts;
  final Workout? currentWorkout;
  final String currentFilter;
  final bool isLoading;
  final bool isLoadingCurrent;
  final String? errorMessage;
  final String? successMessage;

  const WorkoutState({
    this.workouts = const [],
    this.filteredWorkouts = const [],
    this.currentWorkout,
    this.currentFilter = 'All',
    this.isLoading = false,
    this.isLoadingCurrent = false,
    this.errorMessage,
    this.successMessage,
  });

  /// Initial state when workout management starts
  const WorkoutState.initial()
      : workouts = const [],
        filteredWorkouts = const [],
        currentWorkout = null,
        currentFilter = 'All',
        isLoading = true,
        isLoadingCurrent = false,
        errorMessage = null,
        successMessage = null;

  /// State when loading workouts
  WorkoutState copyWith({
    List<Workout>? workouts,
    List<Workout>? filteredWorkouts,
    Workout? currentWorkout,
    String? currentFilter,
    bool? isLoading,
    bool? isLoadingCurrent,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearCurrentWorkout = false,
  }) {
    return WorkoutState(
      workouts: workouts ?? this.workouts,
      filteredWorkouts: filteredWorkouts ?? this.filteredWorkouts,
      currentWorkout: clearCurrentWorkout ? null : (currentWorkout ?? this.currentWorkout),
      currentFilter: currentFilter ?? this.currentFilter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingCurrent: isLoadingCurrent ?? this.isLoadingCurrent,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  /// Get filtered workouts based on current filter
  List<Workout> getFilteredWorkouts() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final recentCutoff = now.subtract(const Duration(days: 7));
    switch (currentFilter) {
      case 'Due Today':
        return workouts.where((w) {
          if (w.isCompleted || w.scheduledDate == null) return false;
          final scheduled = w.scheduledDate!;
          return scheduled.year == todayStart.year &&
              scheduled.month == todayStart.month &&
              scheduled.day == todayStart.day;
        }).toList();
      case 'Overdue':
        return workouts.where((w) {
          if (w.isCompleted || w.scheduledDate == null) return false;
          return w.scheduledDate!.isBefore(todayStart);
        }).toList();
      case 'Recently Completed':
        return workouts.where((w) {
          if (!w.isCompleted || w.completedDate == null) return false;
          return w.completedDate!.isAfter(recentCutoff);
        }).toList();
      case 'Most Frequent':
        final countsByName = <String, int>{};
        for (final workout in workouts) {
          countsByName[workout.name] =
              (countsByName[workout.name] ?? 0) + 1;
        }
        final maxCount = countsByName.values.fold<int>(
          0,
          (prev, count) => count > prev ? count : prev,
        );
        return workouts
            .where((w) => countsByName[w.name] == maxCount)
            .toList();
      case 'All':
      default:
        return workouts;
    }
  }

  /// Check if there are any workouts
  bool get hasWorkouts => workouts.isNotEmpty;

  /// Check if there are any filtered workouts
  bool get hasFilteredWorkouts => filteredWorkouts.isNotEmpty;

  /// Check if currently loading any data
  bool get isAnyLoading => isLoading || isLoadingCurrent;

  /// Check if there's an error
  bool get hasError => errorMessage != null;

  /// Check if there's a success message
  bool get hasSuccess => successMessage != null;

  @override
  List<Object?> get props => [
        workouts,
        filteredWorkouts,
        currentWorkout,
        currentFilter,
        isLoading,
        isLoadingCurrent,
        errorMessage,
        successMessage,
      ];

  @override
  String toString() {
    return 'WorkoutState(workouts: ${workouts.length}, filteredWorkouts: ${filteredWorkouts.length}, currentFilter: $currentFilter, isLoading: $isLoading, hasError: ${errorMessage != null})';
  }
}
