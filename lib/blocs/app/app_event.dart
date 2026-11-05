import 'package:equatable/equatable.dart';

/// Base class for all app events
abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the app
class AppInitialize extends AppEvent {
  const AppInitialize();
}

/// Event to change the current tab
class AppTabChanged extends AppEvent {
  final int tabIndex;

  const AppTabChanged(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

/// Event to toggle dark mode
class AppThemeToggled extends AppEvent {
  const AppThemeToggled();
}

/// Event to update app preferences
class AppPreferencesUpdated extends AppEvent {
  final Map<String, dynamic> preferences;

  const AppPreferencesUpdated(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Event to re-read stored settings into the state without writing any.
class AppPreferencesReloaded extends AppEvent {
  const AppPreferencesReloaded();
}

/// Event to clear any error messages
class AppErrorCleared extends AppEvent {
  const AppErrorCleared();
}

/// Event when an error occurs
class AppErrorOccurred extends AppEvent {
  final String message;

  const AppErrorOccurred(this.message);

  @override
  List<Object?> get props => [message];
}
