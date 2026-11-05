import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:testfitness/services/api_key_service.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/offline_indicator.dart';

/// AI Service powered by Google Gemini 2.5 Flash Lite
///
/// **DISCLAIMER: AI features require an active internet connection**
class AIService {
  static const String _defaultModelName = 'gemini-2.5-flash-lite';
  static const String _modelName = String.fromEnvironment('GEMINI_MODEL',
      defaultValue: _defaultModelName);

  /// Key the current [_model] was built with; used to rebuild on key change.
  String? _modelKey;
  GenerativeModel? _model;
  static AIService? _instance;

  AIService._internal() {
    if (!hasApiKey) {
      AppLogger.warning('Gemini API key is not configured; AI features disabled');
    }
  }

  factory AIService() {
    _instance ??= AIService._internal();
    return _instance!;
  }

  String? get _apiKey => ApiKeyService().cachedKey;

  /// Whether a Gemini API key is configured (user-saved or debug define).
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Whether the device is currently online.
  bool get isOnline => ConnectivityService().isOnline;

  /// Check if AI features are available (requires API key and internet)
  bool get isAvailable => hasApiKey && isOnline;

  /// User-facing reason AI is unavailable, or null when it is available.
  String? get unavailableReason {
    if (!hasApiKey) return ApiKeyService.missingKeyMessage;
    if (!isOnline) {
      return 'AI features require an internet connection. Please check your connection and try again.';
    }
    return null;
  }

  GenerativeModel _buildModel(String apiKey) {
    return GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  /// Maximum time to wait for a Gemini response before giving up, so callers
  /// can fall back (e.g. to the offline coach) instead of spinning forever.
  static const Duration requestTimeout = Duration(seconds: 30);

  Future<GenerateContentResponse> _generate(List<Content> content) async {
    try {
      return await _requireModel()
          .generateContent(content)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw AIServiceException(
          'AI took too long to respond. Check your connection and try again.');
    }
  }

  GenerativeModel _requireModel() {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw AIServiceException(ApiKeyService.missingKeyMessage);
    }

    if (!ConnectivityService().isOnline) {
      throw AIServiceException('AI features require an internet connection');
    }

    // Rebuild the model if the user changed their key.
    if (_model == null || _modelKey != key) {
      _model = _buildModel(key);
      _modelKey = key;
    }
    return _model!;
  }

  /// Analyze workout progress and provide insights
  Future<String> analyzeProgress({
    required List<Workout> completedWorkouts,
    required String timeframe, // week, month, quarter
  }) async {
    try {
      AppLogger.info('Analyzing workout progress');

      final prompt = _buildProgressAnalysisPrompt(completedWorkouts, timeframe);

      final content = [Content.text(prompt)];
      final response = await _generate(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      AppLogger.info('Successfully analyzed workout progress');
      return response.text!;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to analyze progress', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to analyze progress: ${error.toString()}');
    }
  }

