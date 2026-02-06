import 'package:equatable/equatable.dart';

/// Represents the current state of the timer
class TimerState extends Equatable {
  final int totalDurationSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final bool isPaused;
  final bool isCompleted;
  final bool completedWhileBackgrounded;
  final bool showMotivationalPhrases;
  final String? currentMotivationalPhrase;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;

  const TimerState({
    this.totalDurationSeconds = 0,
    this.remainingSeconds = 0,
    this.isRunning = false,
    this.isPaused = false,
    this.isCompleted = false,
    this.completedWhileBackgrounded = false,
    this.showMotivationalPhrases = true,
    this.currentMotivationalPhrase,
    this.progress = 0.0,
    this.errorMessage,
  });

  /// Initial state when timer is not set
  const TimerState.initial()
      : totalDurationSeconds = 0,
        remainingSeconds = 0,
        isRunning = false,
        isPaused = false,
        isCompleted = false,
        completedWhileBackgrounded = false,
        showMotivationalPhrases = true,
        currentMotivationalPhrase = null,
        progress = 0.0,
        errorMessage = null;

  /// State when timer is ready to start
  const TimerState.ready(int durationSeconds,
      {this.showMotivationalPhrases = true})
      : totalDurationSeconds = durationSeconds,
        remainingSeconds = durationSeconds,
        isRunning = false,
        isPaused = false,
        isCompleted = false,
        completedWhileBackgrounded = false,
        currentMotivationalPhrase = null,
        progress = 1.0,
        errorMessage = null;

  /// State when timer is running
  TimerState copyWith({
    int? totalDurationSeconds,
    int? remainingSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? isCompleted,
    bool? completedWhileBackgrounded,
    bool? showMotivationalPhrases,
    String? currentMotivationalPhrase,
    double? progress,
    String? errorMessage,
    bool clearError = false,
    bool clearMotivationalPhrase = false,
  }) {
    return TimerState(
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      completedWhileBackgrounded:
          completedWhileBackgrounded ?? this.completedWhileBackgrounded,
      showMotivationalPhrases:
          showMotivationalPhrases ?? this.showMotivationalPhrases,
      currentMotivationalPhrase: clearMotivationalPhrase
          ? null
          : (currentMotivationalPhrase ?? this.currentMotivationalPhrase),
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Calculate progress based on remaining time
  double get calculatedProgress {
    if (totalDurationSeconds <= 0) return 0.0;
    return remainingSeconds / totalDurationSeconds;
  }

  /// Get formatted time string (MM:SS)
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted total time string (MM:SS)
  String get formattedTotalTime {
    final minutes = totalDurationSeconds ~/ 60;
    final seconds = totalDurationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if timer is initialized
  bool get isInitialized => totalDurationSeconds > 0;

  /// Check if timer can be started
  bool get canStart => isInitialized && !isRunning && !isCompleted;

  /// Check if timer can be paused
  bool get canPause => isRunning && !isPaused;

  /// Check if timer can be resumed
  bool get canResume => isPaused && !isCompleted;

  /// Check if timer can be reset
  bool get canReset => isInitialized && (isRunning || isPaused || isCompleted);

  /// Check if timer has an error
  bool get hasError => errorMessage != null;

  /// Check if timer is in active state (running or paused)
  bool get isActive => isRunning || isPaused;

  /// Get elapsed time in seconds
  int get elapsedSeconds => totalDurationSeconds - remainingSeconds;

  /// Get elapsed time percentage (0.0 to 1.0)
  double get elapsedPercentage => 1.0 - calculatedProgress;

  @override
  List<Object?> get props => [
        totalDurationSeconds,
        remainingSeconds,
        isRunning,
        isPaused,
        isCompleted,
        completedWhileBackgrounded,
        showMotivationalPhrases,
        currentMotivationalPhrase,
        progress,
        errorMessage,
      ];

  @override
  String toString() {
    return 'TimerState(totalDuration: $formattedTotalTime, remaining: $formattedTime, isRunning: $isRunning, isPaused: $isPaused, isCompleted: $isCompleted, progress: ${(calculatedProgress * 100).toStringAsFixed(1)}%)';
  }
}
