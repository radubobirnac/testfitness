import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:testfitness/services/api_key_service.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/offline_indicator.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  late final FlutterTts _tts;
  static AIService? _instance;

  AIService._internal() {
    if (!hasApiKey) {
      AppLogger.warning('Gemini API key is not configured; AI features disabled');
    }

    // Initialize FlutterTTS (interim solution until Dart SDK supports Gemini TTS)
    _tts = FlutterTts();
    _initializeTTS();
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

  /// Generate a personalized workout plan
  Future<String> generateWorkoutPlan({
    required String fitnessLevel, // beginner, intermediate, advanced
    required List<String> availableEquipment,
    required int durationMinutes,
    required String
        primaryGoal, // strength, endurance, weight_loss, muscle_gain
    List<Workout>? recentWorkouts,
    List<String>? targetMuscleGroups,
  }) async {
    try {
      AppLogger.info('Generating workout plan with AI');

      final prompt = _buildWorkoutPlanPrompt(
        fitnessLevel: fitnessLevel,
        availableEquipment: availableEquipment,
        durationMinutes: durationMinutes,
        primaryGoal: primaryGoal,
        recentWorkouts: recentWorkouts,
        targetMuscleGroups: targetMuscleGroups,
      );

      final content = [Content.text(prompt)];
      final response = await _requireModel().generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      AppLogger.info('Successfully generated workout plan');
      return response.text!;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to generate workout plan', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to generate workout plan: ${error.toString()}');
    }
  }

  /// Suggest exercise alternatives
  Future<List<String>> suggestExerciseAlternatives({
    required String exerciseName,
    required List<String> availableEquipment,
    String? targetMuscleGroup,
    String? difficultyLevel,
  }) async {
    try {
      AppLogger.info('Getting exercise alternatives for: $exerciseName');

      final prompt = '''
As a fitness expert, suggest 3-5 alternative exercises for "$exerciseName".

Available equipment: ${availableEquipment.join(', ')}
${targetMuscleGroup != null ? 'Target muscle group: $targetMuscleGroup' : ''}
${difficultyLevel != null ? 'Difficulty level: $difficultyLevel' : ''}

Requirements:
- Only use the available equipment listed
- Target the same muscle groups as the original exercise
- Provide exercises of similar difficulty
- Format as a simple list, one exercise per line
- Keep exercise names concise (max 4 words each)

Example format:
- Push-ups
- Dumbbell Chest Press
- Resistance Band Flyes
''';

      final content = [Content.text(prompt)];
      final response = await _requireModel().generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      // Parse the response into a list
      final alternatives = response.text!
          .split('\n')
          .where((line) => line.trim().startsWith('-'))
          .map((line) => line.trim().substring(1).trim())
          .where((exercise) => exercise.isNotEmpty)
          .toList();

      AppLogger.info('Generated ${alternatives.length} exercise alternatives');
      return alternatives;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to get exercise alternatives', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to get exercise alternatives: ${error.toString()}');
    }
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
      final response = await _requireModel().generateContent(content);

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

  /// Generate motivational message based on user's progress
  Future<String> generateMotivationalMessage({
    required int workoutsThisWeek,
    required int totalWorkouts,
    required bool recentlyCompletedWorkout,
    String? currentGoal,
  }) async {
    try {
      AppLogger.info('Generating motivational message');

      final prompt = '''
Generate a short, motivational message (max 2 sentences) for a fitness app user.

User stats:
- Workouts this week: $workoutsThisWeek
- Total workouts: $totalWorkouts
- Recently completed workout: $recentlyCompletedWorkout
${currentGoal != null ? '- Current goal: $currentGoal' : ''}

Requirements:
- Keep it positive and encouraging
- Make it personal based on their progress
- Use emojis sparingly (max 1-2)
- Focus on their achievements and next steps
- Maximum 2 sentences
''';

      final content = [Content.text(prompt)];
      final response = await _requireModel().generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      AppLogger.info('Successfully generated motivational message');
      return response.text!.trim();
    } catch (error, stackTrace) {
      AppLogger.error(
          'Failed to generate motivational message', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to generate motivational message: ${error.toString()}');
    }
  }

  /// Generate next workout suggestion based on user's workout history
  Future<String> suggestNextWorkout({
    required List<Workout> recentWorkouts,
    int lookbackDays = 14,
    bool? preferSingleMuscleGroup,
  }) async {
    try {
      AppLogger.info('Generating next workout suggestion');

      final prompt = _buildNextWorkoutPrompt(
        recentWorkouts,
        lookbackDays,
        preferSingleMuscleGroup: preferSingleMuscleGroup,
      );

      final content = [Content.text(prompt)];
      final response = await _requireModel().generateContent(content);

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
  }) async {
    try {
      AppLogger.info('Generating focused AI workout');

      final prompt = _buildAiWorkoutPrompt(
        focus: focus,
        context: context,
      );

      final content = [Content.text(prompt)];
      final response = await _requireModel().generateContent(content);

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
      final response = await _requireModel().generateContent(content);

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

  /// Generate and speak exercise coaching instructions
  Future<String> generateVoiceCoaching({
    required String exerciseName,
    required String phase, // 'preparation', 'execution', 'rest', 'motivation'
    int? currentSet,
    int? totalSets,
    bool speakAloud = true,
  }) async {
    try {
      AppLogger.info('Generating voice coaching for: $exerciseName ($phase)');

      final prompt = _buildVoiceCoachingPrompt(
        exerciseName: exerciseName,
        phase: phase,
        currentSet: currentSet,
        totalSets: totalSets,
      );

      final content = [Content.text(prompt)];
      final response = await _requireModel().generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw AIServiceException('AI generated empty response');
      }

      final coachingText = response.text!.trim();

      // Speak the coaching instruction if requested
      if (speakAloud) {
        await speakText(coachingText);
      }

      AppLogger.info('Successfully generated voice coaching');
      return coachingText;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to generate voice coaching', error, stackTrace);
      if (error is AIServiceException) rethrow;
      throw AIServiceException(
          'Failed to generate voice coaching: ${error.toString()}');
    }
  }

  /// Initialize TTS settings (improved FlutterTTS until Gemini TTS is available)
  Future<void> _initializeTTS() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.6); // Slightly faster for better experience
      await _tts.setVolume(0.9); // Louder for gym environment
      await _tts.setPitch(1.1); // Slightly higher pitch for motivation

      // Try to set a better voice if available
      final voices = await _tts.getVoices;
      if (voices.isNotEmpty) {
        // Look for a more natural voice
        final preferredVoices = voices
            .where((voice) =>
                voice['name'].toString().toLowerCase().contains('enhanced') ||
                voice['name'].toString().toLowerCase().contains('neural') ||
                voice['name'].toString().toLowerCase().contains('premium'))
            .toList();

        if (preferredVoices.isNotEmpty) {
          await _tts.setVoice(preferredVoices.first);
          AppLogger.info(
              'Using enhanced voice: ${preferredVoices.first['name']}');
        }
      }

      AppLogger.info('Enhanced TTS initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize enhanced TTS', e);
    }
  }

  /// Speak text using enhanced FlutterTTS (interim until Gemini TTS available)
  Future<void> speakText(String text) async {
    try {
      // Clean text for better TTS pronunciation
      final cleanText = text
          .replaceAll(
              RegExp(r'[^\w\s.,!?]'), '') // Remove emojis and special chars
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();

      if (cleanText.isEmpty) return;

      await _tts.speak(cleanText);
      AppLogger.info(
          'Speaking enhanced TTS: ${cleanText.substring(0, cleanText.length > 50 ? 50 : cleanText.length)}...');
    } catch (e) {
      AppLogger.error('Failed to speak text with enhanced TTS', e);
    }
  }

  /// Stop current TTS speech
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      AppLogger.info('Stopped TTS speech');
    } catch (e) {
      AppLogger.error('Failed to stop TTS', e);
    }
  }

  /// Generate quick motivational phrases for timer completion
  Future<String> generateQuickMotivation({
    required String
        context, // 'rest_complete', 'set_complete', 'workout_complete'
    bool speakAloud = true,
  }) async {
    try {
      final motivationPhrases = {
        'rest_complete': [
          'Let\'s Go! 💪',
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

      final phrases =
          motivationPhrases[context] ?? motivationPhrases['rest_complete']!;
      final randomPhrase =
          phrases[(DateTime.now().millisecondsSinceEpoch % phrases.length)];

      if (speakAloud) {
        await speakText(randomPhrase.replaceAll(
            RegExp(r'[^\w\s]'), '')); // Remove emojis for TTS
      }

      return randomPhrase;
    } catch (e) {
      AppLogger.error('Failed to generate quick motivation', e);
      return 'Keep Going! 💪';
    }
  }

  /// Build workout plan prompt
  String _buildWorkoutPlanPrompt({
    required String fitnessLevel,
    required List<String> availableEquipment,
    required int durationMinutes,
    required String primaryGoal,
    List<Workout>? recentWorkouts,
    List<String>? targetMuscleGroups,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('Create a personalized workout plan as a fitness expert.');
    buffer.writeln('');
    buffer.writeln('User Profile:');
    buffer.writeln('- Fitness Level: $fitnessLevel');
    buffer.writeln('- Available Equipment: ${availableEquipment.join(', ')}');
    buffer.writeln('- Workout Duration: $durationMinutes minutes');
    buffer.writeln('- Primary Goal: $primaryGoal');

    if (targetMuscleGroups != null && targetMuscleGroups.isNotEmpty) {
      buffer
          .writeln('- Target Muscle Groups: ${targetMuscleGroups.join(', ')}');
    }

    if (recentWorkouts != null && recentWorkouts.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Recent Workouts (for variety):');
      for (final workout in recentWorkouts.take(3)) {
        buffer.writeln('- ${workout.name} (${workout.sets.length} exercises)');
      }
    }

    buffer.writeln('');
    buffer.writeln('Requirements:');
    buffer.writeln('- Only use the available equipment listed');
    buffer.writeln('- Match the specified fitness level');
    buffer.writeln('- Design for the exact duration specified');
    buffer.writeln('- Include warm-up and cool-down');
    buffer.writeln('- Provide sets, reps, and rest periods');
    buffer.writeln('- Format as a clear, structured workout plan');
    buffer.writeln('- Include brief exercise descriptions for proper form');

    return buffer.toString();
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

  /// Build voice coaching prompt
  String _buildVoiceCoachingPrompt({
    required String exerciseName,
    required String phase,
    int? currentSet,
    int? totalSets,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are an AI fitness coach providing voice guidance.');
    buffer.writeln('');
    buffer.writeln('Exercise: $exerciseName');
    buffer.writeln('Phase: $phase');

    if (currentSet != null && totalSets != null) {
      buffer.writeln('Progress: Set $currentSet of $totalSets');
    }

    buffer.writeln('');

    switch (phase) {
      case 'preparation':
        buffer.writeln('Provide brief setup instructions for proper form.');
        buffer.writeln('Keep it under 15 words, focus on key form cues.');
        break;
      case 'execution':
        buffer.writeln('Give encouraging coaching during the exercise.');
        buffer.writeln('Focus on form, breathing, and motivation.');
        buffer.writeln('Keep it under 20 words, energetic tone.');
        break;
      case 'rest':
        buffer.writeln('Provide rest period guidance and encouragement.');
        buffer.writeln('Mention recovery and preparation for next set.');
        buffer.writeln('Keep it under 15 words, calm but motivating.');
        break;
      case 'motivation':
        buffer.writeln('Give a motivational boost to push through fatigue.');
        buffer.writeln('High energy, encouraging, under 10 words.');
        break;
    }

    buffer.writeln('');
    buffer.writeln('Requirements:');
    buffer.writeln('- Use simple, clear language');
    buffer.writeln('- Sound like a supportive personal trainer');
    buffer.writeln('- No technical jargon');
    buffer.writeln('- Appropriate for text-to-speech');
    buffer.writeln('- Return only the coaching phrase, no extra text');

    return buffer.toString();
  }

  /// Build next workout suggestion prompt
  String _buildNextWorkoutPrompt(
    List<Workout> recentWorkouts,
    int lookbackDays, {
    bool? preferSingleMuscleGroup,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are an AI fitness coach analyzing workout patterns.');
    buffer.writeln('');
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
    buffer.writeln('- Provide 3-5 specific exercise recommendations');
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
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are a strength coach building an AI workout.');
    buffer.writeln('');
    buffer.writeln('Workout focus: $focus.');
    buffer.writeln('');
    buffer.writeln('Context from recent workouts and progression rules:');
    buffer.writeln(context);
    buffer.writeln('');
    buffer.writeln('Requirements:');
    buffer.writeln('- Provide 4-6 specific exercise names that match the focus');
    buffer.writeln(
        '- Only include exercises that directly train the focus muscle groups');
    buffer.writeln('- Avoid repeating the exact same primary muscle groups from the most recent workout unless the focus demands it');
    buffer.writeln('- Mix compound and accessory movements when appropriate');
    buffer.writeln('- Include a brief 1-2 sentence rationale');
    buffer.writeln('- Then list exercises as a bullet list prefixed with "-"');
    buffer.writeln('- Keep total response under 120 words');

    return buffer.toString();
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
