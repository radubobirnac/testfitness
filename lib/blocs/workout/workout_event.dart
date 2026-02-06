import 'package:equatable/equatable.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';

/// Base class for all workout events
abstract class WorkoutEvent extends Equatable {
  const WorkoutEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all workouts
class WorkoutLoadRequested extends WorkoutEvent {
  const WorkoutLoadRequested();
}

/// Event to load workouts with a specific filter
class WorkoutFilterChanged extends WorkoutEvent {
  final String filter; // 'All', 'Scheduled', 'Completed'

  const WorkoutFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Event to load a specific workout by ID
class WorkoutLoadByIdRequested extends WorkoutEvent {
  final String workoutId;

  const WorkoutLoadByIdRequested(this.workoutId);

  @override
  List<Object?> get props => [workoutId];
}

/// Event to create a new workout
class WorkoutCreateRequested extends WorkoutEvent {
  final Workout workout;

  const WorkoutCreateRequested(this.workout);

  @override
  List<Object?> get props => [workout];
}

/// Event to update an existing workout
class WorkoutUpdateRequested extends WorkoutEvent {
  final Workout workout;

  const WorkoutUpdateRequested(this.workout);

  @override
  List<Object?> get props => [workout];
}

/// Event to delete a workout
class WorkoutDeleteRequested extends WorkoutEvent {
  final String workoutId;

  const WorkoutDeleteRequested(this.workoutId);

  @override
  List<Object?> get props => [workoutId];
}

/// Event to complete a workout
class WorkoutCompleteRequested extends WorkoutEvent {
  final String workoutId;
  final int? durationMinutes;

  const WorkoutCompleteRequested(this.workoutId, {this.durationMinutes});

  @override
  List<Object?> get props => [workoutId, durationMinutes];
}

/// Event to duplicate a workout
class WorkoutDuplicateRequested extends WorkoutEvent {
  final String workoutId;
  final bool copyNamePrefix;

  const WorkoutDuplicateRequested(this.workoutId, {this.copyNamePrefix = true});

  @override
  List<Object?> get props => [workoutId, copyNamePrefix];
}

/// Event to add a set to a workout
class WorkoutSetAddRequested extends WorkoutEvent {
  final String workoutId;
  final WorkoutSet set;

  const WorkoutSetAddRequested(this.workoutId, this.set);

  @override
  List<Object?> get props => [workoutId, set];
}

/// Event to update a set in a workout
class WorkoutSetUpdateRequested extends WorkoutEvent {
  final String workoutId;
  final WorkoutSet set;

  const WorkoutSetUpdateRequested(this.workoutId, this.set);

  @override
  List<Object?> get props => [workoutId, set];
}

/// Event to remove a set from a workout
class WorkoutSetRemoveRequested extends WorkoutEvent {
  final String workoutId;
  final String setId;

  const WorkoutSetRemoveRequested(this.workoutId, this.setId);

  @override
  List<Object?> get props => [workoutId, setId];
}

/// Event to complete a set in a workout
class WorkoutSetCompleteRequested extends WorkoutEvent {
  final String workoutId;
  final String setId;

  const WorkoutSetCompleteRequested(this.workoutId, this.setId);

  @override
  List<Object?> get props => [workoutId, setId];
}

/// Event to load workouts for a specific date
class WorkoutLoadForDateRequested extends WorkoutEvent {
  final DateTime date;

  const WorkoutLoadForDateRequested(this.date);

  @override
  List<Object?> get props => [date];
}

/// Event to replace an exercise in a workout while preserving set data
class WorkoutExerciseReplaceRequested extends WorkoutEvent {
  final String workoutId;
  final String oldExerciseId;
  final String newExerciseId;

  const WorkoutExerciseReplaceRequested({
    required this.workoutId,
    required this.oldExerciseId,
    required this.newExerciseId,
  });

  @override
  List<Object?> get props => [workoutId, oldExerciseId, newExerciseId];
}

/// Event to clear any error messages
class WorkoutErrorCleared extends WorkoutEvent {
  const WorkoutErrorCleared();
}
