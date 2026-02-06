import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Centralized logging utility for the StrengthWave application
///
/// This class provides a consistent logging interface across the app
/// and handles different log levels appropriately for debug vs release builds.
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // Number of method calls to be displayed
      errorMethodCount: 8, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.none, // No timestamp to reduce clutter
    ),
    level: kDebugMode ? Level.debug : Level.info,
  );

  /// Log debug information (only in debug builds)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Log general information
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warnings
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log errors
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal errors
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Log database operations
  static void database(String operation, [String? details]) {
    debug('DB: $operation${details != null ? ' - $details' : ''}');
  }

  /// Log timer operations
  static void timer(String operation, [String? details]) {
    debug('TIMER: $operation${details != null ? ' - $details' : ''}');
  }

  /// Log audio operations
  static void audio(String operation, [String? details]) {
    debug('AUDIO: $operation${details != null ? ' - $details' : ''}');
  }

  /// Log navigation operations
  static void navigation(String operation, [String? details]) {
    debug('NAV: $operation${details != null ? ' - $details' : ''}');
  }
}
