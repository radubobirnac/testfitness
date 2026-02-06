import 'package:equatable/equatable.dart';
import 'package:testfitness/models/exercise.dart';

/// Represents the current state of exercise management
class ExerciseState extends Equatable {
  final List<Exercise> exercises;
  final List<Exercise> filteredExercises;
  final Exercise? currentExercise;
  final List<String> categories;
  final List<String> bodyParts;
  final String searchQuery;
  final String selectedCategory;
  final String selectedBodyPart;
  final bool isLoading;
  final bool isLoadingCurrent;
  final bool isLoadingCategories;
  final bool isLoadingBodyParts;
  final String? errorMessage;
  final String? successMessage;

  const ExerciseState({
    this.exercises = const [],
    this.filteredExercises = const [],
    this.currentExercise,
    this.categories = const [],
    this.bodyParts = const [],
    this.searchQuery = '',
    this.selectedCategory = 'Any Category',
    this.selectedBodyPart = 'Any Body Part',
    this.isLoading = false,
    this.isLoadingCurrent = false,
    this.isLoadingCategories = false,
    this.isLoadingBodyParts = false,
    this.errorMessage,
    this.successMessage,
  });

  /// Initial state when exercise management starts
  const ExerciseState.initial()
      : exercises = const [],
        filteredExercises = const [],
        currentExercise = null,
        categories = const [],
        bodyParts = const [],
        searchQuery = '',
        selectedCategory = 'Any Category',
        selectedBodyPart = 'Any Body Part',
        isLoading = true,
        isLoadingCurrent = false,
        isLoadingCategories = false,
        isLoadingBodyParts = false,
        errorMessage = null,
        successMessage = null;

  /// State when loading exercises
  ExerciseState copyWith({
    List<Exercise>? exercises,
    List<Exercise>? filteredExercises,
    Exercise? currentExercise,
    List<String>? categories,
    List<String>? bodyParts,
    String? searchQuery,
    String? selectedCategory,
    String? selectedBodyPart,
    bool? isLoading,
    bool? isLoadingCurrent,
    bool? isLoadingCategories,
    bool? isLoadingBodyParts,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearCurrentExercise = false,
  }) {
    return ExerciseState(
      exercises: exercises ?? this.exercises,
      filteredExercises: filteredExercises ?? this.filteredExercises,
      currentExercise: clearCurrentExercise ? null : (currentExercise ?? this.currentExercise),
      categories: categories ?? this.categories,
      bodyParts: bodyParts ?? this.bodyParts,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedBodyPart: selectedBodyPart ?? this.selectedBodyPart,
      isLoading: isLoading ?? this.isLoading,
      isLoadingCurrent: isLoadingCurrent ?? this.isLoadingCurrent,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingBodyParts: isLoadingBodyParts ?? this.isLoadingBodyParts,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  /// Check if there are any exercises
  bool get hasExercises => exercises.isNotEmpty;

  /// Check if there are any filtered exercises
  bool get hasFilteredExercises => filteredExercises.isNotEmpty;

  /// Check if currently loading any data
  bool get isAnyLoading => isLoading || isLoadingCurrent || isLoadingCategories || isLoadingBodyParts;

  /// Check if there's an error
  bool get hasError => errorMessage != null;

  /// Check if there's a success message
  bool get hasSuccess => successMessage != null;

  /// Check if any filters are active
  bool get hasActiveFilters => 
      searchQuery.isNotEmpty || 
      selectedCategory != 'Any Category' || 
      selectedBodyPart != 'Any Body Part';

  /// Check if categories are loaded
  bool get hasCategoriesLoaded => categories.isNotEmpty;

  /// Check if body parts are loaded
  bool get hasBodyPartsLoaded => bodyParts.isNotEmpty;

  @override
  List<Object?> get props => [
        exercises,
        filteredExercises,
        currentExercise,
        categories,
        bodyParts,
        searchQuery,
        selectedCategory,
        selectedBodyPart,
        isLoading,
        isLoadingCurrent,
        isLoadingCategories,
        isLoadingBodyParts,
        errorMessage,
        successMessage,
      ];

  @override
  String toString() {
    return 'ExerciseState(exercises: ${exercises.length}, filteredExercises: ${filteredExercises.length}, searchQuery: "$searchQuery", selectedCategory: "$selectedCategory", selectedBodyPart: "$selectedBodyPart", isLoading: $isLoading, hasError: ${errorMessage != null})';
  }
}
