import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/services/tts_analytics_service.dart';

/// Enhanced TTS Service with voice quality improvements and enthusiasm controls
class EnhancedTTSService {
  static final EnhancedTTSService _instance = EnhancedTTSService._internal();
  factory EnhancedTTSService() => _instance;
  EnhancedTTSService._internal();

  late final FlutterTts _tts;
  bool _isInitialized = false;
  final TTSAnalyticsService _analytics = TTSAnalyticsService();

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

  /// Initialize the enhanced TTS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _tts = FlutterTts();
      await _loadSettings();
      await _discoverVoices();
      await _applySettings();

      _isInitialized = true;
      AppLogger.info('Enhanced TTS Service initialized successfully');
    } catch (error) {
      AppLogger.error('Failed to initialize Enhanced TTS Service', error);
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

  /// Discover and rank available voices
  Future<void> _discoverVoices() async {
    try {
      final voices = await _tts.getVoices;
      _availableVoices = voices.cast<Map<String, String>>();

      // Rank voices by quality (prefer enhanced, neural, premium voices)
      _availableVoices.sort((a, b) {
        final aName = a['name']?.toLowerCase() ?? '';
        final bName = b['name']?.toLowerCase() ?? '';

        // Priority scoring
        int aScore = 0;
        int bScore = 0;

        // Highest priority: Enhanced/Neural/Premium voices
        if (aName.contains('enhanced') ||
            aName.contains('neural') ||
            aName.contains('premium')) {
          aScore += 100;
        }
        if (bName.contains('enhanced') ||
            bName.contains('neural') ||
            bName.contains('premium')) {
          bScore += 100;
        }

        // High priority: Natural/High quality voices
        if (aName.contains('natural') ||
            aName.contains('high') ||
            aName.contains('quality')) {
          aScore += 50;
        }
        if (bName.contains('natural') ||
            bName.contains('high') ||
            bName.contains('quality')) {
          bScore += 50;
        }

        // Medium priority: Female voices (often clearer)
        if (aName.contains('female') ||
            aName.contains('woman') ||
            aName.contains('samantha') ||
            aName.contains('karen')) {
          aScore += 25;
        }
        if (bName.contains('female') ||
            bName.contains('woman') ||
            bName.contains('samantha') ||
            bName.contains('karen')) {
          bScore += 25;
        }

        // Prefer US English
        if (a['locale']?.contains('en-US') == true) aScore += 10;
        if (b['locale']?.contains('en-US') == true) bScore += 10;

        return bScore.compareTo(aScore);
      });

      AppLogger.info(
          'Discovered ${_availableVoices.length} voices, ranked by quality');

      // Auto-select best voice if none selected
      if (_selectedVoice.isEmpty && _availableVoices.isNotEmpty) {
        _selectedVoice = _availableVoices.first['name'] ?? '';
        AppLogger.info('Auto-selected best voice: $_selectedVoice');
      }
    } catch (error) {
      AppLogger.error('Failed to discover voices', error);
    }
  }

  /// Apply current settings to TTS engine
  Future<void> _applySettings() async {
    try {
      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(_volume);
      await _tts.setPitch(_pitch);

      // Set voice if available
      if (_selectedVoice.isNotEmpty) {
        final voice = _availableVoices.firstWhere(
          (v) => v['name'] == _selectedVoice,
          orElse: () => {},
        );
        if (voice.isNotEmpty) {
          await _tts.setVoice(voice);
          AppLogger.info('Applied voice: $_selectedVoice');
        }
      }

      AppLogger.info('TTS settings applied successfully');
    } catch (error) {
      AppLogger.error('Failed to apply TTS settings', error);
    }
  }

  /// Enhance text with basic formatting only (no motivational content)
  String _enhanceText(String text, {String context = 'general'}) {
    // Simply return the text as-is, no motivational enhancements
    return text;
  }

  /// Speak text with enhancements
  Future<void> speak(String text, {String context = 'general'}) async {
    if (!_isInitialized) {
      await initialize();
    }

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
          .replaceAll(RegExp(r'[^\w\s.,!?-]'),
              '') // Remove special chars except basic punctuation
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();

      if (cleanText.isEmpty) return;

      await _tts.speak(cleanText);
      AppLogger.info(
          'Enhanced TTS speaking: ${cleanText.length > 50 ? '${cleanText.substring(0, 50)}...' : cleanText}');
    } catch (error) {
      AppLogger.error('Failed to speak enhanced text', error);
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _tts.stop();
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

  // Getters and setters for settings
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
    _speechRate = rate.clamp(0.1, 2.0);
    await _tts.setSpeechRate(_speechRate);
    await _saveSettings();
  }

  /// Update volume
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
    await _saveSettings();
  }

  /// Update pitch
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    await _saveSettings();
  }

  /// Update selected voice
  Future<void> setVoice(String voiceName) async {
    _selectedVoice = voiceName;
    await _applySettings();
    await _saveSettings();
  }

  /// Update enthusiasm level
  Future<void> setEnthusiasmLevel(int level) async {
    _enthusiasmLevel = level.clamp(1, 5);
    await _saveSettings();
  }

  /// Toggle motivational phrases
  Future<void> setUseMotivationalPhrases(bool use) async {
    _useMotivationalPhrases = use;
    await _saveSettings();
  }

  /// Toggle emphasis
  Future<void> setUseEmphasis(bool use) async {
    _useEmphasis = use;
    await _saveSettings();
  }
}
