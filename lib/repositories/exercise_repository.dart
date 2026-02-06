import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/database_service_factory.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/exercise_metadata.dart';

/// Repository for exercise-related operations
class ExerciseRepository {
  final DatabaseInterface _databaseService =
      DatabaseServiceFactory.getDatabaseService();

  /// Get all exercises
  Future<List<Exercise>> getExercises() async {
    return await _databaseService.getExercises();
  }

  /// Get exercise by ID
  Future<Exercise?> getExercise(String id) async {
    return await _databaseService.getExercise(id);
  }

  /// Add a new exercise
  Future<void> addExercise(Exercise exercise) async {
    await _databaseService.insertExercise(exercise);
  }

  /// Update an existing exercise
  Future<void> updateExercise(Exercise exercise) async {
    await _databaseService.updateExercise(exercise);
  }

  /// Delete an exercise
  Future<void> deleteExercise(String id) async {
    await _databaseService.deleteExercise(id);
  }

  /// Search exercises by name
  Future<List<Exercise>> searchExercises(String query) async {
    final exercises = await getExercises();
    if (query.isEmpty) return exercises;

    return exercises
        .where(
          (exercise) =>
              exercise.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  /// Get exercises by category
  Future<List<Exercise>> getExercisesByCategory(String category) async {
    final exercises = await getExercises();
    if (category == 'Any Category') return exercises;

    return exercises
        .where((exercise) => exercise.category == category)
        .toList();
  }

  /// Get exercises by body part
  Future<List<Exercise>> getExercisesByBodyPart(String bodyPart) async {
    final exercises = await getExercises();
    if (bodyPart == 'Any Body Part') return exercises;

    return exercises
        .where((exercise) => exercise.muscleGroup == bodyPart)
        .toList();
  }

  /// Get exercises filtered by search query, category, and body part
  Future<List<Exercise>> getFilteredExercises({
    String searchQuery = '',
    String category = 'Any Category',
    String bodyPart = 'Any Body Part',
  }) async {
    final exercises = await getExercises();

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

  /// Get all available categories
  Future<List<String>> getCategories() async {
    final exercises = await getExercises();

    // Debug what we're getting from database
    AppLogger.debug('Total exercises: ${exercises.length}');
    AppLogger.debug(
        'All categories found: ${exercises.map((e) => e.category).toSet()}');

    final categories = exercises
        .map(ExerciseMetadata.resolveCategory)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList();

    categories.sort();
    return ['Any Category', ...categories];
  }

  /// Get all available body parts
  Future<List<String>> getBodyParts() async {
    final exercises = await getExercises();

    // Debug what we're getting from database
    AppLogger.debug('Total exercises for body parts: ${exercises.length}');
    AppLogger.debug(
        'All muscle groups found: ${exercises.map((e) => e.muscleGroup).toSet()}');

    final bodyParts = <String>{};
    for (final exercise in exercises) {
      bodyParts.addAll(ExerciseMetadata.resolveBodyParts(exercise));
    }

    final sorted = bodyParts.toList()..sort();
    return ['Any Body Part', ...sorted];
  }
}
