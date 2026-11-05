import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'dart:math';

/// Service for generating AI-powered workouts with proper exercises and weights
class AIWorkoutGenerator {
  static final AIWorkoutGenerator _instance = AIWorkoutGenerator._internal();
  factory AIWorkoutGenerator() => _instance;
  AIWorkoutGenerator._internal();

  final ExerciseRepository _exerciseRepository = ExerciseRepository();
  final AIService _aiService = AIService();

  /// Generate a complete AI workout with exercises and appropriate weights
  Future<Workout> generateAIWorkout({
    required String workoutName,
    required List<Workout> recentWorkouts,
    int lookbackDays = 14,
    bool? preferSingleMuscleGroup,
  }) async {
    try {
      AppLogger.info('Generating AI workout: $workoutName');

      // Step 1: Get AI workout suggestion
      final aiSuggestion = await _aiService.suggestNextWorkout(
        recentWorkouts: recentWorkouts,
        lookbackDays: lookbackDays,
        preferSingleMuscleGroup: preferSingleMuscleGroup,
      );

      return _buildWorkoutFromSuggestion(
        workoutName: workoutName,
        aiSuggestion: aiSuggestion,
        recentWorkouts: recentWorkouts,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to generate AI workout', error, stackTrace);
      rethrow;
    }
  }

  /// Generate a focused AI workout using a prepared context pipeline
  Future<Workout> generateAiWorkout({
    required String workoutName,
    required String focus,
    required List<Workout> recentWorkouts,
    int lookbackDays = 21,
    int maxRecentWorkouts = 6,
  }) async {
    try {
      AppLogger.info('Generating focused AI workout: $workoutName');

      final context = await _buildAiWorkoutContext(
        recentWorkouts,
        lookbackDays: lookbackDays,
        maxWorkouts: maxRecentWorkouts,
      );

      final aiSuggestion = await _aiService.generateAiWorkout(
        focus: focus,
        context: context,
      );

      return _buildWorkoutFromSuggestion(
        workoutName: workoutName,
        aiSuggestion: aiSuggestion,
        recentWorkouts: recentWorkouts,
        focus: focus,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to generate focused AI workout', error, stackTrace);
      rethrow;
    }
  }

  Future<Workout> _buildWorkoutFromSuggestion({
    required String workoutName,
    required String aiSuggestion,
    required List<Workout> recentWorkouts,
    String? focus,
  }) async {
    // Step 2: Parse AI suggestion to extract exercise recommendations
    final exerciseRecommendations =
        _parseAISuggestion(aiSuggestion, focus: focus);

    // Step 3: Get available exercises from database
    final allExercises = await _exerciseRepository.getExercises();
    final focusPool = _filterExercisesForFocus(allExercises, focus);
    final primaryPool = focusPool.isNotEmpty ? focusPool : allExercises;

    // Step 4: Match AI recommendations with actual exercises
    final selectedExercises = _matchExercisesToRecommendations(
      exerciseRecommendations,
      primaryPool,
      fillPool: primaryPool,
    );

    // Step 5: Calculate appropriate weights based on user history
    final workoutSets = await _generateSetsWithWeights(
      selectedExercises,
      recentWorkouts,
    );

    // Step 6: Generate AI reasoning
    final aiReasoning =
        _generateAIReasoning(selectedExercises, recentWorkouts, aiSuggestion);

    // Step 7: Create the workout
    final workout = Workout(
      id: 'workout_${DateTime.now().millisecondsSinceEpoch}',
      name: workoutName,
      sets: workoutSets,
      isCompleted: false,
      scheduledDate: DateTime.now(),
      notes: aiReasoning, // Store AI reasoning in notes field
    );

    AppLogger.info(
        'Generated AI workout with ${selectedExercises.length} exercises and ${workoutSets.length} sets');
    return workout;
  }

  Future<String> _buildAiWorkoutContext(
    List<Workout> recentWorkouts, {
    required int lookbackDays,
    required int maxWorkouts,
  }) async {
    final buffer = StringBuffer();
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));

    final workoutsWithSets = recentWorkouts
        .where((workout) =>
            workout.sets.isNotEmpty &&
            (workout.isCompleted || workout.completedDate != null))
        .toList();

    List<Workout> filtered = workoutsWithSets.where((workout) {
      final date = workout.completedDate ?? workout.scheduledDate;
      if (date == null) return false;
      return date.isAfter(cutoff);
    }).toList();

    if (filtered.isEmpty) {
      filtered = workoutsWithSets;
    }

    filtered.sort((a, b) {
      final dateA = a.completedDate ?? a.scheduledDate ?? DateTime(0);
      final dateB = b.completedDate ?? b.scheduledDate ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    final recent = filtered.take(maxWorkouts).toList();

    final exercises = await _exerciseRepository.getExercises();
    final exerciseById = {
      for (final exercise in exercises) exercise.id: exercise
    };

    buffer.writeln(
        'Recent workouts (most recent first, last $lookbackDays days):');

    if (recent.isEmpty) {
      buffer.writeln('- No recent workouts available.');
    } else {
      for (final workout in recent) {
        final date = workout.completedDate ?? workout.scheduledDate;
        final dateLabel =
            date == null ? 'Unknown date' : date.toIso8601String().split('T')[0];
        buffer.writeln('- $dateLabel: ${workout.name}');

        final setsByExercise = <String, List<WorkoutSet>>{};
        for (final set in workout.sets) {
          setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
        }

        var exerciseCount = 0;
        for (final entry in setsByExercise.entries) {
          if (exerciseCount >= 6) break;
          final exercise = exerciseById[entry.key];
          final name = exercise?.name ?? entry.key;
          final sets = entry.value;
          final maxWeight = sets
              .map((s) => s.weight)
              .fold<double>(0, (maxValue, value) {
            return value > maxValue ? value : maxValue;
          });
          final avgReps =
              (sets.map((s) => s.reps).reduce((a, b) => a + b) / sets.length)
                  .round();

          buffer.writeln(
              '  * $name: ${sets.length} sets, top ${_formatWeight(maxWeight)}, avg $avgReps reps');
          exerciseCount += 1;
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('Progression rules:');
    buffer.writeln(
        '- Use 3-4 working sets per exercise with a warm-up set at ~80% load');
    buffer.writeln(
        '- Increase load 5-10% for compound lifts and 2.5-5% for isolation when last performance was solid');
    buffer.writeln('- Keep reps in the 6-12 range for compounds');
    buffer.writeln('- Keep reps in the 8-15 range for accessory movements');
    buffer.writeln(
        '- Balance push, pull, and legs across sessions when possible');

    return buffer.toString();
  }

  String _formatWeight(double weight) {
    if (weight == 0) return 'bodyweight';
    if (weight == weight.roundToDouble()) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
  }

  /// Parse AI suggestion text to extract exercise recommendations
  List<ExerciseRecommendation> _parseAISuggestion(String aiSuggestion,
      {String? focus}) {
    final recommendations = <ExerciseRecommendation>[];

    // Common exercise patterns to look for in AI text
    final exercisePatterns = {
      'squat': ['squat', 'squats'],
      'deadlift': ['deadlift', 'deadlifts'],
      'bench': ['bench', 'bench press'],
      'row': ['row', 'rows', 'barbell row'],
      'press': ['press', 'overhead press', 'shoulder press'],
      'curl': ['curl', 'curls', 'bicep curl'],
      'extension': ['extension', 'tricep extension'],
      'pullup': ['pull-up', 'pullup', 'pull up'],
      'pushup': ['push-up', 'pushup', 'push up'],
      'lunge': ['lunge', 'lunges'],
      'dip': ['dip', 'dips'],
      'pulldown': ['pulldown', 'lat pulldown'],
    };

    // Muscle group patterns
    final muscleGroups = {
      'chest': ['chest', 'pectoral'],
      'back': ['back', 'lat', 'rhomboid'],
      'shoulders': ['shoulder', 'deltoid'],
      'arms': ['arm', 'bicep', 'tricep'],
      'legs': ['leg', 'quad', 'hamstring', 'glute'],
      'core': ['core', 'abs', 'abdominal'],
    };

    final lowerText = aiSuggestion.toLowerCase();

    // Look for specific exercise mentions
    for (final entry in exercisePatterns.entries) {
      for (final pattern in entry.value) {
        if (lowerText.contains(pattern)) {
          recommendations.add(ExerciseRecommendation(
            exerciseType: entry.key,
            muscleGroup: _getMuscleGroupForExercise(entry.key),
            priority: 1,
          ));
          break;
        }
      }
    }

    // If no specific exercises found, add based on muscle groups mentioned
    if (recommendations.isEmpty) {
      for (final entry in muscleGroups.entries) {
        for (final pattern in entry.value) {
          if (lowerText.contains(pattern)) {
            recommendations.add(ExerciseRecommendation(
              exerciseType: 'general',
              muscleGroup: entry.key,
              priority: 2,
            ));
            break;
          }
        }
      }
    }

    // Default fallback - create a balanced workout or focus-based guidance
    if (recommendations.isEmpty) {
      final focusGroups = _focusToMuscleGroups(focus);
      if (focusGroups.isNotEmpty) {
        for (final group in focusGroups) {
          recommendations.add(ExerciseRecommendation(
            exerciseType: 'general',
            muscleGroup: group,
            priority: 1,
          ));
        }
      } else {
        recommendations.addAll([
          ExerciseRecommendation(
              exerciseType: 'squat', muscleGroup: 'legs', priority: 1),
          ExerciseRecommendation(
              exerciseType: 'bench', muscleGroup: 'chest', priority: 1),
          ExerciseRecommendation(
              exerciseType: 'row', muscleGroup: 'back', priority: 1),
          ExerciseRecommendation(
              exerciseType: 'press', muscleGroup: 'shoulders', priority: 2),
        ]);
      }
    }

    return recommendations;
  }

  List<String> _focusToMuscleGroups(String? focus) {
    if (focus == null || focus.trim().isEmpty) return [];
    final normalized = focus.toLowerCase();

    if (normalized.contains('full')) {
      return [];
    }
    if (normalized.contains('upper')) {
      return ['chest', 'back', 'shoulders', 'arms'];
    }
    if (normalized.contains('lower')) {
      return ['legs'];
    }
    if (normalized.contains('push')) {
      return ['chest', 'shoulders', 'arms'];
    }
    if (normalized.contains('pull')) {
      return ['back', 'arms'];
    }
    if (normalized.contains('legs')) {
      return ['legs'];
    }
    if (normalized.contains('chest')) {
      return ['chest'];
    }
    if (normalized.contains('back')) {
      return ['back'];
    }
    if (normalized.contains('shoulders')) {
      return ['shoulders'];
    }
    if (normalized.contains('arms')) {
      return ['arms'];
    }
    if (normalized.contains('core')) {
      return ['core'];
    }

    return [];
  }

  /// Get muscle group for exercise type
  String _getMuscleGroupForExercise(String exerciseType) {
    const exerciseToMuscleGroup = {
      'squat': 'legs',
      'deadlift': 'legs',
      'bench': 'chest',
      'row': 'back',
      'press': 'shoulders',
      'curl': 'arms',
      'extension': 'arms',
      'pullup': 'back',
      'pushup': 'chest',
      'lunge': 'legs',
      'dip': 'chest',
      'pulldown': 'back',
    };
    return exerciseToMuscleGroup[exerciseType] ?? 'general';
  }

  /// Match exercise recommendations to actual exercises in database
  List<Exercise> _matchExercisesToRecommendations(
    List<ExerciseRecommendation> recommendations,
    List<Exercise> allExercises, {
    List<Exercise>? fillPool,
  }) {
    final selectedExercises = <Exercise>[];
    final usedExercises = <String>{};
    final pool =
        (fillPool == null || fillPool.isEmpty) ? allExercises : fillPool;

    for (final recommendation in recommendations) {
      Exercise? bestMatch;

      if (recommendation.exerciseType != 'general') {
        // Look for specific exercise type
        bestMatch = allExercises
            .where((e) => !usedExercises.contains(e.id))
            .where((e) =>
                e.name.toLowerCase().contains(recommendation.exerciseType))
            .firstOrNull;
      }

      // If no specific match, find by muscle group
      bestMatch ??= allExercises
          .where((e) => !usedExercises.contains(e.id))
          .where((e) =>
              e.muscleGroup
                      ?.toLowerCase()
                      .contains(recommendation.muscleGroup) ==
                  true ||
              e.category?.toLowerCase().contains(recommendation.muscleGroup) ==
                  true)
          .firstOrNull;

      if (bestMatch != null) {
        selectedExercises.add(bestMatch);
        usedExercises.add(bestMatch.id);
      }
    }

    // Ensure we have at least 3-4 exercises for a good workout
    while (selectedExercises.length < 4) {
      final remainingExercises =
          pool.where((e) => !usedExercises.contains(e.id)).toList();

      if (remainingExercises.isEmpty) break;

      final randomExercise =
          remainingExercises[Random().nextInt(remainingExercises.length)];
      selectedExercises.add(randomExercise);
      usedExercises.add(randomExercise.id);
    }

    return selectedExercises;
  }

  List<Exercise> _filterExercisesForFocus(
    List<Exercise> exercises,
    String? focus,
  ) {
    final keywords = _focusKeywordsFor(focus);
    if (keywords.isEmpty) return exercises;

    final matching = exercises.where((exercise) {
      final haystack = [
        exercise.name,
        exercise.muscleGroup ?? '',
        exercise.category ?? '',
      ].join(' ').toLowerCase();
      return keywords.any(haystack.contains);
    }).toList();

    if (matching.isEmpty) return matching;

    final nonImported =
        matching.where((exercise) => !_isImportedExercise(exercise)).toList();
    return nonImported.isNotEmpty ? nonImported : matching;
  }

  bool _isImportedExercise(Exercise exercise) {
    final category = exercise.category?.toLowerCase().trim() ?? '';
    final description = exercise.description?.toLowerCase().trim() ?? '';
    if (category == 'imported') return true;
    if (description == 'imported from csv') return true;
    return false;
  }

  Set<String> _focusKeywordsFor(String? focus) {
    if (focus == null) return {};
    final normalized = focus.toLowerCase();
    if (normalized.contains('full')) {
      return {};
    }
    if (normalized.contains('upper')) {
      return {
        'chest',
        'back',
        'shoulder',
        'deltoid',
        'arm',
        'bicep',
        'tricep',
      };
    }
    if (normalized.contains('lower')) {
      return {'leg', 'quad', 'hamstring', 'glute', 'calf'};
    }
    if (normalized.contains('push')) {
      return {'chest', 'shoulder', 'deltoid', 'tricep'};
    }
    if (normalized.contains('pull')) {
      return {'back', 'lat', 'rhomboid', 'bicep'};
    }
    if (normalized.contains('legs')) {
      return {'leg', 'quad', 'hamstring', 'glute', 'calf'};
    }
    if (normalized.contains('chest')) {
      return {'chest', 'pectoral', 'pec'};
    }
    if (normalized.contains('back')) {
      return {'back', 'lat', 'rhomboid'};
    }
    if (normalized.contains('shoulder')) {
      return {'shoulder', 'deltoid'};
    }
    if (normalized.contains('arms')) {
      return {'arm', 'bicep', 'tricep', 'forearm'};
    }
    if (normalized.contains('core')) {
      return {'core', 'abs', 'abdominal'};
    }
    return {normalized};
  }

  /// Generate sets with appropriate weights based on user history
  Future<List<WorkoutSet>> _generateSetsWithWeights(
    List<Exercise> exercises,
    List<Workout> recentWorkouts,
  ) async {
    final allSets = <WorkoutSet>[];

    for (final exercise in exercises) {
      // Get user's recent performance for this exercise
      final recentWeight =
          _getRecentWeightForExercise(exercise.id, recentWorkouts);
      final recentReps = _getRecentRepsForExercise(exercise.id, recentWorkouts);

      // Calculate progressive weight (5-10% increase from last time)
      final baseWeight =
          recentWeight > 0 ? recentWeight : _getDefaultWeight(exercise);
      final progressiveWeight =
          _calculateProgressiveWeight(baseWeight, exercise);

      // Generate 3-4 sets with progressive overload
      final setCount = 3 + Random().nextInt(2); // 3-4 sets

      for (int i = 0; i < setCount; i++) {
        final setWeight = i == 0
            ? _roundToNearestFive(
                baseWeight * 0.8) // Warm-up first set (rounded)
            : progressiveWeight;
        final setReps = _calculateRepsForSet(i, recentReps, exercise);

        allSets.add(WorkoutSet(
          id: 'set_${DateTime.now().millisecondsSinceEpoch}_${exercise.id}_$i',
          exerciseId: exercise.id,
          weight: setWeight,
          reps: setReps,
          isCompleted: false,
        ));
      }
    }

    return allSets;
  }

  /// Get recent weight used for an exercise
  double _getRecentWeightForExercise(
      String exerciseId, List<Workout> recentWorkouts) {
    for (final workout in recentWorkouts.reversed) {
      final exerciseSets = workout.sets
          .where((s) => s.exerciseId == exerciseId && s.isCompleted);
      if (exerciseSets.isNotEmpty) {
        return exerciseSets
            .map((s) => s.weight)
            .reduce((a, b) => a > b ? a : b);
      }
    }
    return 0;
  }

  /// Get recent reps used for an exercise
  int _getRecentRepsForExercise(
      String exerciseId, List<Workout> recentWorkouts) {
    for (final workout in recentWorkouts.reversed) {
      final exerciseSets = workout.sets
          .where((s) => s.exerciseId == exerciseId && s.isCompleted);
      if (exerciseSets.isNotEmpty) {
        return (exerciseSets.map((s) => s.reps).reduce((a, b) => a + b) /
                exerciseSets.length)
            .round();
      }
    }
    return 8; // Default reps
  }

  /// Get default starting weight for an exercise (gym-friendly 5lb increments)
  double _getDefaultWeight(Exercise exercise) {
    // Default weights based on exercise type and category (all in 5lb increments)
    final category = exercise.category?.toLowerCase() ?? '';
    final name = exercise.name.toLowerCase();

    if (name.contains('squat') || name.contains('deadlift')) {
      return 135.0; // Already 5lb increment
    }
    if (name.contains('bench') || name.contains('press')) {
      return 95.0; // Already 5lb increment
    }
    if (name.contains('row') || name.contains('pulldown')) {
      return 100.0; // Already 5lb increment
    }
    if (name.contains('curl') || name.contains('extension')) {
      return 25.0; // Already 5lb increment
    }
    if (category.contains('cardio')) return 0.0;

    return 50.0; // General default (5lb increment)
  }

  /// Calculate progressive weight increase (rounded to nearest 5 lbs for gym compatibility)
  double _calculateProgressiveWeight(double baseWeight, Exercise exercise) {
    if (baseWeight == 0) {
      return _roundToNearestFive(_getDefaultWeight(exercise));
    }

    // 5-10% increase for strength exercises, 2.5-5% for isolation
    final category = exercise.category?.toLowerCase() ?? '';
    final increasePercent = category.contains('strength') ? 0.075 : 0.05;

    final newWeight = baseWeight * (1 + increasePercent);
    return _roundToNearestFive(newWeight);
  }

  /// Round weight to nearest 5 pounds (standard gym increment)
  double _roundToNearestFive(double weight) {
    return (weight / 5).round() * 5.0;
  }

  /// Calculate reps for a specific set
  int _calculateRepsForSet(int setIndex, int baseReps, Exercise exercise) {
    if (setIndex == 0) return baseReps + 2; // Warm-up set with higher reps

    // Progressive rep scheme: higher weight, lower reps
    final repReduction = setIndex * 1;
    return (baseReps - repReduction).clamp(6, 15);
  }

  /// Generate AI reasoning for exercise selection and programming
  String _generateAIReasoning(List<Exercise> selectedExercises,
      List<Workout> recentWorkouts, String aiSuggestion) {
    final buffer = StringBuffer();

    buffer.writeln('🤖 AI WORKOUT REASONING\n');

    // Exercise selection reasoning
    buffer.writeln('📋 EXERCISE SELECTION:');
    for (int i = 0; i < selectedExercises.length; i++) {
      final exercise = selectedExercises[i];
      final muscleGroup = exercise.muscleGroup ?? 'general';
      final categoryLabel = _isImportedExercise(exercise)
          ? 'General'
          : (exercise.category ?? 'General');
      buffer.writeln('${i + 1}. ${exercise.name}');
      buffer.writeln('   → Targets: ${muscleGroup.toUpperCase()}');
      buffer.writeln('   → Category: $categoryLabel');

      // Add specific reasoning based on exercise type
      if (exercise.name.toLowerCase().contains('squat')) {
        buffer.writeln('   → Compound movement for leg strength & power');
      } else if (exercise.name.toLowerCase().contains('deadlift')) {
        buffer.writeln('   → Full-body strength & posterior chain development');
      } else if (exercise.name.toLowerCase().contains('bench') ||
          exercise.name.toLowerCase().contains('press')) {
        buffer.writeln('   → Upper body pushing strength & chest development');
      } else if (exercise.name.toLowerCase().contains('row') ||
          exercise.name.toLowerCase().contains('pulldown')) {
        buffer.writeln('   → Upper body pulling strength & back development');
      } else if (exercise.name.toLowerCase().contains('curl')) {
        buffer.writeln('   → Isolation movement for arm development');
      } else {
        buffer.writeln('   → Selected for balanced muscle development');
      }
      buffer.writeln('');
    }

    // Weight progression reasoning
    buffer.writeln('⚖️ WEIGHT PROGRESSION:');
    buffer.writeln('• All weights rounded to 5lb increments (gym standard)');
    buffer.writeln(
        '• Progressive overload: 5-10% increase from recent performance');
    buffer.writeln('• Warm-up sets at 80% of working weight');
    buffer.writeln('• Strength exercises get larger increases than isolation');
    buffer.writeln('');

    // Rep scheme reasoning
    buffer.writeln('🔢 REP SCHEME:');
    buffer.writeln('• Set 1: Higher reps for warm-up and muscle activation');
    buffer
        .writeln('• Sets 2-4: Progressive intensity with slightly lower reps');
    buffer.writeln('• Rep range optimized for strength and hypertrophy');
    buffer.writeln('');

    // Recent workout analysis
    if (recentWorkouts.isNotEmpty) {
      buffer.writeln('📊 RECENT ACTIVITY ANALYSIS:');
      buffer.writeln('• Analyzed ${recentWorkouts.length} recent workouts');

      // Count total exercises in recent workouts
      int totalExercises = 0;
      for (final workout in recentWorkouts) {
        totalExercises += workout.exerciseIds.length;
      }
      buffer.writeln('• Total exercises in recent workouts: $totalExercises');

      buffer.writeln('• Balanced selection to avoid overtraining');
      buffer.writeln('• Progressive difficulty based on recent performance');
      buffer.writeln('');
    }

    // AI suggestion context
    buffer.writeln('💡 AI SUGGESTION CONTEXT:');
    buffer.writeln(
        '"${aiSuggestion.length > 100 ? '${aiSuggestion.substring(0, 100)}...' : aiSuggestion}"');
    buffer.writeln('');

    buffer.writeln(
        '✅ This workout is designed for progressive strength building');
    buffer
        .writeln('   with proper warm-up and gym-standard weight increments.');

    return buffer.toString();
  }
}

/// Data class for exercise recommendations from AI
class ExerciseRecommendation {
  final String exerciseType;
  final String muscleGroup;
  final int priority;

  ExerciseRecommendation({
    required this.exerciseType,
    required this.muscleGroup,
    required this.priority,
  });
}
