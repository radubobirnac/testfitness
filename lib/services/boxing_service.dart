import 'dart:async';
import 'package:testfitness/services/boxing_audio_controller.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Boxing combinations service for cardio workouts
/// Supports Traditional, Cuban, and Soviet boxing styles
/// Generates and calls out boxing combinations with high-quality audio
class BoxingService {
  static BoxingService? _instance;
  final BoxingAudioController _audioController = BoxingAudioController();
  Timer? _roundTimer;
  Timer? _restTimer;
  Timer? _combinationTimer;

  // Boxing styles and their progressive combination chains
  static const Map<String, Map<String, List<List<String>>>> _boxingStyles = {
    'traditional': {
      'beginner': [
        // Chain 1: Basic jab-cross progression
        ['1-2', '1-2-3', '1-2-3-2'],
        // Chain 2: Hook combinations
        ['2-3', '2-3-4', '2-3-4-3'],
        // Chain 3: Basic defense
        ['1-2', '1-2-slip', '1-2-slip-2'],
        // Chain 4: Uppercut introduction
        ['1-2', '1-2-5', '1-2-5-6'],
        // Chain 5: Simple patterns
        ['3-4', '3-4-3', '3-4-3-2'],
      ],
      'intermediate': [
        // Chain 1: Progressive jab-cross building
        ['1-2', '1-2-slip', '1-2-slip-2', '1-2-slip-2-3'],
        // Chain 2: Hook progression with defense
        ['2-3', '2-3-roll', '2-3-roll-2', '2-3-roll-2-4'],
        // Chain 3: Building uppercut combinations
        ['1-6', '1-6-3', '1-6-3-2', '1-6-3-2-slip'],
        // Chain 4: Progressive defense patterns
        ['3-slip', '3-slip-2', '3-slip-2-1', '3-slip-2-1-4'],
        // Chain 5: Complex building sequences
        ['2-duck', '2-duck-3', '2-duck-3-4', '2-duck-3-4-roll'],
        // Chain 6: Power combination building
        ['1-2-3', '1-2-3-duck', '1-2-3-duck-4', '1-2-3-duck-4-2'],
        // Chain 7: Advanced flow patterns
        ['5-2', '5-2-slip', '5-2-slip-3', '5-2-slip-3-4'],
        // Chain 8: Multi-level progressions
        ['3-4-roll', '3-4-roll-1', '3-4-roll-1-2', '3-4-roll-1-2-slip'],
      ],
      'advanced': [
        // Chain 1: Complex jab-cross with multiple defenses
        ['1-2-slip-2', '1-2-slip-2-3', '1-2-slip-2-3-4', '1-2-slip-2-3-4-roll'],
        // Chain 2: Advanced hook combinations
        ['3-2-roll', '3-2-roll-4', '3-2-roll-4-3', '3-2-roll-4-3-slip-2'],
        // Chain 3: Uppercut power combinations
        ['1-6-3', '1-6-3-2', '1-6-3-2-duck-4', '1-6-3-2-duck-4-3'],
        // Chain 4: Defense-heavy patterns
        [
          '2-slip-2-3',
          '2-slip-2-3-roll',
          '2-slip-2-3-roll-4',
          '2-slip-2-3-roll-4-5'
        ],
        // Chain 5: Multi-level combinations
        [
          '1-2-3-parry',
          '1-2-3-parry-2',
          '1-2-3-parry-2-4',
          '1-2-3-parry-2-4-3'
        ],
        // Chain 6: Power finishing sequences
        ['5-2-slip-3', '5-2-slip-3-4', '5-2-slip-3-4-2', '5-2-slip-3-4-2-roll'],
      ],
    },
    'cuban': {
      'beginner': [
        // Cuban style emphasizes rhythm, footwork, and counter-punching
        // Chain 1: Rhythmic jab combinations
        ['1', '1-1', '1-1-2', '1-1-2-3'],
        // Chain 2: Counter-punch patterns
        ['2-1', '2-1-3', '2-1-3-2'],
        // Chain 3: Footwork with punches
        ['1-step', '1-step-2', '1-step-2-3'],
        // Chain 4: Cuban rhythm patterns
        ['1-2-1', '1-2-1-3', '1-2-1-3-2'],
        // Chain 5: Basic Cuban combinations
        ['3-2-1', '3-2-1-2', '3-2-1-2-3'],
      ],
      'intermediate': [
        // Chain 1: Advanced Cuban rhythm
        ['1-1-2', '1-1-2-slip', '1-1-2-slip-3', '1-1-2-slip-3-2'],
        // Chain 2: Counter-attack sequences
        ['slip-2-3', 'slip-2-3-2', 'slip-2-3-2-1', 'slip-2-3-2-1-3'],
        // Chain 3: Cuban footwork combinations
        [
          '1-step-2-3',
          '1-step-2-3-step',
          '1-step-2-3-step-2',
          '1-step-2-3-step-2-1'
        ],
        // Chain 4: Rhythmic defense patterns
        ['duck-1-2', 'duck-1-2-3', 'duck-1-2-3-slip', 'duck-1-2-3-slip-2'],
        // Chain 5: Cuban flow combinations
        ['3-1-2-3', '3-1-2-3-1', '3-1-2-3-1-2', '3-1-2-3-1-2-3'],
        // Chain 6: Advanced counter patterns
        ['parry-2-3', 'parry-2-3-1', 'parry-2-3-1-2', 'parry-2-3-1-2-3'],
      ],
      'advanced': [
        // Chain 1: Master Cuban rhythm
        [
          '1-1-2-slip-3-2',
          '1-1-2-slip-3-2-1',
          '1-1-2-slip-3-2-1-3',
          '1-1-2-slip-3-2-1-3-2'
        ],
        // Chain 2: Complex counter-attacks
        [
          'slip-duck-2-3-1',
          'slip-duck-2-3-1-2',
          'slip-duck-2-3-1-2-3',
          'slip-duck-2-3-1-2-3-1'
        ],
        // Chain 3: Cuban master combinations
        [
          '3-1-2-slip-3-1',
          '3-1-2-slip-3-1-2',
          '3-1-2-slip-3-1-2-3',
          '3-1-2-slip-3-1-2-3-1'
        ],
        // Chain 4: Advanced footwork patterns
        [
          'step-1-2-3-step-2',
          'step-1-2-3-step-2-1',
          'step-1-2-3-step-2-1-3',
          'step-1-2-3-step-2-1-3-2'
        ],
        // Chain 5: Elite Cuban sequences
        [
          'parry-slip-2-3-1-2',
          'parry-slip-2-3-1-2-3',
          'parry-slip-2-3-1-2-3-1',
          'parry-slip-2-3-1-2-3-1-2'
        ],
      ],
    },
    'soviet': {
      'beginner': [
        // Soviet style emphasizes technical precision, conditioning, and systematic approach
        // Chain 1: Technical jab sequences
        ['1', '1-2', '1-2-1', '1-2-1-2'],
        // Chain 2: Systematic power building
        ['2', '2-3', '2-3-2', '2-3-2-3'],
        // Chain 3: Soviet conditioning patterns
        ['1-2-3', '1-2-3-2', '1-2-3-2-1', '1-2-3-2-1-2'],
        // Chain 4: Technical defense introduction
        ['1-block', '1-block-2', '1-block-2-3'],
        // Chain 5: Soviet systematic approach
        ['3-2', '3-2-1', '3-2-1-2', '3-2-1-2-3'],
      ],
      'intermediate': [
        // Chain 1: Soviet technical combinations
        ['1-2-1-2', '1-2-1-2-3', '1-2-1-2-3-2', '1-2-1-2-3-2-1'],
        // Chain 2: Systematic defense patterns
        ['block-2-3', 'block-2-3-2', 'block-2-3-2-1', 'block-2-3-2-1-2'],
        // Chain 3: Soviet power sequences
        ['2-3-2-3', '2-3-2-3-2', '2-3-2-3-2-1', '2-3-2-3-2-1-2'],
        // Chain 4: Technical conditioning
        ['1-2-3-2-1', '1-2-3-2-1-2', '1-2-3-2-1-2-3', '1-2-3-2-1-2-3-2'],
        // Chain 5: Soviet methodical approach
        ['3-2-1-2-3', '3-2-1-2-3-2', '3-2-1-2-3-2-1', '3-2-1-2-3-2-1-2'],
        // Chain 6: Advanced technical patterns
        [
          'block-1-2-3',
          'block-1-2-3-2',
          'block-1-2-3-2-1',
          'block-1-2-3-2-1-2'
        ],
      ],
      'advanced': [
        // Chain 1: Master Soviet combinations
        [
          '1-2-1-2-3-2-1',
          '1-2-1-2-3-2-1-2',
          '1-2-1-2-3-2-1-2-3',
          '1-2-1-2-3-2-1-2-3-2'
        ],
        // Chain 2: Elite technical sequences
        [
          'block-2-3-2-1-2',
          'block-2-3-2-1-2-3',
          'block-2-3-2-1-2-3-2',
          'block-2-3-2-1-2-3-2-1'
        ],
        // Chain 3: Soviet conditioning mastery
        [
          '2-3-2-3-2-1-2',
          '2-3-2-3-2-1-2-3',
          '2-3-2-3-2-1-2-3-2',
          '2-3-2-3-2-1-2-3-2-1'
        ],
        // Chain 4: Advanced systematic approach
        [
          '3-2-1-2-3-2-1-2',
          '3-2-1-2-3-2-1-2-3',
          '3-2-1-2-3-2-1-2-3-2',
          '3-2-1-2-3-2-1-2-3-2-1'
        ],
        // Chain 5: Master technical patterns
        [
          'block-1-2-3-2-1-2',
          'block-1-2-3-2-1-2-3',
          'block-1-2-3-2-1-2-3-2',
          'block-1-2-3-2-1-2-3-2-1'
        ],
      ],
    },
  };

