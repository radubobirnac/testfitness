import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:testfitness/services/rest_timer_manager.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/audio_player_util.dart';

/// A fullscreen timer that shows a countdown for rest periods between sets
class RestTimerScreen extends StatefulWidget {
  /// Total duration of the timer in seconds
  final int durationSeconds;

  /// Callback when timer completes
  final VoidCallback? onComplete;

  /// Whether to show motivational phrases
  final bool showMotivationalPhrases;

  /// Whether to allow watch buzz (via phone notifications) for this timer
  final bool enableWatchBuzz;

  const RestTimerScreen({
    super.key,
    required this.durationSeconds,
    this.onComplete,
    this.showMotivationalPhrases = true,
    this.enableWatchBuzz = true,
  });

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> {
  final RestTimerManager _timerManager = RestTimerManager();
  final AudioPlayerUtil _audioPlayer = AudioPlayerUtil();
  StreamSubscription<RestTimerState>? _subscription;

  RestTimerState _timerState = const RestTimerState.idle();
  String? _motivationalPhrase;
  bool _watchBuzzEnabled = true;
  bool _completionHandled = false;
  int? _lastRemainingSeconds;
  bool _ticksActive = false;

  // List of motivational phrases to show when timer ends or is close to ending
  final List<String> _motivationalPhrases = [
    "Beast Mode! 💪",
    "Crush It! 🔥",
    "Let's Go! 🚀",
    "You Got This! ⚡",
    "Time to Shine! ✨"
  ];

  @override
  void initState() {
    super.initState();
    _watchBuzzEnabled = widget.enableWatchBuzz;

    _audioPlayer.setOnTimerComplete(() {
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    });

    _subscription = _timerManager.stream.listen(_handleTimerState);
    _startTimer();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _audioPlayer.stopPeriodicTicks();
    _audioPlayer.stopSound();
    _timerManager.stop();
    super.dispose();
  }

  void _handleTimerState(RestTimerState state) {
    if (!mounted) return;

    final remainingSeconds =
        state.remainingMs > 0 ? (state.remainingMs / 1000).ceil() : 0;
    String? motivationalPhrase = _motivationalPhrase;

    if (state.isRunning && !_ticksActive && widget.durationSeconds > 30) {
      _audioPlayer.startPeriodicTicks(intervalSeconds: 15);
      _ticksActive = true;
    } else if (!state.isRunning && _ticksActive) {
      _audioPlayer.stopPeriodicTicks();
      _ticksActive = false;
    }

    if (state.isRunning && remainingSeconds <= 5) {
      _audioPlayer.prepareForBackgroundAudio();
    }

    if (state.isRunning &&
        remainingSeconds == 3 &&
        widget.showMotivationalPhrases &&
        _lastRemainingSeconds != remainingSeconds) {
      motivationalPhrase = _randomMotivationalPhrase();
    }

    if (state.isCompleted && !_completionHandled) {
      _completionHandled = true;
      if (widget.showMotivationalPhrases) {
        motivationalPhrase = _randomMotivationalPhrase();
      }
      if (!state.completedWhileBackgrounded) {
        _audioPlayer.playTimerEndSound(
          useNotification: _watchBuzzEnabled,
        );
      }
    }

    if (state.isRunning) {
      _completionHandled = false;
    }

    setState(() {
      _timerState = state;
      _motivationalPhrase = motivationalPhrase;
    });

    _lastRemainingSeconds = remainingSeconds;
  }

  Future<void> _startTimer() async {
    await _timerManager.start(
      durationSeconds: widget.durationSeconds,
      notificationsEnabled: _watchBuzzEnabled,
    );
    _audioPlayer.playTimerStartSound();

    if (widget.durationSeconds > 30) {
      _audioPlayer.startPeriodicTicks(intervalSeconds: 15);
      _ticksActive = true;
    }
  }

  void _pauseTimer() {
    _timerManager.pause();
  }

  void _resumeTimer() {
    _timerManager.resume();
  }

  void _resumeOrRestartTimer() {
    if (_timerState.isCompleted || _timerState.status == RestTimerStatus.idle) {
      _startTimer();
      return;
    }
    _resumeTimer();
  }

  void _resetTimer() {
    _motivationalPhrase = null;
    _completionHandled = false;

    if (_timerState.isRunning) {
      _startTimer();
    } else {
      _timerManager.reset(durationSeconds: widget.durationSeconds);
    }
  }

  void _skipTimer() {
    _timerManager.stop();
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
    Navigator.of(context).pop();
  }

  void _adjustTime(int seconds) {
    if (seconds == 0) return;
    _motivationalPhrase = null;

    if (seconds > 0) {
      _timerManager.addTime(seconds);
    } else {
      _timerManager.subtractTime(seconds.abs());
    }
  }

  /// Pick a random motivational phrase
  String _randomMotivationalPhrase() {
    final random = Random();
    return _motivationalPhrases[random.nextInt(_motivationalPhrases.length)];
  }

  /// Format seconds as MM:SS
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final remainingSeconds = _timerState.remainingMs > 0
        ? (_timerState.remainingMs / 1000).ceil()
        : 0;
    final progress = _timerState.progress.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App bar with close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Timer display
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Motivational phrase (if available)
                    if (_motivationalPhrase != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _motivationalPhrase!,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Rest label
                    Text(
                      'REST',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Circular progress indicator with time inside
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            color: remainingSeconds < 5
                                ? Colors.red
                                : Theme.of(context).colorScheme.primary,
                          ),

                          // Time display
                          Text(
                            _formatTime(remainingSeconds),
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: remainingSeconds < 5
                                  ? Colors.red
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Controls row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reset button
                        IconButton.filled(
                          onPressed: _resetTimer,
                          icon: const Icon(Icons.refresh),
                          iconSize: 32,
                        ),

                        const SizedBox(width: 24),

                        // Play/Pause button
                        IconButton.filled(
                          onPressed: _timerState.isRunning
                              ? _pauseTimer
                              : _resumeOrRestartTimer,
                          icon: Icon(_timerState.isRunning
                              ? Icons.pause
                              : Icons.play_arrow),
                          iconSize: 48,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        const SizedBox(width: 24),

                        // Skip button
                        IconButton.filled(
                          onPressed: _skipTimer,
                          icon: const Icon(Icons.skip_next),
                          iconSize: 32,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          const Icon(Icons.watch),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Watch buzz for this timer',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          Switch(
                            value: _watchBuzzEnabled,
                            onChanged: (value) {
                              setState(() {
                                _watchBuzzEnabled = value;
                              });
                              _timerManager.setNotificationsEnabled(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Time adjustment buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // -30s button
                  ElevatedButton(
                    onPressed:
                        remainingSeconds > 30 ? () => _adjustTime(-30) : null,
                    child: const Text('-30s'),
                  ),

                  // -15s button
                  ElevatedButton(
                    onPressed:
                        remainingSeconds > 15 ? () => _adjustTime(-15) : null,
                    child: const Text('-15s'),
                  ),

                  // +15s button
                  ElevatedButton(
                    onPressed: () => _adjustTime(15),
                    child: const Text('+15s'),
                  ),

                  // +30s button
                  ElevatedButton(
                    onPressed: () => _adjustTime(30),
                    child: const Text('+30s'),
                  ),
                ],
              ),
            ),

            // Info text
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: () {
                  // Show a dialog with information about rest timing
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Rest Timer'),
                      content: const Text(
                          'Rest periods between sets help your muscles recover. For strength training, 2-5 minutes is recommended. For endurance, 30-90 seconds is typical.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('About Rest Timing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the rest timer as a full screen dialog
Future<void> showRestTimer(
  BuildContext context, {
  int? durationSeconds,
  VoidCallback? onComplete,
  bool showMotivationalPhrases = true,
  bool enableWatchBuzz = true,
}) async {
  // If duration not provided, get from user preferences
  final actualDuration =
      durationSeconds ?? UserPreferencesService().getRestTimerDuration();

  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => RestTimerScreen(
        durationSeconds: actualDuration,
        onComplete: onComplete,
        showMotivationalPhrases: showMotivationalPhrases,
        enableWatchBuzz: enableWatchBuzz,
      ),
    ),
  );
}
