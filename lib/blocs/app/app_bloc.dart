import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/app/app_state.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/error_handler.dart';

/// BLoC for managing global app state
class AppBloc extends Bloc<AppEvent, AppState> {
  static const String _darkModeKey = 'dark_mode';
  static const String _currentTabKey = 'current_tab';

  AppBloc() : super(const AppState.initial()) {
    on<AppInitialize>(_onInitialize);
    on<AppTabChanged>(_onTabChanged);
    on<AppThemeToggled>(_onThemeToggled);
    on<AppPreferencesUpdated>(_onPreferencesUpdated);
    on<AppErrorCleared>(_onErrorCleared);
    on<AppErrorOccurred>(_onErrorOccurred);
  }

  /// Initialize the app by loading saved preferences
  Future<void> _onInitialize(
      AppInitialize event, Emitter<AppState> emit) async {
    try {
      AppLogger.info('Initializing app state...');

      final prefs = await SharedPreferences.getInstance();

      // Load saved preferences
      final isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      final currentTabIndex = prefs.getInt(_currentTabKey) ?? 0;

      // Create preferences map
      final preferences = <String, dynamic>{
        _darkModeKey: isDarkMode,
        _currentTabKey: currentTabIndex,
      };

      emit(state.copyWith(
        isInitialized: true,
        isDarkMode: isDarkMode,
        currentTabIndex: currentTabIndex,
        preferences: preferences,
        isLoading: false,
        clearError: true,
      ));

      AppLogger.info('App state initialized successfully');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to initialize app state', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to initialize app state', error, stackTrace);

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize app: ${error.toString()}',
      ));
    }
  }

  /// Handle tab change events
  Future<void> _onTabChanged(
      AppTabChanged event, Emitter<AppState> emit) async {
    try {
      AppLogger.debug('Changing tab to index: ${event.tabIndex}');

      // Save tab preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_currentTabKey, event.tabIndex);

      // Update preferences map
      final updatedPreferences = Map<String, dynamic>.from(state.preferences);
      updatedPreferences[_currentTabKey] = event.tabIndex;

      emit(state.copyWith(
        currentTabIndex: event.tabIndex,
        preferences: updatedPreferences,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to change tab', error, stackTrace);
      ErrorHandler.logWarning('Failed to change tab', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to change tab: ${error.toString()}',
      ));
    }
  }

  /// Handle theme toggle events
  Future<void> _onThemeToggled(
      AppThemeToggled event, Emitter<AppState> emit) async {
    try {
      final newDarkMode = !state.isDarkMode;
      AppLogger.debug('Toggling theme to: ${newDarkMode ? 'dark' : 'light'}');

      // Save theme preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, newDarkMode);

      // Update preferences map
      final updatedPreferences = Map<String, dynamic>.from(state.preferences);
      updatedPreferences[_darkModeKey] = newDarkMode;

      emit(state.copyWith(
        isDarkMode: newDarkMode,
        preferences: updatedPreferences,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to toggle theme', error, stackTrace);
      ErrorHandler.logWarning('Failed to toggle theme', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to toggle theme: ${error.toString()}',
      ));
    }
  }

  /// Handle preferences update events
  Future<void> _onPreferencesUpdated(
      AppPreferencesUpdated event, Emitter<AppState> emit) async {
    try {
      AppLogger.debug('Updating app preferences');

      final prefs = await SharedPreferences.getInstance();

      // Save each preference
      for (final entry in event.preferences.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(key, value);
        }
      }

      // Merge with existing preferences
      final updatedPreferences = Map<String, dynamic>.from(state.preferences);
      updatedPreferences.addAll(event.preferences);

      emit(state.copyWith(
        preferences: updatedPreferences,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      AppLogger.error('Failed to update preferences', error, stackTrace);
      ErrorHandler.logWarning(
          'Failed to update preferences', error, stackTrace);

      emit(state.copyWith(
        errorMessage: 'Failed to update preferences: ${error.toString()}',
      ));
    }
  }

  /// Handle error cleared events
  void _onErrorCleared(AppErrorCleared event, Emitter<AppState> emit) {
    emit(state.copyWith(clearError: true));
  }

  /// Handle error occurred events
  void _onErrorOccurred(AppErrorOccurred event, Emitter<AppState> emit) {
    AppLogger.error('App error occurred: ${event.message}');
    emit(state.copyWith(errorMessage: event.message));
  }
}
