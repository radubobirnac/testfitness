import 'dart:async';
import 'enhanced_tts_service.dart';
import '../utils/app_logger.dart';

/// Simple Boxing Audio Controller
/// Uses Flutter native TTS for countdown and combinations
class BoxingAudioController {
  static final BoxingAudioController _instance =
      BoxingAudioController._internal();
  factory BoxingAudioController() => _instance;
  BoxingAudioController._internal();

  EnhancedTTSService? _tts;
  bool _isInitialized = false;

  /// Boxing call-out voice: slower and louder for clarity. Applied as a
  /// session-only override so the user's saved voice settings are never
  /// overwritten; [stopAll]/[dispose] restore them.
  static const double boxingSpeechRate = 0.6;
  static const double boxingPitch = 1.0;
  static const double boxingVolume = 1.0;

  /// Initialize the boxing audio controller with native TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('Initializing simple boxing audio controller...');

      _tts = EnhancedTTSService();
      await _tts!.initialize();

      _isInitialized = true;
      AppLogger.info('Simple boxing audio ready!');
    } catch (e) {
      AppLogger.error('Failed to initialize boxing audio controller', e);
      rethrow;
    }
  }

  /// Applies the boxing voice to the engine (not persisted) if not active.
  Future<void> _ensureBoxingVoice() async {
    final tts = _tts;
    if (tts == null || tts.isSessionOverrideActive) return;
    await tts.applySessionOverride(
      speechRate: boxingSpeechRate,
      pitch: boxingPitch,
      volume: boxingVolume,
    );
  }

  /// Play simple countdown: 3, 2, 1
  Future<void> playCountdown() async {
    if (!_isInitialized) await initialize();

    try {
      AppLogger.info('Starting simple countdown...');
      await _ensureBoxingVoice();

      await _tts!.speak("3");
      await Future.delayed(const Duration(seconds: 1));
      await _tts!.speak("2");
      await Future.delayed(const Duration(seconds: 1));
      await _tts!.speak("1");

      AppLogger.info('Countdown complete!');
    } catch (e) {
      AppLogger.error('Failed to play countdown', e);
    }
  }

  /// Call out a boxing combination using TTS
  Future<void> callCombination(String combination) async {
    if (!_isInitialized) await initialize();

    try {
      final spokenCombination = _convertToSpokenCombination(combination);
      await _ensureBoxingVoice();
      await _tts!.speak(spokenCombination);
      AppLogger.info('🥊 Called combination: $combination');
    } catch (e) {
      AppLogger.error('Failed to call combination: $combination', e);
    }
  }

  /// Convert combination notation to spoken format
  String _convertToSpokenCombination(String combination) {
    return combination
        .replaceAll('-', ' ')
        .replaceAll('1', 'ONE')
        .replaceAll('2', 'TWO')
        .replaceAll('3', 'THREE')
        .replaceAll('4', 'FOUR')
        .replaceAll('5', 'FIVE')
        .replaceAll('6', 'SIX')
        .replaceAll('slip', 'SLIP')
        .replaceAll('duck', 'DUCK')
        .replaceAll('roll', 'ROLL')
        .replaceAll('block', 'BLOCK')
        .replaceAll('parry', 'PARRY')
        .toUpperCase();
  }

  /// Round start (NO ANNOUNCEMENT per user preference)
  Future<void> announceRoundStart(int roundNumber) async {
    // User wants NO round announcements - just log it
    AppLogger.info(
        'Round $roundNumber ready (no announcement per user preference)');
  }

  /// Stop all audio and restore the user's own voice settings
  Future<void> stopAll() async {
    try {
      await _tts?.stop();
      await _tts?.clearSessionOverride();
      AppLogger.info('Stopped all boxing audio');
    } catch (e) {
      AppLogger.error('Failed to stop boxing audio', e);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _tts?.clearSessionOverride();
      _isInitialized = false;
      AppLogger.info('BoxingAudioController disposed');
    } catch (e) {
      AppLogger.error('Failed to dispose boxing audio controller', e);
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
}