  // Progressive combination state
  int _currentChainIndex = 0;
  int _roundStartTime = 0;
  String _currentStyle = 'traditional'; // Default to traditional style

  BoxingService._internal();

  factory BoxingService() {
    _instance ??= BoxingService._internal();
    return _instance!;
  }

  /// Start a boxing cardio session
  Future<void> startBoxingSession({
    required String style,
    required String difficulty,
    required int roundDurationSeconds,
    required int restDurationSeconds,
    required int totalRounds,
    required Function(String) onCombinationCall,
    required Function(int) onRoundComplete,
    required Function() onSessionComplete,
    required Function(int) onRestStart,
    int combinationIntervalSeconds = 4,
  }) async {
    try {
      AppLogger.info(
          'Starting boxing session: $style $difficulty, $totalRounds rounds');

      // Set current style
      _currentStyle = style;
      int currentRound = 1;

      // Countdown before starting
      await _audioController.playCountdown();

      await _startRound(
        style: style,
        difficulty: difficulty,
        roundDurationSeconds: roundDurationSeconds,
        restDurationSeconds: restDurationSeconds,
        currentRound: currentRound,
        totalRounds: totalRounds,
        onCombinationCall: onCombinationCall,
        onRoundComplete: onRoundComplete,
        onSessionComplete: onSessionComplete,
        onRestStart: onRestStart,
        combinationIntervalSeconds: combinationIntervalSeconds,
      );
    } catch (e) {
      AppLogger.error('Failed to start boxing session', e);
      rethrow;
    }
  }

