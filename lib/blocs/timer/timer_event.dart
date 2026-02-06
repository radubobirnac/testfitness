import 'package:equatable/equatable.dart';
import 'package:testfitness/services/rest_timer_manager.dart';

/// Base class for all timer events
abstract class TimerEvent extends Equatable {
  const TimerEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the timer with a duration
class TimerInitialized extends TimerEvent {
  final int durationSeconds;
  final bool showMotivationalPhrases;

  const TimerInitialized({
    required this.durationSeconds,
    this.showMotivationalPhrases = true,
  });

  @override
  List<Object?> get props => [durationSeconds, showMotivationalPhrases];
}

/// Event to start the timer
class TimerStarted extends TimerEvent {
  const TimerStarted();
}

/// Event to pause the timer
class TimerPaused extends TimerEvent {
  const TimerPaused();
}

/// Event to resume the timer
class TimerResumed extends TimerEvent {
  const TimerResumed();
}

/// Event to reset the timer
class TimerReset extends TimerEvent {
  const TimerReset();
}

/// Event to stop the timer
class TimerStopped extends TimerEvent {
  const TimerStopped();
}

/// Event to update timer duration
class TimerDurationUpdated extends TimerEvent {
  final int newDurationSeconds;

  const TimerDurationUpdated(this.newDurationSeconds);

  @override
  List<Object?> get props => [newDurationSeconds];
}

/// Event to toggle motivational phrases
class TimerMotivationalPhrasesToggled extends TimerEvent {
  const TimerMotivationalPhrasesToggled();
}

/// Event to add time to the timer
class TimerTimeAdded extends TimerEvent {
  final int additionalSeconds;

  const TimerTimeAdded(this.additionalSeconds);

  @override
  List<Object?> get props => [additionalSeconds];
}

/// Event to subtract time from the timer
class TimerTimeSubtracted extends TimerEvent {
  final int secondsToSubtract;

  const TimerTimeSubtracted(this.secondsToSubtract);

  @override
  List<Object?> get props => [secondsToSubtract];
}

/// Event to clear any error messages
class TimerErrorCleared extends TimerEvent {
  const TimerErrorCleared();
}

/// Internal event from RestTimerManager updates
class TimerManagerUpdated extends TimerEvent {
  final RestTimerState state;

  const TimerManagerUpdated(this.state);

  @override
  List<Object?> get props => [state];
}
