import 'dart:html' show window;
import 'package:testfitness/utils/app_logger.dart';

/// Web implementation to reset localStorage
/// This function is only used on web platforms
void resetWebStorage() {
  try {
    // Clear just the exercise data
    window.localStorage.remove('testfitness_exercises');
    AppLogger.database('Web localStorage for exercises has been reset');
  } catch (e) {
    AppLogger.error('Error resetting web localStorage', e);
  }
}