  /// Start a single round
  Future<void> _startRound({
    required String style,
    required String difficulty,
    required int roundDurationSeconds,
    required int restDurationSeconds,
    required int currentRound,
    required int totalRounds,
    required Function(String) onCombinationCall,
    required Function(int) onRoundComplete,
    required Function() onSessionComplete,
    required Function(int) onRestStart,
    required int combinationIntervalSeconds,
  }) async {
    // Initialize progressive combination state for new round
    _initializeProgressiveRound();

    // Announce round start using high-quality audio
    await _audioController.announceRoundStart(currentRound);

    // Start calling progressive combinations during the round
    _startProgressiveCombinationCalls(difficulty, onCombinationCall,
        intervalSeconds: combinationIntervalSeconds);

    // Set round timer
    _roundTimer = Timer(Duration(seconds: roundDurationSeconds), () async {
      _stopCombinationCalls();
      // NO round complete announcement - user wants minimal audio
      onRoundComplete(currentRound);

      if (currentRound < totalRounds) {
        // Start rest period
        onRestStart(restDurationSeconds);
        // NO rest announcement - user wants minimal audio

        _restTimer = Timer(Duration(seconds: restDurationSeconds), () async {
          await _startRound(
            style: style,
            difficulty: difficulty,
            roundDurationSeconds: roundDurationSeconds,
            restDurationSeconds: restDurationSeconds,
            currentRound: currentRound + 1,
            totalRounds: totalRounds,
            onCombinationCall: onCombinationCall,
            onRoundComplete: onRoundComplete,
            onSessionComplete: onSessionComplete,
            onRestStart: onRestStart,
            combinationIntervalSeconds: combinationIntervalSeconds,
          );
        });
      } else {
        // Session complete - NO announcement
        onSessionComplete();
      }
    });
  }

