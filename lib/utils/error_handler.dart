import 'package:flutter/material.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Centralized error handling utility for StrengthWave
///
/// This class provides consistent error handling patterns across the app
/// and converts technical errors into user-friendly messages.
class ErrorHandler {
  /// Handle database-related errors
  static void handleDatabaseError(
    BuildContext? context,
    dynamic error, [
    StackTrace? stackTrace,
    String? userMessage,
  ]) {
    AppLogger.error('Database error occurred', error, stackTrace);

    if (context != null && context.mounted) {
      _showUserFriendlyError(
        context,
        userMessage ?? 'Unable to access your workout data. Please try again.',
        canRetry: true,
        icon: Icons.storage_outlined,
      );
    }
  }

  /// Handle network/connectivity errors
  static void handleNetworkError(
    BuildContext? context,
    dynamic error, [
    StackTrace? stackTrace,
    String? userMessage,
  ]) {
    AppLogger.error('Network error occurred', error, stackTrace);

    if (context != null && context.mounted) {
      _showUserFriendlyError(
        context,
        userMessage ??
            'Connection issue. Please check your internet and try again.',
        canRetry: true,
        icon: Icons.wifi_off_outlined,
      );
    }
  }

  /// Handle audio/media errors
  static void handleAudioError(
    BuildContext? context,
    dynamic error, [
    StackTrace? stackTrace,
    String? userMessage,
  ]) {
    AppLogger.error('Audio error occurred', error, stackTrace);

    if (context != null && context.mounted) {
      _showUserFriendlyError(
        context,
        userMessage ??
            'Audio playback issue. Check your device volume settings.',
        canRetry: false,
        icon: Icons.volume_off_outlined,
      );
    }
  }

  /// Handle timer-related errors
  static void handleTimerError(
    BuildContext? context,
    dynamic error, [
    StackTrace? stackTrace,
    String? userMessage,
  ]) {
    AppLogger.error('Timer error occurred', error, stackTrace);

    if (context != null && context.mounted) {
      _showUserFriendlyError(
        context,
        userMessage ?? 'Timer issue occurred. Please restart the timer.',
        canRetry: true,
        icon: Icons.timer_off_outlined,
      );
    }
  }

  /// Handle user preferences errors
  static void handlePreferencesError(
    BuildContext? context,
    dynamic error, [
    StackTrace? stackTrace,
    String? userMessage,
  ]) {
    AppLogger.error('Preferences error occurred', error, stackTrace);

    if (context != null && context.mounted) {
      _showUserFriendlyError(
        context,
        userMessage ?? 'Settings could not be saved. Please try again.',
        canRetry: true,
      );
    }
  }

  /// Handle general application errors
  static void handleGeneralError(
    BuildContext? context,
    dynamic error, [
    StackTrace? stackTrace,
    String? userMessage,
  ]) {
    AppLogger.error('General error occurred', error, stackTrace);

    if (context != null && context.mounted) {
      _showUserFriendlyError(
        context,
        userMessage ?? 'Something went wrong. Please try again.',
        canRetry: true,
      );
    }
  }

  /// Handle parsing/data conversion errors
  static void handleParsingError(
    dynamic error, [
    StackTrace? stackTrace,
    String? context,
  ]) {
    AppLogger.error(
      'Data parsing error${context != null ? ' in $context' : ''}',
      error,
      stackTrace,
    );
  }

  /// Log warnings without showing user messages
  static void logWarning(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    AppLogger.warning(message, error, stackTrace);
  }

  /// Show user-friendly error message with optional retry
  static void _showUserFriendlyError(
    BuildContext context,
    String message, {
    bool canRetry = false,
    VoidCallback? onRetry,
    IconData? icon,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        action: canRetry && onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success message to user
  static void showSuccess(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show info message to user
  static void showInfo(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
