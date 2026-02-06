import 'package:equatable/equatable.dart';

/// Base class for all application-level events
abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the application
class AppInitialized extends AppEvent {
  const AppInitialized();
}

/// Event to change the current tab
class AppTabChanged extends AppEvent {
  final int tabIndex;

  const AppTabChanged(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}

/// Event to toggle theme mode
class AppThemeToggled extends AppEvent {
  const AppThemeToggled();
}

/// Event to update user preferences
class AppPreferencesUpdated extends AppEvent {
  final Map<String, dynamic> preferences;

  const AppPreferencesUpdated(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Event to handle app lifecycle changes
class AppLifecycleChanged extends AppEvent {
  final String state;

  const AppLifecycleChanged(this.state);

  @override
  List<Object?> get props => [state];
}

/// Event to handle errors at app level
class AppErrorOccurred extends AppEvent {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  const AppErrorOccurred({
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  List<Object?> get props => [message, error, stackTrace];
}

/// Event to clear app-level errors
class AppErrorCleared extends AppEvent {
  const AppErrorCleared();
}
