import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:testfitness/services/boxing_audio_controller.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Boxing combinations service for cardio workouts
/// Supports Traditional, Cuban, and Soviet boxing styles
/// Generates and calls out boxing combinations with high-quality audio
class BoxingService {
  static BoxingService? _instance;
  Timer? _phaseTimer; // Round or rest timer (only one phase runs at a time)
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

  // Session state machine
  final BoxingAudio _audio;
  final DateTime Function() _now;
  _BoxingSessionConfig? _config;
  BoxingPhase _phase = BoxingPhase.idle;
  bool _isPaused = false;
  int _currentRound = 0;

  /// Incremented whenever a session is started or stopped so that async
  /// continuations (countdown, round announcement) from a stale session bail.
  int _sessionToken = 0;

  /// Wall-clock time at which the current round/rest phase ends.
  DateTime? _phaseEndsAt;

  /// Remaining time of the current phase, captured when paused.
  Duration? _pausedRemaining;
  DateTime? _pausedAt;

  BoxingService._internal(this._audio, this._now);

  factory BoxingService() {
    _instance ??= BoxingService._internal(
        _ControllerBoxingAudio(BoxingAudioController()), DateTime.now);
    return _instance!;
  }

  /// Creates a standalone (non-singleton) instance with injected audio and
  /// clock, for tests.
  @visibleForTesting
  factory BoxingService.test({
    required BoxingAudio audio,
    DateTime Function()? now,
  }) =>
      BoxingService._internal(audio, now ?? DateTime.now);

  /// Current phase of the session.
  BoxingPhase get phase => _phase;

  /// Whether the session is paused.
  bool get isPaused => _isPaused;

  /// Round currently in progress (or the round just finished while resting).
  int get currentRound => _currentRound;

  /// Time left in the current round/rest phase, or null when not timing.
  Duration? get phaseRemaining {
    if (_isPaused) return _pausedRemaining;
    if (_phaseEndsAt == null) return null;
    return _remainingAt(_now());
  }