  /// Generate next workout suggestion based on user's workout history
  Future<String> suggestNextWorkout({
    required List<Workout> recentWorkouts,
    int lookbackDays = 14,
    bool? preferSingleMuscleGroup,
    WorkoutPreferences? preferences,
  }) async {
    try {
      AppLogger.info('Generating next workout suggestion');

      final prompt = _buildNextWorkoutPrompt(
        recentWorkouts,
        lookbackDays,
        preferSingleMuscleGroup: preferSingleMuscleGroup,
        preferences: preferences,
      );

      final content = [Content.text(prompt)];
      final response = await _generate(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      AppLogger.info('Successfully generated next workout suggestion');
      return response.text!;
    } catch (error, stackTrace) {
      AppLogger.error(
          'Failed to generate next workout suggestion', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to generate next workout suggestion: ${error.toString()}');
    }
  }

  /// Generate a focused workout suggestion using prepared context
  Future<String> generateAiWorkout({
    required String focus,
    required String context,
    WorkoutPreferences? preferences,
  }) async {
    try {
      AppLogger.info('Generating focused AI workout');

      final prompt = _buildAiWorkoutPrompt(
        focus: focus,
        context: context,
        preferences: preferences,
      );

      final content = [Content.text(prompt)];
      final response = await _generate(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      AppLogger.info('Successfully generated focused AI workout');
      return response.text!;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to generate focused AI workout', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to generate focused AI workout: ${error.toString()}');
    }
  }

  /// Answer fitness-related questions
  Future<String> answerFitnessQuestion(String question) async {
    try {
      AppLogger.info('Answering fitness question');

      final prompt = '''
You are a knowledgeable fitness coach. Answer this fitness question clearly and concisely:

"$question"

Requirements:
- Provide accurate, evidence-based information
- Keep the answer practical and actionable
- Use simple language that beginners can understand
- Include safety considerations when relevant
- Maximum 3 paragraphs
- If the question is not fitness-related, politely redirect to fitness topics
''';

      final content = [Content.text(prompt)];
      final response = await _generate(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      AppLogger.info('Successfully answered fitness question');
      return response.text!;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to answer fitness question', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to answer fitness question: ${error.toString()}');
    }
  }

  static const Map<String, List<String>> _motivationPhrases = {
    'rest_complete': [
      "Let's Go! 💪",
      'Beast Mode! 🔥',
      'Crush It! 💥',
      'You Got This! ⚡',
      'Time to Shine! ✨',
    ],
    'set_complete': [
      'Great Set! 🎯',
      'Keep Going! 💪',
      'Strong Work! 🔥',
      'Excellent! ⭐',
      'Power Up! ⚡',
    ],
    'workout_complete': [
      'Workout Done! 🏆',
      'Amazing Job! 🌟',
      'Victory! 🎉',
      'Crushed It! 💥',
      'Champion! 👑',
    ],
  };

  /// Picks a quick motivational phrase. Purely offline (built-in list, no
  /// API key or network). Speaking it is the caller's job, via
  /// EnhancedTTSService, so the user's voice settings and switches apply.
  static String quickMotivationPhrase(String context, {int? seed}) {
    final phrases =
        _motivationPhrases[context] ?? _motivationPhrases['rest_complete']!;
    final index = (seed ?? DateTime.now().millisecondsSinceEpoch) %
        phrases.length;
    return phrases[index];
  }

  /// Generate quick motivational phrases for timer completion
  Future<String> generateQuickMotivation({
    required String
        context, // 'rest_complete', 'set_complete', 'workout_complete'
  }) async {
    return quickMotivationPhrase(context);
  }

  /// Build progress analysis prompt
  String _buildProgressAnalysisPrompt(
      List<Workout> workouts, String timeframe) {
    final buffer = StringBuffer();

    buffer
        .writeln('Analyze this user\'s workout progress as a fitness expert.');
    buffer.writeln('');
    buffer.writeln('Timeframe: $timeframe');
    buffer.writeln('Total workouts analyzed: ${workouts.length}');
    buffer.writeln('');

    if (workouts.isNotEmpty) {
      final totalSets = workouts.fold<int>(0, (sum, w) => sum + w.sets.length);
      final avgSetsPerWorkout =
          workouts.isNotEmpty ? totalSets / workouts.length : 0;

      buffer.writeln('Workout Summary:');
      buffer.writeln('- Total sets completed: $totalSets');
      buffer.writeln(
          '- Average sets per workout: ${avgSetsPerWorkout.toStringAsFixed(1)}');
      buffer.writeln(
          '- Workout frequency: ${workouts.length} workouts in $timeframe');
    }

    buffer.writeln('');
    buffer.writeln('Provide insights on:');
    buffer.writeln('- Progress trends and patterns');
    buffer.writeln('- Areas of improvement');
    buffer.writeln('- Recommendations for next steps');
    buffer.writeln('- Motivation and encouragement');
    buffer.writeln('');
    buffer.writeln(
        'Keep the analysis positive, actionable, and under 200 words.');

    return buffer.toString();
  }

  /// Build next workout suggestion prompt
  String _buildNextWorkoutPrompt(
    List<Workout> recentWorkouts,
    int lookbackDays, {
    bool? preferSingleMuscleGroup,
    WorkoutPreferences? preferences,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are an AI fitness coach analyzing workout patterns.');
    buffer.writeln('');
    _writePreferences(buffer, preferences);
    buffer.writeln('User\'s Recent Workout History (last $lookbackDays days):');
    buffer.writeln('');

    if (preferSingleMuscleGroup != null) {
      final preferenceText = preferSingleMuscleGroup
          ? 'single muscle group focus'
          : 'multiple muscle groups / full-body balance';
      buffer.writeln('User preference: $preferenceText.');
      buffer.writeln('');
    }

    if (recentWorkouts.isEmpty) {
      buffer.writeln('No recent workouts found.');
      buffer.writeln('');
      buffer.writeln('Suggest a beginner-friendly full-body workout.');
    } else {
      // Analyze workout patterns
      final workoutsByDay = <String, List<String>>{};
      final exerciseFrequency = <String, int>{};

      for (final workout in recentWorkouts) {
        final dayName = _getDayName(workout.scheduledDate ?? DateTime.now());
        workoutsByDay[dayName] = workout.exerciseIds.toList();

        for (final exerciseId in workout.exerciseIds) {
          exerciseFrequency[exerciseId] =
              (exerciseFrequency[exerciseId] ?? 0) + 1;
        }
      }

      // Build workout pattern description
      buffer.writeln('Workout Pattern Analysis:');
      workoutsByDay.forEach((day, exercises) {
        buffer.writeln('- $day: ${exercises.length} exercises');
      });

      buffer.writeln('');
      buffer.writeln('Most Frequent Exercise Types:');
      final sortedExercises = exerciseFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedExercises.take(5)) {
        buffer.writeln('- ${entry.key}: ${entry.value} times');
      }
    }

    buffer.writeln('');
    buffer.writeln('Requirements for Next Workout Suggestion:');
    buffer.writeln(
        '- Analyze the workout pattern and identify muscle groups trained');
    buffer.writeln(
        '- Suggest the next logical workout based on recovery and balance');
    buffer.writeln('- Consider muscle group rotation and rest periods');
    buffer.writeln(preferences == null
        ? '- Provide 3-5 specific exercise recommendations'
        : '- Provide ${preferences.exerciseCount} specific exercise '
            'recommendations');
    if (preferences != null) {
      buffer.writeln('- Respect every user preference listed above');
    }
    buffer.writeln('- Keep the suggestion concise (under 100 words)');
    buffer.writeln('- Focus on what muscle groups to target next');
    buffer.writeln('- Include reasoning for the suggestion');
    buffer.writeln('');
    buffer.writeln(
        'Format: "Based on your recent [pattern], I suggest focusing on [muscle groups] today. Recommended exercises: [list]. This will [reasoning]."');

    return buffer.toString();
  }

  String _buildAiWorkoutPrompt({
    required String focus,
    required String context,
    WorkoutPreferences? preferences,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are a strength coach building an AI workout.');
    buffer.writeln('');
    buffer.writeln('Workout focus: $focus.');
    buffer.writeln('');
    _writePreferences(buffer, preferences,
        note: 'The chosen workout focus above decides the muscle groups; '
            'apply these where they do not conflict with it.');
    buffer.writeln('Context from recent workouts and progression rules:');
    buffer.writeln(context);
    buffer.writeln('');
    buffer.writeln('Requirements:');
    buffer.writeln(preferences == null
        ? '- Provide 4-6 specific exercise names that match the focus'
        : '- Provide ${preferences.exerciseCount} specific exercise names '
            'that match the focus');
    buffer.writeln(
        '- Only include exercises that directly train the focus muscle groups');
    buffer.writeln('- Avoid repeating the exact same primary muscle groups from the most recent workout unless the focus demands it');
    buffer.writeln('- Mix compound and accessory movements when appropriate');
    buffer.writeln('- Include a brief 1-2 sentence rationale');
    buffer.writeln('- Then list exercises as a bullet list prefixed with "-"');
    buffer.writeln('- Keep total response under 120 words');

    return buffer.toString();
  }

  /// Writes the user's "Workout Suggestions" settings into a prompt.
  void _writePreferences(StringBuffer buffer, WorkoutPreferences? preferences,
      {String? note}) {
    if (preferences == null) return;
    buffer.writeln('User workout preferences (from their settings):');
    for (final line in preferences.describeForPrompt()) {
      buffer.writeln('- $line');
    }
    if (note != null) buffer.writeln(note);
    buffer.writeln('');
  }

  /// Get day name from date
  String _getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }
}

/// Custom exception for AI service errors
class AIServiceException implements Exception {
  final String message;

  AIServiceException(this.message);

  @override
  String toString() => 'AIServiceException: $message';
}
