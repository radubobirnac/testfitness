import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/exercise/exercise_event.dart';
import 'package:testfitness/blocs/exercise/exercise_state.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/error_handler.dart';

/// BLoC for managing exercise operations
class ExerciseBloc extends Bloc<ExerciseEvent, ExerciseState> {
  final ExerciseRepository _exerciseRepository;

  ExerciseBloc({ExerciseRepository? exerciseRepository})
      : _exerciseRepository = exerciseRepository ?? ExerciseRepository(),
        super(const ExerciseState.initial()) {
    on<ExerciseLoadRequested>(_onLoadRequested);
    on<ExerciseSearchRequested>(_onSearchRequested);
    on<ExerciseCategoryFilterChanged>(_onCategoryFilterChanged);
    on<ExerciseBodyPartFilterChanged>(_onBodyPartFilterChanged);
    on<ExerciseFiltersApplied>(_onFiltersApplied);
    on<ExerciseLoadByIdRequested>(_onLoadByIdRequested);
    on<ExerciseCreateRequested>(_onCreateRequested);
    on<ExerciseUpdateRequested>(_onUpdateRequested);
    on<ExerciseDeleteRequested>(_onDeleteRequested);
    on<ExerciseCategoriesLoadRequested>(_onCategoriesLoadRequested);
    on<ExerciseBodyPartsLoadRequested>(_onBodyPartsLoadRequested);
    on<ExerciseErrorCleared>(_onErrorCleared);
    on<ExerciseFiltersCleared>(_onFiltersCleared);
  }

