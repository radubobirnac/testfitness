import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/timer/timer_event.dart';
import 'package:testfitness/blocs/timer/timer_state.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/rest_timer_manager.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/error_handler.dart';

/// BLoC for managing timer operations
class TimerBloc extends Bloc<TimerEvent, TimerState> {
  final RestTimerManager _timerManager = RestTimerManager();
  StreamSubscription<RestTimerState>? _timerSubscription;

  TimerBloc() : super(const TimerState.initial()) {
    on<TimerInitialized>(_onInitialized);
    on<TimerStarted>(_onStarted);
    on<TimerPaused>(_onPaused);
    on<TimerResumed>(_onResumed);
    on<TimerReset>(_onReset);
    on<TimerStopped>(_onStopped);
    on<TimerDurationUpdated>(_onDurationUpdated);
    on<TimerMotivationalPhrasesToggled>(_onMotivationalPhrasesToggled);
    on<TimerTimeAdded>(_onTimeAdded);
    on<TimerTimeSubtracted>(_onTimeSubtracted);
    on<TimerErrorCleared>(_onErrorCleared);
    on<TimerManagerUpdated>(_onManagerUpdated);

    _timerSubscription = _timerManager.stream.listen((managerState) {
      add(TimerManagerUpdated(managerState));
    });
    unawaited(_timerManager.initialize());
  }

  @override
  Future<void> close() {
    _timerSubscription?.cancel();
    return super.close();
  }

