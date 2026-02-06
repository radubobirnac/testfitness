import 'package:equatable/equatable.dart';

/// Represents the current state of the application
class AppState extends Equatable {
  final bool isInitialized;
  final int currentTabIndex;
  final bool isDarkMode;
  final Map<String, dynamic> preferences;
  final String? errorMessage;
  final bool isLoading;

  const AppState({
    this.isInitialized = false,
    this.currentTabIndex = 0,
    this.isDarkMode = false,
    this.preferences = const {},
    this.errorMessage,
    this.isLoading = false,
  });

  /// Initial state when app starts
  const AppState.initial()
      : isInitialized = false,
        currentTabIndex = 0,
        isDarkMode = false,
        preferences = const {},
        errorMessage = null,
        isLoading = true;

  /// State when app is fully loaded
  AppState copyWith({
    bool? isInitialized,
    int? currentTabIndex,
    bool? isDarkMode,
    Map<String, dynamic>? preferences,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      preferences: preferences ?? this.preferences,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        isInitialized,
        currentTabIndex,
        isDarkMode,
        preferences,
        errorMessage,
        isLoading,
      ];

  @override
  String toString() {
    return 'AppState(isInitialized: $isInitialized, currentTabIndex: $currentTabIndex, isDarkMode: $isDarkMode, hasError: ${errorMessage != null}, isLoading: $isLoading)';
  }
}
