import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/services/tts_analytics_service.dart';

/// Enhanced TTS Service with voice quality improvements and enthusiasm controls
///
/// All app speech (profile tests, rest-timer phrases, boxing call-outs) goes
/// through this single engine, so [stop] silences everything.
class EnhancedTTSService {
  static final EnhancedTTSService _instance = EnhancedTTSService._internal();
  factory EnhancedTTSService() => _instance;
  EnhancedTTSService._internal();

  FlutterTts? _tts;
  Future<void>? _initFuture;
  bool _isInitialized = false;
  final TTSAnalyticsService _analytics = TTSAnalyticsService();

  /// True while a caller (e.g. boxing) has applied temporary engine settings
  /// via [applySessionOverride]; the user's saved settings are untouched.
  bool _sessionOverrideActive = false;

  // TTS Settings
  double _speechRate = 0.6;
  double _volume = 0.9;
  double _pitch = 1.1;
  String _selectedVoice = '';
  final String _language = 'en-US';

  // Enthusiasm Settings
  int _enthusiasmLevel = 1; // 1-5 scale (default to minimal)
  bool _useMotivationalPhrases = false; // Disabled by default
  bool _useEmphasis = false; // Disabled by default

  // Available voices cache
  List<Map<String, String>> _availableVoices = [];

  // Preference keys
  static const String _speechRateKey = 'tts_speech_rate';
  static const String _volumeKey = 'tts_volume';
  static const String _pitchKey = 'tts_pitch';
  static const String _selectedVoiceKey = 'tts_selected_voice';
  static const String _enthusiasmLevelKey = 'tts_enthusiasm_level';
  static const String _useMotivationalPhrasesKey =
      'tts_use_motivational_phrases';
  static const String _useEmphasisKey = 'tts_use_emphasis';

  /// Initialize the enhanced TTS service. Idempotent and safe to call
  /// concurrently: every caller awaits the same in-flight initialization.
  Future<void> initialize() => _initFuture ??= _initializeInternal();

  Future<void> _initializeInternal() async {
    try {
      _tts ??= FlutterTts();
      await _loadSettings();
      await _discoverVoices();
      await _applySettings();

      _isInitialized = true;
      AppLogger.info('Enhanced TTS Service initialized successfully');
    } catch (error) {
      AppLogger.error('Failed to initialize Enhanced TTS Service', error);
      // Allow a later call to retry.
      _initFuture = null;
    }
  }

  /// Load settings from preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _speechRate = prefs.getDouble(_speechRateKey) ?? 0.6;
      _volume = prefs.getDouble(_volumeKey) ?? 0.9;
      _pitch = prefs.getDouble(_pitchKey) ?? 1.1;
      _selectedVoice = prefs.getString(_selectedVoiceKey) ?? '';
      _enthusiasmLevel = prefs.getInt(_enthusiasmLevelKey) ?? 1;
      _useMotivationalPhrases =
          prefs.getBool(_useMotivationalPhrasesKey) ?? false;
      _useEmphasis = prefs.getBool(_useEmphasisKey) ?? false;