  /// Initialize progressive combination state for a new round
  void _initializeProgressiveRound() {
    _currentChainIndex = 0;
    _roundStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Start calling out progressive combinations at intervals
  void _startProgressiveCombinationCalls(
      String difficulty, Function(String) onCombinationCall,
      {int intervalSeconds = 4}) {
    final callInterval = Duration(seconds: intervalSeconds);

    _combinationTimer = Timer.periodic(callInterval, (timer) {
      final combination = _getNextProgressiveCombination(difficulty);

      onCombinationCall(combination);
      _audioController.callCombination(combination);
    });
  }

  /// Get the next combination in the progressive sequence
  String _getNextProgressiveCombination(String difficulty) {
    final styleData = _boxingStyles[_currentStyle];
    if (styleData == null) return '1-2'; // Fallback

    final chains = styleData[difficulty] ?? styleData['beginner']!;

    if (chains.isEmpty) return '1-2'; // Fallback

    // Calculate progression based on time elapsed in round
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (currentTime - _roundStartTime) / 1000;

    // Get current chain
    final currentChain = chains[_currentChainIndex % chains.length];

    // Progressive building within each chain - every 4 seconds advance to next step
    final stepInterval = 4; // seconds between progression steps
    final currentStep = (elapsedSeconds / stepInterval).floor();

    // If we've completed the current chain, move to next chain
    if (currentStep >= currentChain.length) {
      _currentChainIndex = (_currentChainIndex + 1) % chains.length;
      _roundStartTime = currentTime.toInt(); // Reset timer for new chain
      return chains[_currentChainIndex][0]; // Start new chain
    }

    // Return the current step in the progression
    final stepIndex = currentStep.clamp(0, currentChain.length - 1);
    return currentChain[stepIndex];
  }

  /// Stop calling combinations
  void _stopCombinationCalls() {
    _combinationTimer?.cancel();
    _combinationTimer = null;
  }

  /// Stop the current boxing session
  void stopSession() {
    AppLogger.info('Stopping boxing session');
    _roundTimer?.cancel();
    _restTimer?.cancel();
    _combinationTimer?.cancel();

    _roundTimer = null;
    _restTimer = null;
    _combinationTimer = null;
  }

  /// Pause the current session
  void pauseSession() {
    AppLogger.info('Pausing boxing session');
    _combinationTimer?.cancel();
    _combinationTimer = null;
  }

  /// Resume the current session
  void resumeSession(String difficulty, Function(String) onCombinationCall,
      {int intervalSeconds = 4}) {
    AppLogger.info('Resuming boxing session');
    _startProgressiveCombinationCalls(difficulty, onCombinationCall,
        intervalSeconds: intervalSeconds);
  }

  /// Get available boxing styles
  List<String> getBoxingStyles() {
    return _boxingStyles.keys.toList();
  }

  /// Get available difficulty levels for current style
  List<String> getDifficultyLevels([String? style]) {
    final currentStyleData = _boxingStyles[style ?? _currentStyle];
    if (currentStyleData == null) {
      return ['beginner', 'intermediate', 'advanced'];
    }
    return currentStyleData.keys.toList();
  }

  /// Get sample combinations for a difficulty level and style
  List<String> getSampleCombinations(String difficulty, [String? style]) {
    final currentStyleData = _boxingStyles[style ?? _currentStyle];
    if (currentStyleData == null) return [];

    final chains = currentStyleData[difficulty] ?? [];
    final List<String> allCombinations = [];

    for (final chain in chains) {
      allCombinations.addAll(chain);
    }

    return allCombinations;
  }

  /// Set the current boxing style
  void setBoxingStyle(String style) {
    if (_boxingStyles.containsKey(style)) {
      _currentStyle = style;
    }
  }

  /// Get the current boxing style
  String getCurrentStyle() {
    return _currentStyle;
  }

  /// Dispose of the service
  void dispose() {
    stopSession();
    _instance = null;
  }
}

/// Exception for boxing service errors
class BoxingServiceException implements Exception {
  final String message;
  BoxingServiceException(this.message);

  @override
  String toString() => 'BoxingServiceException: $message';
}
