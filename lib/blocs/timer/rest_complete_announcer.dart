import 'package:testfitness/services/enhanced_tts_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Speaks the rest-complete phrase through [EnhancedTTSService] (the user's
/// voice, rate and pitch), honouring the user's switches:
/// - "Motivational Phrases" off -> no speech.
/// - "Timer Sound" off -> silent rest end, so no speech either.
/// - Completed while backgrounded -> the notification was the alert; don't
///   talk over it / speak late on resume.
class RestCompleteAnnouncer {
  RestCompleteAnnouncer({
    Future<bool> Function()? motivationalPhrasesEnabled,
    bool Function()? timerSoundEnabled,
    Future<void> Function(String phrase)? speak,
  })  : _motivationalPhrasesEnabled =
            motivationalPhrasesEnabled ?? _defaultMotivationalPhrasesEnabled,
        _timerSoundEnabled = timerSoundEnabled ??
            (() => UserPreferencesService().getPlaySoundOnTimerEnd()),
        _speak = speak ?? ((p) => EnhancedTTSService().speakRestComplete(p));

  final Future<bool> Function() _motivationalPhrasesEnabled;
  final bool Function() _timerSoundEnabled;
  final Future<void> Function(String phrase) _speak;

  static Future<bool> _defaultMotivationalPhrasesEnabled() async {
    final tts = EnhancedTTSService();
    // Settings are loaded from prefs during initialize; without it the
    // getter would report the default (off) even if the user enabled it.
    await tts.initialize();
    return tts.useMotivationalPhrases;
  }

  /// Speaks [phrase] if allowed. Returns whether speech was requested.
  Future<bool> announce(
    String phrase, {
    required bool completedWhileBackgrounded,
  }) async {
    try {
      if (completedWhileBackgrounded) return false;
      if (!_timerSoundEnabled()) return false;
      if (!await _motivationalPhrasesEnabled()) return false;
      await _speak(phrase);
      return true;
    } catch (e) {
      AppLogger.warning('Failed to announce rest completion: $e');
      return false;
    }
  }
}