      AppLogger.info('TTS settings loaded from preferences');
    } catch (error) {
      AppLogger.error('Failed to load TTS settings', error);
    }
  }

  /// Save settings to preferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble(_speechRateKey, _speechRate);
      await prefs.setDouble(_volumeKey, _volume);
      await prefs.setDouble(_pitchKey, _pitch);
      await prefs.setString(_selectedVoiceKey, _selectedVoice);
      await prefs.setInt(_enthusiasmLevelKey, _enthusiasmLevel);
      await prefs.setBool(_useMotivationalPhrasesKey, _useMotivationalPhrases);
      await prefs.setBool(_useEmphasisKey, _useEmphasis);

      AppLogger.info('TTS settings saved to preferences');
    } catch (error) {
      AppLogger.error('Failed to save TTS settings', error);
    }
  }

  /// Converts the raw `getVoices` platform result into string maps.
  ///
  /// flutter_tts returns platform-channel data (a `List` of
  /// `Map<Object?, Object?>`), so `cast<Map<String, String>>()` throws as soon
  /// as an element is read. Entries without a name are dropped.
  @visibleForTesting
  static List<Map<String, String>> parseVoices(Object? raw) {
    if (raw is! List) return [];
    final voices = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final voice = <String, String>{};
      item.forEach((key, value) {
        if (key != null && value != null) voice['$key'] = '$value';
      });
      if ((voice['name'] ?? '').isEmpty) continue;
      voices.add(voice);
    }
    return voices;
  }

  static int _voiceScore(Map<String, String> voice) {
    final name = voice['name']?.toLowerCase() ?? '';
    var score = 0;
    // Highest priority: Enhanced/Neural/Premium voices
    if (name.contains('enhanced') ||
        name.contains('neural') ||
        name.contains('premium')) {
      score += 100;
    }
    // High priority: Natural/High quality voices
    if (name.contains('natural') ||
        name.contains('high') ||
        name.contains('quality')) {
      score += 50;
    }
    // Medium priority: Female voices (often clearer)
    if (name.contains('female') ||
        name.contains('woman') ||
        name.contains('samantha') ||
        name.contains('karen')) {
      score += 25;
    }
    // Prefer US English
    final locale = voice['locale'] ?? '';
    if (locale.contains('en-US') || locale.contains('en_US')) score += 10;
    return score;
  }

  /// Sorts voices best-first (enhanced/neural, natural, en-US ...).
  @visibleForTesting
  static List<Map<String, String>> rankVoices(
      List<Map<String, String>> voices) {
    final ranked = List<Map<String, String>>.of(voices);
    ranked.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
    return ranked;
  }

  /// The voice named [name] in [voices], or null when it isn't available.
  @visibleForTesting
  static Map<String, String>? findVoice(
      List<Map<String, String>> voices, String name) {
    if (name.isEmpty) return null;
    for (final voice in voices) {
      if (voice['name'] == name) return voice;
    }
    return null;
  }

  /// Discover and rank available voices
  Future<void> _discoverVoices() async {
    final tts = _tts;
    if (tts == null) return;
    try {
      final raw = await tts.getVoices;
      _availableVoices = rankVoices(parseVoices(raw));

      AppLogger.info(
          'Discovered ${_availableVoices.length} voices, ranked by quality');

      // Auto-select the best voice if none is selected or the saved one is
      // no longer installed (in memory only; persisted on the next save).
      if (_availableVoices.isNotEmpty &&
          findVoice(_availableVoices, _selectedVoice) == null) {
        _selectedVoice = _availableVoices.first['name'] ?? '';
        AppLogger.info('Auto-selected best voice: $_selectedVoice');
      }
    } catch (error) {
      AppLogger.error('Failed to discover voices', error);
    }
  }

  /// Apply the user's saved settings to the TTS engine
  Future<void> _applySettings() async {
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.setLanguage(_language);
      await tts.setSpeechRate(_speechRate);
      await tts.setVolume(_volume);
      await tts.setPitch(_pitch);
      await _applyVoice(tts);

      AppLogger.info('TTS settings applied successfully');
    } catch (error) {
      AppLogger.error('Failed to apply TTS settings', error);
    }
  }

  Future<void> _applyVoice(FlutterTts tts) async {
    final voice = findVoice(_availableVoices, _selectedVoice);
    if (voice == null) return;
    try {
      // flutter_tts matches on name + locale; pass only those keys.
      await tts.setVoice({
        'name': voice['name'] ?? '',
        'locale': voice['locale'] ?? '',
      });
      AppLogger.info('Applied voice: $_selectedVoice');
    } catch (error) {
      AppLogger.error('Failed to apply voice $_selectedVoice', error);
    }
  }

  /// Temporarily changes engine rate/pitch/volume for a session (e.g. a
  /// boxing workout) WITHOUT persisting them. Call [clearSessionOverride] to
  /// return to the user's saved settings.
  Future<void> applySessionOverride({
    double? speechRate,
    double? pitch,
    double? volume,
  }) async {
    await initialize();
    final tts = _tts;
    if (tts == null) return;
    _sessionOverrideActive = true;
    try {
      await tts.setSpeechRate((speechRate ?? _speechRate).clamp(0.1, 2.0));
      await tts.setPitch((pitch ?? _pitch).clamp(0.5, 2.0));
      await tts.setVolume((volume ?? _volume).clamp(0.0, 1.0));
    } catch (error) {
      AppLogger.error('Failed to apply session TTS override', error);
    }
  }

  /// Restores the user's saved settings after [applySessionOverride].
  Future<void> clearSessionOverride() async {
    if (!_sessionOverrideActive) return;
    _sessionOverrideActive = false;
    await initialize();
    await _applySettings();
  }

  bool get isSessionOverrideActive => _sessionOverrideActive;

  /// Enhance text with basic formatting only (no motivational content)
  String _enhanceText(String text, {String context = 'general'}) {
    // Simply return the text as-is, no motivational enhancements
    return text;
  }

  /// Speak text with enhancements
  Future<void> speak(String text, {String context = 'general'}) async {
    await initialize();
    final tts = _tts;
    if (tts == null) return;

    try {
      // Track TTS usage for cost optimization analytics
      await _analytics.trackTTSUsage(
        text: text,
        context: context,
        serviceType: 'Enhanced TTS (Flutter)',
        voice: _selectedVoice,
        costEstimate: 0.0, // Flutter TTS is free
      );

      final enhancedText = _enhanceText(text, context: context);

      // Clean text for better pronunciation
      final cleanText = enhancedText
          .replaceAll(RegExp(r"[^\w\s.,!?'-]"),
              '') // Remove emojis/special chars except basic punctuation
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();

      if (cleanText.isEmpty) return;

      await tts.speak(cleanText);
      AppLogger.info(
          'Enhanced TTS speaking: ${cleanText.length > 50 ? '${cleanText.substring(0, 50)}...' : cleanText}');
    } catch (error) {
      AppLogger.error('Failed to speak enhanced text', error);
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (error) {
      AppLogger.error('Failed to stop TTS', error);
    }
  }

  /// Test current voice settings
  Future<void> testVoice() async {
    await speak(
        'This is a test of the text to speech system. How does this sound?');
  }

  /// Test boxing-specific voice
  Future<void> testBoxingVoice() async {
    await speak('One two slip two');
  }

  /// Test workout voice
  Future<void> testWorkoutVoice() async {
    await speak('Three more reps');
  }

  /// Speaks a rest-timer completion phrase. Used by the real rest end
  /// (TimerBloc) and suitable for the profile "Timer" preview, so both use
  /// the same engine, voice, rate and pitch.
  Future<void> speakRestComplete(String phrase) =>
      speak(phrase, context: 'timer_completion');

  // Getters and setters for settings
  bool get isInitialized => _isInitialized;
  double get speechRate => _speechRate;
  double get volume => _volume;
  double get pitch => _pitch;
  String get selectedVoice => _selectedVoice;
  int get enthusiasmLevel => _enthusiasmLevel;
  bool get useMotivationalPhrases => _useMotivationalPhrases;
  bool get useEmphasis => _useEmphasis;
  List<Map<String, String>> get availableVoices => _availableVoices;

  /// Update speech rate
  Future<void> setSpeechRate(double rate) async {
    await initialize();
    _speechRate = rate.clamp(0.1, 2.0);
    try {
      await _tts?.setSpeechRate(_speechRate);
    } catch (error) {
      AppLogger.error('Failed to set speech rate', error);
    }
    await _saveSettings();
  }

  /// Update volume
  Future<void> setVolume(double volume) async {
    await initialize();
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _tts?.setVolume(_volume);
    } catch (error) {
      AppLogger.error('Failed to set volume', error);
    }
    await _saveSettings();
  }

  /// Update pitch
  Future<void> setPitch(double pitch) async {
    await initialize();
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _tts?.setPitch(_pitch);
    } catch (error) {
      AppLogger.error('Failed to set pitch', error);
    }
    await _saveSettings();
  }

  /// Update selected voice
  Future<void> setVoice(String voiceName) async {
    await initialize();
    _selectedVoice = voiceName;
    await _applySettings();
    await _saveSettings();
  }

  /// Update enthusiasm level
  Future<void> setEnthusiasmLevel(int level) async {
    await initialize();
    _enthusiasmLevel = level.clamp(1, 5);
    await _saveSettings();
  }

  /// Toggle motivational phrases
  Future<void> setUseMotivationalPhrases(bool use) async {
    await initialize();
    _useMotivationalPhrases = use;
    await _saveSettings();
  }

  /// Toggle emphasis
  Future<void> setUseEmphasis(bool use) async {
    await initialize();
    _useEmphasis = use;
    await _saveSettings();
  }
}
