import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/workout_repository.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/error_handler.dart';

/// BLoC for managing workout operations
class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  final WorkoutRepository _workoutRepository;

  WorkoutBloc({WorkoutRepository? workoutRepository})
      : _workoutRepository = workoutRepository ?? WorkoutRepository(),
        super(const WorkoutState.initial()) {
    // A single handler with a sequential transformer guarantees that ALL
    // workout events (across event types) are processed one at a time.
    // flutter_bloc 8 otherwise runs handlers concurrently, letting
    // read-modify-write handlers interleave and overwrite each other.
    on<WorkoutEvent>(_onEvent, transformer: _sequential());
  }

  /// Process events one at a time so read-modify-write handlers cannot
  /// interleave and overwrite each other's results.
  static EventTransformer<E> _sequential<E>() =>
      (events, mapper) => events.asyncExpand(mapper);

  Future<void> _onEvent(WorkoutEvent event, Emitter<WorkoutState> emit) async {
    if (event is WorkoutLoadRequested) {
      await _onLoadRequested(event, emit);
    } else if (event is WorkoutFilterChanged) {
      _onFilterChanged(event, emit);
    } else if (event is WorkoutLoadByIdRequested) {
      await _onLoadByIdRequested(event, emit);
    } else if (event is WorkoutCreateRequested) {
      await _onCreateRequested(event, emit);
    } else if (event is WorkoutUpdateRequested) {
      await _onUpdateRequested(event, emit);
    } else if (event is WorkoutDeleteRequested) {
      await _onDeleteRequested(event, emit);
    } else if (event is WorkoutCompleteRequested) {
      await _onCompleteRequested(event, emit);
    } else if (event is WorkoutDuplicateRequested) {
      await _onDuplicateRequested(event, emit);
    } else if (event is WorkoutSetAddRequested) {
      await _onSetAddRequested(event, emit);
    } else if (event is WorkoutSetUpdateRequested) {
      await _onSetUpdateRequested(event, emit);
    } else if (event is WorkoutSetRemoveRequested) {
      await _onSetRemoveRequested(event, emit);
    } else if (event is WorkoutSetCompleteRequested) {
      await _onSetCompleteRequested(event, emit);
    } else if (event is WorkoutExerciseReplaceRequested) {
      await _onExerciseReplaceRequested(event, emit);
    } else if (event is WorkoutLoadForDateRequested) {
      await _onLoadForDateRequested(event, emit);
    } else if (event is WorkoutErrorCleared) {
      _onErrorCleared(event, emit);
    }
  }

  /// Load all workouts
  Future<void> _onLoadRequested(
      WorkoutLoadRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Loading all workouts...');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        isLoading: false,
      ));

      AppLogger.info('Loaded ${workouts.length} workouts successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load workouts', error, stackTrace);
      ErrorHandler.logWarning('Failed to load workouts', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load workouts: ${error.toString()}',
      ));
    }
  }

  /// Change workout filter
  void _onFilterChanged(
      WorkoutFilterChanged event, Emitter<WorkoutState> emit) {
    try {
      AppLogger.debug('Changing workout filter to: ${event.filter}');

      final filteredWorkouts = _applyFilter(state.workouts, event.filter);

      emit(state.copyWith(
        currentFilter: event.filter,
        filteredWorkouts: filteredWorkouts,
        clearError: true,
        clearSuccess: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to change filter', error, stackTrace);
      ErrorHandler.logWarning('Failed to change filter', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to change filter: ${error.toString()}',
      ));
    }
  }

  /// Load a specific workout by ID
  Future<void> _onLoadByIdRequested(
      WorkoutLoadByIdRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Loading workout by ID: ${event.workoutId}');
      emit(state.copyWith(
          isLoadingCurrent: true, clearError: true, clearSuccess: true));

      final workout = await _workoutRepository.getWorkout(event.workoutId);

      emit(state.copyWith(
        currentWorkout: workout,
        isLoadingCurrent: false,
      ));

      if (workout != null) {
        AppLogger.info('Loaded workout: ${workout.name}');
      } else {
        AppLogger.warning('Workout not found: ${event.workoutId}');
        emit(state.copyWith(
          errorMessage: 'Workout not found',
        ));
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load workout by ID', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to load workout by ID', error, stackTrace);

      emit(state.copyWith(
        isLoadingCurrent: false,
        errorMessage: 'Failed to load workout: ${error.toString()}',
      ));
    }
  }

  /// Create a new workout
  Future<void> _onCreateRequested(
      WorkoutCreateRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Creating new workout: ${event.workout.name}');
      if (!event.silent) {
        emit(state.copyWith(
            isLoading: true, clearError: true, clearSuccess: true));
      }

      await _workoutRepository.addWorkout(event.workout);

      // Reload workouts to get updated list
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      if (event.silent) {
        emit(state.copyWith(
          workouts: workouts,
          filteredWorkouts: filteredWorkouts,
          currentWorkout: event.workout,
          clearSuccess: true,
        ));
      } else {
        emit(state.copyWith(
          workouts: workouts,
          filteredWorkouts: filteredWorkouts,
          isLoading: false,
          successMessage: 'Workout created successfully',
        ));
      }

      AppLogger.info('Workout created successfully: ${event.workout.name}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to create workout', error, stackTrace);
      ErrorHandler.logWarning('Failed to create workout', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create workout: ${error.toString()}',
      ));
    }
  }

  /// Update an existing workout
  Future<void> _onUpdateRequested(
      WorkoutUpdateRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Updating workout: ${event.workout.name}');
      if (!event.silent) {
        emit(state.copyWith(
            isLoading: true, clearError: true, clearSuccess: true));
      }

      await _workoutRepository.updateWorkout(event.workout);

      // Reload workouts to get updated list
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      // Update current workout if it's the same one
      final updatedCurrentWorkout =
          event.silent || state.currentWorkout?.id == event.workout.id
              ? event.workout
              : state.currentWorkout;

      if (event.silent) {
        emit(state.copyWith(
          workouts: workouts,
          filteredWorkouts: filteredWorkouts,
          currentWorkout: updatedCurrentWorkout,
          clearSuccess: true,
        ));
      } else {
        emit(state.copyWith(
          workouts: workouts,
          filteredWorkouts: filteredWorkouts,
          currentWorkout: updatedCurrentWorkout,
          isLoading: false,
          successMessage: 'Workout updated successfully',
        ));
      }

      AppLogger.info('Workout updated successfully: ${event.workout.name}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to update workout', error, stackTrace);
      ErrorHandler.logWarning('Failed to update workout', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update workout: ${error.toString()}',
      ));
    }
  }

  /// Delete a workout
  Future<void> _onDeleteRequested(
      WorkoutDeleteRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Deleting workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      await _workoutRepository.deleteWorkout(event.workoutId);

      // Reload workouts to get updated list
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      // Clear current workout if it was deleted
      final deletedCurrent = state.currentWorkout?.id == event.workoutId;

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        clearCurrentWorkout: deletedCurrent,
        isLoading: false,
        successMessage: 'Workout deleted successfully',
      ));

      AppLogger.info('Workout deleted successfully: ${event.workoutId}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to delete workout', error, stackTrace);
      ErrorHandler.logWarning('Failed to delete workout', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete workout: ${error.toString()}',
      ));
    }
  }

  /// Apply filter to workouts list and sort by newest first
  List<Workout> _applyFilter(List<Workout> workouts, String filter) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final recentCutoff = now.subtract(const Duration(days: 7));
    List<Workout> filtered;
    switch (filter) {
      case 'Due Today':
        filtered = workouts.where((w) {
          if (w.isCompleted || w.scheduledDate == null) return false;
          final scheduled = w.scheduledDate!;
          return scheduled.year == todayStart.year &&
              scheduled.month == todayStart.month &&
              scheduled.day == todayStart.day;
        }).toList();
        break;
      case 'Overdue':
        filtered = workouts.where((w) {
          if (w.isCompleted || w.scheduledDate == null) return false;
          return w.scheduledDate!.isBefore(todayStart);
        }).toList();
        break;
      case 'Recently Completed':
        filtered = workouts.where((w) {
          if (!w.isCompleted || w.completedDate == null) return false;
          return w.completedDate!.isAfter(recentCutoff);
        }).toList();
        break;
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
        filtered = workouts
            .where((w) => countsByName[w.name] == maxCount)
            .toList();
        break;
      case 'All':
      default:
        filtered = workouts;
        break;
    }

    // Sort workouts by creation date (newest first)
    // Use the workout ID which contains timestamp for creation order
    filtered.sort((a, b) {
      // Extract timestamp from workout ID (format: workout_timestamp)
      final aTimestamp = _extractTimestampFromId(a.id);
      final bTimestamp = _extractTimestampFromId(b.id);

      // Sort newest first (descending order)
      return bTimestamp.compareTo(aTimestamp);
    });

    return filtered;
  }

  /// Extract timestamp from workout ID for sorting
  int _extractTimestampFromId(String id) {
    try {
      // Handle both UUID format and timestamp format
      if (id.startsWith('workout_')) {
        final timestampStr = id.substring(8); // Remove 'workout_' prefix
        return int.tryParse(timestampStr) ?? 0;
      }
      // For UUID format, use hashCode as fallback (not ideal but consistent)
      return id.hashCode;
    } catch (e) {
      return 0;
    }
  }

  /// Complete a workout
  Future<void> _onCompleteRequested(
      WorkoutCompleteRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Completing workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      await _workoutRepository.completeWorkout(event.workoutId,
          durationMinutes: event.durationMinutes);

      // Reload workouts to get updated list
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      // Update current workout if it's the same one
      final updatedCurrentWorkout = state.currentWorkout?.id == event.workoutId
          ? await _workoutRepository.getWorkout(event.workoutId)
          : state.currentWorkout;

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        currentWorkout: updatedCurrentWorkout,
        isLoading: false,
        successMessage: 'Workout completed successfully',
      ));

      AppLogger.info('Workout completed successfully: ${event.workoutId}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to complete workout', error, stackTrace);
      ErrorHandler.logWarning('Failed to complete workout', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to complete workout: ${error.toString()}',
      ));
    }
  }

  /// Duplicate a workout
  Future<void> _onDuplicateRequested(
      WorkoutDuplicateRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Duplicating workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      final newWorkoutId = await _workoutRepository.duplicateWorkout(
        event.workoutId,
        copyNamePrefix: event.copyNamePrefix,
      );

      // Reload workouts to get updated list
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        isLoading: false,
        successMessage: 'Workout duplicated successfully',
      ));

      AppLogger.info('Workout duplicated successfully. New ID: $newWorkoutId');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to duplicate workout', error, stackTrace);
      ErrorHandler.logWarning('Failed to duplicate workout', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to duplicate workout: ${error.toString()}',
      ));
    }
  }

  /// Add a set to a workout
  Future<void> _onSetAddRequested(
      WorkoutSetAddRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Adding set to workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoadingCurrent: true, clearError: true, clearSuccess: true));

      await _workoutRepository.addSetToWorkout(event.workoutId, event.set);

      // Reload current workout and workouts list
      final updatedWorkout =
          await _workoutRepository.getWorkout(event.workoutId);
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        currentWorkout: updatedWorkout,
        isLoadingCurrent: false,
        successMessage: 'Set added successfully',
      ));

      AppLogger.info('Set added successfully to workout: ${event.workoutId}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to add set to workout', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to add set to workout', error, stackTrace);

      emit(state.copyWith(
        isLoadingCurrent: false,
        errorMessage: 'Failed to add set: ${error.toString()}',
      ));
    }
  }

  /// Update a set in a workout
  Future<void> _onSetUpdateRequested(
      WorkoutSetUpdateRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Updating set in workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoadingCurrent: true, clearError: true, clearSuccess: true));

      await _workoutRepository.updateSetInWorkout(event.workoutId, event.set);

      // Reload current workout and workouts list
      final updatedWorkout =
          await _workoutRepository.getWorkout(event.workoutId);
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        currentWorkout: updatedWorkout,
        isLoadingCurrent: false,
        successMessage: 'Set updated successfully',
      ));

      AppLogger.info('Set updated successfully in workout: ${event.workoutId}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to update set in workout', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to update set in workout', error, stackTrace);

      emit(state.copyWith(
        isLoadingCurrent: false,
        errorMessage: 'Failed to update set: ${error.toString()}',
      ));
    }
  }

  /// Remove a set from a workout
  Future<void> _onSetRemoveRequested(
      WorkoutSetRemoveRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Removing set from workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoadingCurrent: true, clearError: true, clearSuccess: true));

      await _workoutRepository.removeSetFromWorkout(
          event.workoutId, event.setId);

      // Reload current workout and workouts list
      final updatedWorkout =
          await _workoutRepository.getWorkout(event.workoutId);
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        currentWorkout: updatedWorkout,
        isLoadingCurrent: false,
        successMessage: 'Set removed successfully',
      ));

      AppLogger.info(
          'Set removed successfully from workout: ${event.workoutId}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to remove set from workout', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to remove set from workout', error, stackTrace);

      emit(state.copyWith(
        isLoadingCurrent: false,
        errorMessage: 'Failed to remove set: ${error.toString()}',
      ));
    }
  }

  /// Complete a set in a workout
  Future<void> _onSetCompleteRequested(
      WorkoutSetCompleteRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Completing set in workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoadingCurrent: true, clearError: true, clearSuccess: true));

      await _workoutRepository.completeSet(event.workoutId, event.setId);

      // Reload current workout and workouts list
      final updatedWorkout =
          await _workoutRepository.getWorkout(event.workoutId);
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        currentWorkout: updatedWorkout,
        isLoadingCurrent: false,
        successMessage: 'Set completed successfully',
      ));

      AppLogger.info(
          'Set completed successfully in workout: ${event.workoutId}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to complete set in workout', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to complete set in workout', error, stackTrace);

      emit(state.copyWith(
        isLoadingCurrent: false,
        errorMessage: 'Failed to complete set: ${error.toString()}',
      ));
    }
  }

  /// Load workouts for a specific date
  Future<void> _onLoadForDateRequested(
      WorkoutLoadForDateRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info('Loading workouts for date: ${event.date}');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      final workouts = await _workoutRepository.getWorkoutsForDate(event.date);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: workouts, // For date-specific loads, show all results
        isLoading: false,
      ));

      AppLogger.info(
          'Loaded ${workouts.length} workouts for date: ${event.date}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load workouts for date', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to load workouts for date', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load workouts for date: ${error.toString()}',
      ));
    }
  }

  /// Replace an exercise in a workout while preserving set data
  Future<void> _onExerciseReplaceRequested(
      WorkoutExerciseReplaceRequested event, Emitter<WorkoutState> emit) async {
    try {
      AppLogger.info(
          'Replacing exercise ${event.oldExerciseId} with ${event.newExerciseId} in workout: ${event.workoutId}');
      emit(state.copyWith(
          isLoadingCurrent: true, clearError: true, clearSuccess: true));

      // Get the current workout
      final currentWorkout =
          await _workoutRepository.getWorkout(event.workoutId);
      if (currentWorkout == null) {
        throw Exception('Workout not found');
      }

      // Replace the exercise while preserving set data
      final updatedWorkout = currentWorkout.replaceExercise(
        event.oldExerciseId,
        event.newExerciseId,
      );

      // Update the workout in the repository
      await _workoutRepository.updateWorkout(updatedWorkout);

      // Reload current workout and workouts list
      final reloadedWorkout =
          await _workoutRepository.getWorkout(event.workoutId);
      final workouts = await _workoutRepository.getWorkouts();
      final filteredWorkouts = _applyFilter(workouts, state.currentFilter);

      emit(state.copyWith(
        workouts: workouts,
        filteredWorkouts: filteredWorkouts,
        currentWorkout: reloadedWorkout,
        isLoadingCurrent: false,
        successMessage: 'Exercise replaced successfully',
      ));

      AppLogger.info(
          'Exercise replaced successfully in workout: ${event.workoutId}');
    } catch (error, stackTrace) {
      AppLogger.error(
          'Failed to replace exercise in workout', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to replace exercise in workout', error, stackTrace);

      emit(state.copyWith(
        isLoadingCurrent: false,
        errorMessage: 'Failed to replace exercise: ${error.toString()}',
      ));
    }
  }

  /// Clear error messages
  void _onErrorCleared(WorkoutErrorCleared event, Emitter<WorkoutState> emit) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
