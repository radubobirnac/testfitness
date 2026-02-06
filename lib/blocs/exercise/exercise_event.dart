import 'package:equatable/equatable.dart';
import 'package:testfitness/models/exercise.dart';

/// Base class for all exercise events
abstract class ExerciseEvent extends Equatable {
  const ExerciseEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all exercises
class ExerciseLoadRequested extends ExerciseEvent {
  const ExerciseLoadRequested();
}

/// Event to search exercises by query
class ExerciseSearchRequested extends ExerciseEvent {
  final String query;

  const ExerciseSearchRequested(this.query);

  @override
  List<Object?> get props => [query];
}

/// Event to filter exercises by category
class ExerciseCategoryFilterChanged extends ExerciseEvent {
  final String category;

  const ExerciseCategoryFilterChanged(this.category);

  @override
  List<Object?> get props => [category];
}

/// Event to filter exercises by body part
class ExerciseBodyPartFilterChanged extends ExerciseEvent {
  final String bodyPart;

  const ExerciseBodyPartFilterChanged(this.bodyPart);

  @override
  List<Object?> get props => [bodyPart];
}

/// Event to apply multiple filters at once
class ExerciseFiltersApplied extends ExerciseEvent {
  final String searchQuery;
  final String category;
  final String bodyPart;

  const ExerciseFiltersApplied({
    this.searchQuery = '',
    this.category = 'Any Category',
    this.bodyPart = 'Any Body Part',
  });

  @override
  List<Object?> get props => [searchQuery, category, bodyPart];
}

/// Event to load a specific exercise by ID
class ExerciseLoadByIdRequested extends ExerciseEvent {
  final String exerciseId;

  const ExerciseLoadByIdRequested(this.exerciseId);

  @override
  List<Object?> get props => [exerciseId];
}

/// Event to create a new exercise
class ExerciseCreateRequested extends ExerciseEvent {
  final Exercise exercise;

  const ExerciseCreateRequested(this.exercise);

  @override
  List<Object?> get props => [exercise];
}

/// Event to update an existing exercise
class ExerciseUpdateRequested extends ExerciseEvent {
  final Exercise exercise;

  const ExerciseUpdateRequested(this.exercise);

  @override
  List<Object?> get props => [exercise];
}

/// Event to delete an exercise
class ExerciseDeleteRequested extends ExerciseEvent {
  final String exerciseId;

  const ExerciseDeleteRequested(this.exerciseId);

  @override
  List<Object?> get props => [exerciseId];
}

/// Event to load available categories
class ExerciseCategoriesLoadRequested extends ExerciseEvent {
  const ExerciseCategoriesLoadRequested();
}

/// Event to load available body parts
class ExerciseBodyPartsLoadRequested extends ExerciseEvent {
  const ExerciseBodyPartsLoadRequested();
}

/// Event to clear any error messages
class ExerciseErrorCleared extends ExerciseEvent {
  const ExerciseErrorCleared();
}

/// Event to clear search and filters
class ExerciseFiltersCleared extends ExerciseEvent {
  const ExerciseFiltersCleared();
}