  /// Initialize the timer with a duration
  void _onInitialized(TimerInitialized event, Emitter<TimerState> emit) {
    try {
      AppLogger.timer(
          'Initializing timer with ${event.durationSeconds} seconds');

      if (event.durationSeconds <= 0) {
        emit(state.copyWith(
          errorMessage: 'Timer duration must be greater than 0',
        ));
        return;
      }

      emit(TimerState.ready(
        event.durationSeconds,
        showMotivationalPhrases: event.showMotivationalPhrases,
      ));

      AppLogger.timer('Timer initialized successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to initialize timer', error, stackTrace);
      ErrorHandler.logWarning('Failed to initialize timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to initialize timer: ${error.toString()}',
      ));
    }
  }

  /// Start the timer
  Future<void> _onStarted(
      TimerStarted event, Emitter<TimerState> emit) async {
    try {
      if (!state.canStart) {
        AppLogger.warning(
            'Cannot start timer in current state: ${state.toString()}');
        return;
      }

      AppLogger.timer('Starting timer');

      emit(state.copyWith(
        isRunning: true,
        isPaused: false,
        isCompleted: false,
        clearError: true,
        clearMotivationalPhrase: true,
      ));

      await _timerManager.start(
        durationSeconds: state.totalDurationSeconds,
        notificationsEnabled: true,
      );
      AppLogger.timer('Timer started successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to start timer', error, stackTrace);
      ErrorHandler.logWarning('Failed to start timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to start timer: ${error.toString()}',
      ));
    }
  }

  /// Pause the timer
  Future<void> _onPaused(TimerPaused event, Emitter<TimerState> emit) async {
    try {
      if (!state.canPause) {
        AppLogger.warning(
            'Cannot pause timer in current state: ${state.toString()}');
        return;
      }

      AppLogger.timer('Pausing timer');

      await _timerManager.pause();

      emit(state.copyWith(
        isRunning: false,
        isPaused: true,
        clearError: true,
      ));

      AppLogger.timer('Timer paused successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to pause timer', error, stackTrace);
      ErrorHandler.logWarning('Failed to pause timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to pause timer: ${error.toString()}',
      ));
    }
  }

  /// Resume the timer
  Future<void> _onResumed(
      TimerResumed event, Emitter<TimerState> emit) async {
    try {
      if (!state.canResume) {
        AppLogger.warning(
            'Cannot resume timer in current state: ${state.toString()}');
        return;
      }

      AppLogger.timer('Resuming timer');

      emit(state.copyWith(
        isRunning: true,
        isPaused: false,
        clearError: true,
      ));

      await _timerManager.resume();
      AppLogger.timer('Timer resumed successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to resume timer', error, stackTrace);
      ErrorHandler.logWarning('Failed to resume timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to resume timer: ${error.toString()}',
      ));
    }
  }

  /// Reset the timer
  Future<void> _onReset(TimerReset event, Emitter<TimerState> emit) async {
    try {
      if (!state.canReset) {
        AppLogger.warning(
            'Cannot reset timer in current state: ${state.toString()}');
        return;
      }

      AppLogger.timer('Resetting timer');

      await _timerManager.reset(durationSeconds: state.totalDurationSeconds);

      emit(state.copyWith(
        remainingSeconds: state.totalDurationSeconds,
        isRunning: false,
        isPaused: false,
        isCompleted: false,
        progress: 1.0,
        clearError: true,
        clearMotivationalPhrase: true,
      ));

      AppLogger.timer('Timer reset successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to reset timer', error, stackTrace);
      ErrorHandler.logWarning('Failed to reset timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to reset timer: ${error.toString()}',
      ));
    }
  }

  /// Stop the timer
  Future<void> _onStopped(TimerStopped event, Emitter<TimerState> emit) async {
    try {
      AppLogger.timer('Stopping timer');

      await _timerManager.stop();

      emit(const TimerState.initial());

      AppLogger.timer('Timer stopped successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to stop timer', error, stackTrace);
      ErrorHandler.logWarning('Failed to stop timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to stop timer: ${error.toString()}',
      ));
    }
  }

  /// Generate AI motivation asynchronously
  void _generateAIMotivation() {
    try {
      final aiService = AIService();
      aiService.generateQuickMotivation(
        context: 'rest_complete',
        speakAloud: true,
      );
    } catch (e) {
      AppLogger.warning('Failed to generate AI motivation: $e');
    }
  }

  /// Update timer duration
  void _onDurationUpdated(
      TimerDurationUpdated event, Emitter<TimerState> emit) {
    try {
      if (event.newDurationSeconds <= 0) {
        emit(state.copyWith(
          errorMessage: 'Timer duration must be greater than 0',
        ));
        return;
      }

      AppLogger.timer(
          'Updating timer duration to ${event.newDurationSeconds} seconds');

      // Stop current timer if running
      unawaited(_timerManager.reset(durationSeconds: event.newDurationSeconds));

      emit(TimerState.ready(
        event.newDurationSeconds,
        showMotivationalPhrases: state.showMotivationalPhrases,
      ));

      AppLogger.timer('Timer duration updated successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to update timer duration', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to update timer duration', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to update timer duration: ${error.toString()}',
      ));
    }
  }

  /// Toggle motivational phrases
  void _onMotivationalPhrasesToggled(
      TimerMotivationalPhrasesToggled event, Emitter<TimerState> emit) {
    try {
      AppLogger.timer(
          'Toggling motivational phrases: ${!state.showMotivationalPhrases}');

      emit(state.copyWith(
        showMotivationalPhrases: !state.showMotivationalPhrases,
        clearMotivationalPhrase: !state.showMotivationalPhrases ? false : true,
        clearError: true,
      ));

      AppLogger.timer('Motivational phrases toggled successfully');
    } catch (error, stackTrace) {
      AppLogger.error(
          'Failed to toggle motivational phrases', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to toggle motivational phrases', error, stackTrace);

      emit(state.copyWith(
        errorMessage:
            'Failed to toggle motivational phrases: ${error.toString()}',
      ));
    }
  }

  /// Add time to the timer
  Future<void> _onTimeAdded(
      TimerTimeAdded event, Emitter<TimerState> emit) async {
    try {
      if (event.additionalSeconds <= 0) {
        AppLogger.warning('Cannot add non-positive time to timer');
        return;
      }

      AppLogger.timer('Adding ${event.additionalSeconds} seconds to timer');

      await _timerManager.addTime(event.additionalSeconds);

      AppLogger.timer('Time added successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to add time to timer', error, stackTrace);
      ErrorHandler.logWarning('Failed to add time to timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to add time: ${error.toString()}',
      ));
    }
  }

  /// Subtract time from the timer
  Future<void> _onTimeSubtracted(
      TimerTimeSubtracted event, Emitter<TimerState> emit) async {
    try {
      if (event.secondsToSubtract <= 0) {
        AppLogger.warning('Cannot subtract non-positive time from timer');
        return;
      }

      AppLogger.timer(
          'Subtracting ${event.secondsToSubtract} seconds from timer');

      await _timerManager.subtractTime(event.secondsToSubtract);

      AppLogger.timer('Time subtracted successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to subtract time from timer', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to subtract time from timer', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to subtract time: ${error.toString()}',
      ));
    }
  }

  /// Clear error messages
  void _onErrorCleared(TimerErrorCleared event, Emitter<TimerState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onManagerUpdated(
      TimerManagerUpdated event, Emitter<TimerState> emit) {
    final managerState = event.state;
    final totalSeconds = managerState.totalDurationMs > 0
        ? (managerState.totalDurationMs / 1000).ceil()
        : 0;
    final remainingSeconds = managerState.remainingMs > 0
        ? (managerState.remainingMs / 1000).ceil()
        : 0;
    final progress = totalSeconds > 0
        ? remainingSeconds / totalSeconds
        : 0.0;
    final justCompleted = managerState.isCompleted && !state.isCompleted;

    if (justCompleted) {
      _generateAIMotivation();
    }

    emit(state.copyWith(
      totalDurationSeconds: totalSeconds,
      remainingSeconds: remainingSeconds,
      isRunning: managerState.isRunning,
      isPaused: managerState.isPaused,
      isCompleted: managerState.isCompleted,
      progress: progress,
      currentMotivationalPhrase:
          justCompleted ? "Let's Go! 💪" : state.currentMotivationalPhrase,
      completedWhileBackgrounded: managerState.completedWhileBackgrounded,
      clearMotivationalPhrase: !managerState.isCompleted,
      clearError: true,
    ));
  }
}