  Duration _remainingAt(DateTime time) {
    final endsAt = _phaseEndsAt;
    if (endsAt == null) return Duration.zero;
    final remaining = endsAt.difference(time);
    return remaining.isNegative ? Duration.zero : remaining;
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
    Function(int)? onRoundStart,
    int combinationIntervalSeconds = 4,
  }) async {
    try {
      AppLogger.info(
          'Starting boxing session: $style $difficulty, $totalRounds rounds');

      // Make sure nothing from a previous session is still running.
      _cancelAllTimers();
      final token = ++_sessionToken;

      _currentStyle = style;
      _config = _BoxingSessionConfig(
        difficulty: difficulty,
        roundDuration: Duration(seconds: roundDurationSeconds),
        restDuration: Duration(seconds: restDurationSeconds),
        totalRounds: totalRounds,
        combinationInterval: Duration(seconds: combinationIntervalSeconds),
        onCombinationCall: onCombinationCall,
        onRoundComplete: onRoundComplete,
        onSessionComplete: onSessionComplete,
        onRestStart: onRestStart,
        onRoundStart: onRoundStart,
      );
      _phase = BoxingPhase.countdown;
      _isPaused = false;
      _pausedRemaining = null;
      _pausedAt = null;
      _currentRound = 0;

      // Countdown before starting
      await _audio.playCountdown();
      if (token != _sessionToken) return; // Stopped during countdown

      await _beginRound(1, token);
    } catch (e) {
      AppLogger.error('Failed to start boxing session', e);
      rethrow;
    }
  }

  /// Start a single round
  Future<void> _beginRound(int round, int token) async {
    final config = _config;
    if (config == null || token != _sessionToken) return;

    _currentRound = round;
    _phase = BoxingPhase.round;
    _phaseEndsAt = null;
    _initializeProgressiveRound();
    config.onRoundStart?.call(round);

    // Announce round start using high-quality audio
    await _audio.announceRoundStart(round);
    if (token != _sessionToken) return;

    if (_isPaused) {
      // Paused during countdown/announcement: start the round frozen.
      _pausedRemaining = config.roundDuration;
      _pausedAt = _now();
      return;
    }

    _schedulePhaseEnd(config.roundDuration);
    _startProgressiveCombinationCalls();
  }

  /// (Re)arm the single phase timer. Always cancels any previous one first.
  void _schedulePhaseEnd(Duration duration) {
    _phaseTimer?.cancel();
    _phaseEndsAt = _now().add(duration);
    final token = _sessionToken;
    _phaseTimer = Timer(duration, () => _onPhaseEnded(token));
  }

  void _onPhaseEnded(int token) {
    _phaseTimer = null;
    _phaseEndsAt = null;
    final config = _config;
    if (config == null || token != _sessionToken || _isPaused) return;

    if (_phase == BoxingPhase.round) {
      _stopCombinationCalls();
      // NO round complete announcement - user wants minimal audio
      config.onRoundComplete(_currentRound);

      if (_currentRound < config.totalRounds) {
        _phase = BoxingPhase.rest;
        config.onRestStart(config.restDuration.inSeconds);
        _schedulePhaseEnd(config.restDuration);
      } else {
        _phase = BoxingPhase.complete;
        _config = null;
        config.onSessionComplete();
      }
    } else if (_phase == BoxingPhase.rest) {
      _beginRound(_currentRound + 1, token);
    }
  }

  /// Initialize progressive combination state for a new round
  void _initializeProgressiveRound() {
    _currentChainIndex = 0;
    _roundStartTime = _now().millisecondsSinceEpoch;
  }

  /// Start calling out progressive combinations at intervals.
  /// Always cancels any previous combination timer first.
  void _startProgressiveCombinationCalls() {
    final config = _config;
    if (config == null) return;
    _combinationTimer?.cancel();
    final token = _sessionToken;
    _combinationTimer = Timer.periodic(config.combinationInterval, (timer) {
      if (token != _sessionToken ||
          _isPaused ||
          _phase != BoxingPhase.round) {
        timer.cancel();
        return;
      }
      final combination = _getNextProgressiveCombination(config.difficulty);
      config.onCombinationCall(combination);
      _audio.callCombination(combination);
    });
  }

  /// Get the next combination in the progressive sequence
  String _getNextProgressiveCombination(String difficulty) {
    final styleData = _boxingStyles[_currentStyle];
    if (styleData == null) return '1-2'; // Fallback

    final chains = styleData[difficulty] ?? styleData['beginner']!;

    if (chains.isEmpty) return '1-2'; // Fallback

    // Calculate progression based on time elapsed in round
    final currentTime = _now().millisecondsSinceEpoch;
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

  void _cancelAllTimers() {
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _stopCombinationCalls();
    _phaseEndsAt = null;
  }

  /// Stop the current boxing session: cancels every timer, invalidates any
  /// pending async continuation and silences TTS.
  void stopSession() {
    AppLogger.info('Stopping boxing session');
    _sessionToken++;
    _cancelAllTimers();
    _config = null;
    _phase = BoxingPhase.idle;
    _isPaused = false;
    _pausedRemaining = null;
    _pausedAt = null;
    _currentRound = 0;
    _audio.stopAll();
  }

  /// Pause the current session, freezing the round/rest clock.
  void pauseSession() {
    if (_isPaused) return;
    if (_phase != BoxingPhase.countdown &&
        _phase != BoxingPhase.round &&
        _phase != BoxingPhase.rest) {
      return;
    }
    AppLogger.info('Pausing boxing session');
    final now = _now();
    _isPaused = true;
    _pausedAt = now;
    // Null while still in countdown; _beginRound fills it in that case.
    _pausedRemaining = _phaseTimer != null ? _remainingAt(now) : null;
    _cancelAllTimers();
    _audio.stopAll();
  }

  /// Resume a paused session from where the current phase was frozen.
  void resumeSession() {
    if (!_isPaused) return;
    AppLogger.info('Resuming boxing session');
    _isPaused = false;

    final pausedAt = _pausedAt;
    if (pausedAt != null) {
      // Shift the combination progression so paused time doesn't count.
      _roundStartTime += _now().difference(pausedAt).inMilliseconds;
    }
    final remaining = _pausedRemaining;
    _pausedRemaining = null;
    _pausedAt = null;

    // Still in countdown: _beginRound will start the round normally.
    if (remaining == null) return;

    _schedulePhaseEnd(remaining);
    if (_phase == BoxingPhase.round) {
      _startProgressiveCombinationCalls();
    }
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
    if (identical(_instance, this)) _instance = null;
  }
}

/// Exception for boxing service errors
class BoxingServiceException implements Exception {
  final String message;
  BoxingServiceException(this.message);

  @override
  String toString() => 'BoxingServiceException: $message';
}

/// Phases of a boxing session.
enum BoxingPhase { idle, countdown, round, rest, complete }

/// Audio output used by [BoxingService]; abstracted so it can be faked in tests.
abstract class BoxingAudio {
  Future<void> playCountdown();
  Future<void> announceRoundStart(int roundNumber);
  Future<void> callCombination(String combination);
  Future<void> stopAll();
}

class _ControllerBoxingAudio implements BoxingAudio {
  final BoxingAudioController _controller;
  _ControllerBoxingAudio(this._controller);

  @override
  Future<void> playCountdown() => _controller.playCountdown();
  @override
  Future<void> announceRoundStart(int roundNumber) =>
      _controller.announceRoundStart(roundNumber);
  @override
  Future<void> callCombination(String combination) =>
      _controller.callCombination(combination);
  @override
  Future<void> stopAll() => _controller.stopAll();
}

class _BoxingSessionConfig {
  final String difficulty;
  final Duration roundDuration;
  final Duration restDuration;
  final int totalRounds;
  final Duration combinationInterval;
  final Function(String) onCombinationCall;
  final Function(int) onRoundComplete;
  final Function() onSessionComplete;
  final Function(int) onRestStart;
  final Function(int)? onRoundStart;

  _BoxingSessionConfig({
    required this.difficulty,
    required this.roundDuration,
    required this.restDuration,
    required this.totalRounds,
    required this.combinationInterval,
    required this.onCombinationCall,
    required this.onRoundComplete,
    required this.onSessionComplete,
    required this.onRestStart,
    this.onRoundStart,
  });
}