  /// Load all exercises
  Future<void> _onLoadRequested(
      ExerciseLoadRequested event, Emitter<ExerciseState> emit) async {
    try {
      AppLogger.info('Loading all exercises...');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      final exercises = await _exerciseRepository.getExercises();
      final filteredExercises = _applyFilters(
        exercises,
        state.searchQuery,
        state.selectedCategory,
        state.selectedBodyPart,
      );

      emit(state.copyWith(
        exercises: exercises,
        filteredExercises: filteredExercises,
        isLoading: false,
      ));

      AppLogger.info('Loaded ${exercises.length} exercises successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load exercises', error, stackTrace);
      ErrorHandler.logWarning('Failed to load exercises', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load exercises: ${error.toString()}',
      ));
    }
  }

  /// Search exercises by query
  void _onSearchRequested(
      ExerciseSearchRequested event, Emitter<ExerciseState> emit) {
    try {
      AppLogger.debug('Searching exercises with query: "${event.query}"');

      final filteredExercises = _applyFilters(
        state.exercises,
        event.query,
        state.selectedCategory,
        state.selectedBodyPart,
      );

      emit(state.copyWith(
        searchQuery: event.query,
        filteredExercises: filteredExercises,
        clearError: true,
        clearSuccess: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to search exercises', error, stackTrace);
      ErrorHandler.logWarning('Failed to search exercises', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to search exercises: ${error.toString()}',
      ));
    }
  }

  /// Change category filter
  void _onCategoryFilterChanged(
      ExerciseCategoryFilterChanged event, Emitter<ExerciseState> emit) {
    try {
      AppLogger.debug(
          'Changing exercise category filter to: ${event.category}');

      final filteredExercises = _applyFilters(
        state.exercises,
        state.searchQuery,
        event.category,
        state.selectedBodyPart,
      );

      emit(state.copyWith(
        selectedCategory: event.category,
        filteredExercises: filteredExercises,
        clearError: true,
        clearSuccess: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to change category filter', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to change category filter', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to change category filter: ${error.toString()}',
      ));
    }
  }

  /// Change body part filter
  void _onBodyPartFilterChanged(
      ExerciseBodyPartFilterChanged event, Emitter<ExerciseState> emit) {
    try {
      AppLogger.debug(
          'Changing exercise body part filter to: ${event.bodyPart}');

      final filteredExercises = _applyFilters(
        state.exercises,
        state.searchQuery,
        state.selectedCategory,
        event.bodyPart,
      );

      emit(state.copyWith(
        selectedBodyPart: event.bodyPart,
        filteredExercises: filteredExercises,
        clearError: true,
        clearSuccess: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to change body part filter', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to change body part filter', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to change body part filter: ${error.toString()}',
      ));
    }
  }

  /// Apply multiple filters at once
  void _onFiltersApplied(
      ExerciseFiltersApplied event, Emitter<ExerciseState> emit) {
    try {
      AppLogger.debug(
          'Applying exercise filters: query="${event.searchQuery}", category="${event.category}", bodyPart="${event.bodyPart}"');

      final filteredExercises = _applyFilters(
        state.exercises,
        event.searchQuery,
        event.category,
        event.bodyPart,
      );

      emit(state.copyWith(
        searchQuery: event.searchQuery,
        selectedCategory: event.category,
        selectedBodyPart: event.bodyPart,
        filteredExercises: filteredExercises,
        clearError: true,
        clearSuccess: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to apply filters', error, stackTrace);
      ErrorHandler.logWarning('Failed to apply filters', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to apply filters: ${error.toString()}',
      ));
    }
  }

  /// Load a specific exercise by ID
  Future<void> _onLoadByIdRequested(
      ExerciseLoadByIdRequested event, Emitter<ExerciseState> emit) async {
    final exerciseId = event.exerciseId.trim();
    if (exerciseId.isEmpty) {
      emit(state.copyWith(
        clearCurrentExercise: true,
        clearError: true,
        clearSuccess: true,
        isLoadingCurrent: false,
      ));
      return;
    }

    try {
      AppLogger.info('Loading exercise by ID: $exerciseId');
      emit(state.copyWith(
          isLoadingCurrent: true, clearError: true, clearSuccess: true));

      final exercise = await _exerciseRepository.getExercise(exerciseId);

      if (exercise != null) {
        emit(state.copyWith(
          currentExercise: exercise,
          isLoadingCurrent: false,
        ));
        AppLogger.info('Loaded exercise: ${exercise.name}');
      } else {
        AppLogger.warning('Exercise not found: $exerciseId');
        emit(state.copyWith(
          isLoadingCurrent: false,
          clearCurrentExercise: true,
          errorMessage: 'Exercise not found',
        ));
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load exercise by ID', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to load exercise by ID', error, stackTrace);

      emit(state.copyWith(
        isLoadingCurrent: false,
        errorMessage: 'Failed to load exercise: ${error.toString()}',
      ));
    }
  }

  /// Apply filters to exercises list
  List<Exercise> _applyFilters(
    List<Exercise> exercises,
    String searchQuery,
    String category,
    String bodyPart,
  ) {
    return exercises.where((exercise) {
      // Apply search filter
      final nameMatches = searchQuery.isEmpty ||
          exercise.name.toLowerCase().contains(searchQuery.toLowerCase());

      // Apply category filter
      final categoryMatches =
          category == 'Any Category' || exercise.category == category;

      // Apply body part filter
      final bodyPartMatches =
          bodyPart == 'Any Body Part' || exercise.muscleGroup == bodyPart;

      return nameMatches && categoryMatches && bodyPartMatches;
    }).toList();
  }

  /// Clear error messages
  void _onErrorCleared(
      ExerciseErrorCleared event, Emitter<ExerciseState> emit) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  /// Create a new exercise
  Future<void> _onCreateRequested(
      ExerciseCreateRequested event, Emitter<ExerciseState> emit) async {
    try {
      AppLogger.info('Creating new exercise: ${event.exercise.name}');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      await _exerciseRepository.addExercise(event.exercise);

      // Reload exercises to get updated list
      final exercises = await _exerciseRepository.getExercises();
      final filteredExercises = _applyFilters(
        exercises,
        state.searchQuery,
        state.selectedCategory,
        state.selectedBodyPart,
      );

      emit(state.copyWith(
        exercises: exercises,
        filteredExercises: filteredExercises,
        isLoading: false,
        successMessage: 'Exercise created successfully',
      ));

      AppLogger.info('Exercise created successfully: ${event.exercise.name}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to create exercise', error, stackTrace);
      ErrorHandler.logWarning('Failed to create exercise', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create exercise: ${error.toString()}',
      ));
    }
  }

  /// Update an existing exercise
  Future<void> _onUpdateRequested(
      ExerciseUpdateRequested event, Emitter<ExerciseState> emit) async {
    try {
      AppLogger.info('Updating exercise: ${event.exercise.name}');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      await _exerciseRepository.updateExercise(event.exercise);

      // Reload exercises to get updated list
      final exercises = await _exerciseRepository.getExercises();
      final filteredExercises = _applyFilters(
        exercises,
        state.searchQuery,
        state.selectedCategory,
        state.selectedBodyPart,
      );

      // Update current exercise if it's the same one
      final updatedCurrentExercise =
          state.currentExercise?.id == event.exercise.id
              ? event.exercise
              : state.currentExercise;

      emit(state.copyWith(
        exercises: exercises,
        filteredExercises: filteredExercises,
        currentExercise: updatedCurrentExercise,
        isLoading: false,
        successMessage: 'Exercise updated successfully',
      ));

      AppLogger.info('Exercise updated successfully: ${event.exercise.name}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to update exercise', error, stackTrace);
      ErrorHandler.logWarning('Failed to update exercise', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update exercise: ${error.toString()}',
      ));
    }
  }

  /// Delete an exercise
  Future<void> _onDeleteRequested(
      ExerciseDeleteRequested event, Emitter<ExerciseState> emit) async {
    try {
      AppLogger.info('Deleting exercise: ${event.exerciseId}');
      emit(state.copyWith(
          isLoading: true, clearError: true, clearSuccess: true));

      await _exerciseRepository.deleteExercise(event.exerciseId);

      // Reload exercises to get updated list
      final exercises = await _exerciseRepository.getExercises();
      final filteredExercises = _applyFilters(
        exercises,
        state.searchQuery,
        state.selectedCategory,
        state.selectedBodyPart,
      );

      // Clear current exercise if it was deleted
      final updatedCurrentExercise =
          state.currentExercise?.id == event.exerciseId
              ? null
              : state.currentExercise;

      emit(state.copyWith(
        exercises: exercises,
        filteredExercises: filteredExercises,
        currentExercise: updatedCurrentExercise,
        isLoading: false,
        successMessage: 'Exercise deleted successfully',
      ));

      AppLogger.info('Exercise deleted successfully: ${event.exerciseId}');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to delete exercise', error, stackTrace);
      ErrorHandler.logWarning('Failed to delete exercise', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete exercise: ${error.toString()}',
      ));
    }
  }

  /// Load available categories
  Future<void> _onCategoriesLoadRequested(ExerciseCategoriesLoadRequested event,
      Emitter<ExerciseState> emit) async {
    try {
      AppLogger.info('Loading exercise categories...');
      emit(state.copyWith(
          isLoadingCategories: true, clearError: true, clearSuccess: true));

      final categories = await _exerciseRepository.getCategories();

      emit(state.copyWith(
        categories: categories,
        isLoadingCategories: false,
      ));

      AppLogger.info(
          'Loaded ${categories.length} exercise categories successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load exercise categories', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to load exercise categories', error, stackTrace);

      emit(state.copyWith(
        isLoadingCategories: false,
        errorMessage: 'Failed to load categories: ${error.toString()}',
      ));
    }
  }

  /// Load available body parts
  Future<void> _onBodyPartsLoadRequested(
      ExerciseBodyPartsLoadRequested event, Emitter<ExerciseState> emit) async {
    try {
      AppLogger.info('Loading exercise body parts...');
      emit(state.copyWith(
          isLoadingBodyParts: true, clearError: true, clearSuccess: true));

      final bodyParts = await _exerciseRepository.getBodyParts();

      emit(state.copyWith(
        bodyParts: bodyParts,
        isLoadingBodyParts: false,
      ));

      AppLogger.info(
          'Loaded ${bodyParts.length} exercise body parts successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to load exercise body parts', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to load exercise body parts', error, stackTrace);

      emit(state.copyWith(
        isLoadingBodyParts: false,
        errorMessage: 'Failed to load body parts: ${error.toString()}',
      ));
    }
  }

  /// Clear search and filters
  void _onFiltersCleared(
      ExerciseFiltersCleared event, Emitter<ExerciseState> emit) {
    try {
      AppLogger.debug('Clearing exercise filters');

      final filteredExercises = _applyFilters(
        state.exercises,
        '',
        'Any Category',
        'Any Body Part',
      );

      emit(state.copyWith(
        searchQuery: '',
        selectedCategory: 'Any Category',
        selectedBodyPart: 'Any Body Part',
        filteredExercises: filteredExercises,
        clearError: true,
        clearSuccess: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to clear filters', error, stackTrace);
      ErrorHandler.logWarning('Failed to clear filters', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to clear filters: ${error.toString()}',
      ));
    }
  }
}
