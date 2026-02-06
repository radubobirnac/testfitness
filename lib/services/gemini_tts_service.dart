import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:testfitness/services/tts_analytics_service.dart';

/// Gemini 2.5 TTS Service for high-quality text-to-speech
class GeminiTTSService {
  static final GeminiTTSService _instance = GeminiTTSService._internal();
  factory GeminiTTSService() => _instance;
  GeminiTTSService._internal();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  String? _apiKey;
  final TTSAnalyticsService _analytics = TTSAnalyticsService();

  // Available Gemini TTS voices
  static const List<String> availableVoices = [
    'Zephyr', // Bright
    'Puck', // Upbeat
    'Charon', // Informative
    'Kore', // Firm
    'Fenrir', // Excitable
    'Leda', // Youthful
    'Orus', // Firm
    'Aoede', // Breezy
    'Callirrhoe', // Easy-going
    'Autonoe', // Bright
    'Enceladus', // Breathy
    'Iapetus', // Clear
    'Umbriel', // Easy-going
    'Algieba', // Smooth
    'Despina', // Smooth
    'Erinome', // Clear
    'Algenib', // Gravelly
    'Rasalgethi', // Informative
    'Laomedeia', // Upbeat
    'Achernar', // Soft
    'Alnilam', // Firm
    'Schedar', // Even
    'Gacrux', // Mature
    'Pulcherrima', // Forward
    'Achird', // Friendly
    'Zubenelgenubi', // Casual
    'Vindemiatrix', // Gentle
    'Sadachbia', // Lively
    'Sadaltager', // Knowledgeable
    'Sulafat', // Warm
  ];

  // Voice descriptions for UI
  static const Map<String, String> voiceDescriptions = {
    'Zephyr': 'Bright',
    'Puck': 'Upbeat',
    'Charon': 'Informative',
    'Kore': 'Firm',
    'Fenrir': 'Excitable',
    'Leda': 'Youthful',
    'Orus': 'Firm',
    'Aoede': 'Breezy',
    'Callirrhoe': 'Easy-going',
    'Autonoe': 'Bright',
    'Enceladus': 'Breathy',
    'Iapetus': 'Clear',
    'Umbriel': 'Easy-going',
    'Algieba': 'Smooth',
    'Despina': 'Smooth',
    'Erinome': 'Clear',
    'Algenib': 'Gravelly',
    'Rasalgethi': 'Informative',
    'Laomedeia': 'Upbeat',
    'Achernar': 'Soft',
    'Alnilam': 'Firm',
    'Schedar': 'Even',
    'Gacrux': 'Mature',
    'Pulcherrima': 'Forward',
    'Achird': 'Friendly',
    'Zubenelgenubi': 'Casual',
    'Vindemiatrix': 'Gentle',
    'Sadachbia': 'Lively',
    'Sadaltager': 'Knowledgeable',
    'Sulafat': 'Warm',
  };

  // Settings
  String _selectedVoice = 'Kore';
  String _selectedModel = 'gemini-2.5-flash-preview-tts';

  // Preference keys
  static const String _selectedVoiceKey = 'gemini_tts_selected_voice';
  static const String _selectedModelKey = 'gemini_tts_selected_model';

  /// Initialize the Gemini TTS service
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('Gemini TTS Service already initialized');
      return;
    }

    try {
      AppLogger.info('=== Starting Gemini TTS Service initialization ===');

      // Step 1: Initialize AudioPlayer (re-enabled after successful API testing)
      AppLogger.info('Step 1: Initializing AudioPlayer...');
      _audioPlayer = AudioPlayer();
      AppLogger.info('Step 1: AudioPlayer initialized successfully');

      // Step 2: Get API key
      AppLogger.info('Step 2: Loading API key from environment...');
      _apiKey = dotenv.env['GEMINI_API_KEY'];
      AppLogger.info(
          'Step 2: API key loaded: ${_apiKey != null ? 'Yes (${_apiKey!.length} chars)' : 'No'}');

      if (_apiKey == null || _apiKey!.isEmpty) {
        final errorMsg = 'Gemini API key not found in .env file';
        AppLogger.error('Step 2: $errorMsg');
        throw Exception(errorMsg);
      }
      AppLogger.info('Step 2: API key validation passed');

      // Step 3: Load settings
      AppLogger.info('Step 3: Loading settings...');
      try {
        await _loadSettings();
        AppLogger.info(
            'Step 3: Settings loaded successfully - Voice: $_selectedVoice, Model: $_selectedModel');
      } catch (settingsError) {
        AppLogger.error('Step 3: Failed to load settings', settingsError);
        AppLogger.info('Step 3: Continuing with default settings');
        // Continue anyway with defaults
      }

      // Step 4: Mark as initialized
      AppLogger.info('Step 4: Marking service as initialized...');
      _isInitialized = true;
      AppLogger.info('=== Gemini TTS Service initialized successfully ===');
    } catch (error) {
      AppLogger.error('=== Failed to initialize Gemini TTS Service ===', error);
      AppLogger.error('Error type: ${error.runtimeType}');
      AppLogger.error('Error details: ${error.toString()}');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Load settings from preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedVoice = prefs.getString(_selectedVoiceKey) ?? 'Kore';
      _selectedModel =
          prefs.getString(_selectedModelKey) ?? 'gemini-2.5-flash-preview-tts';
      AppLogger.info('Gemini TTS settings loaded from preferences');
    } catch (error) {
      AppLogger.error('Failed to load Gemini TTS settings', error);
    }
  }

  /// Save settings to preferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedVoiceKey, _selectedVoice);
      await prefs.setString(_selectedModelKey, _selectedModel);
      AppLogger.info('Gemini TTS settings saved to preferences');
    } catch (error) {
      AppLogger.error('Failed to save Gemini TTS settings', error);
    }
  }

  /// Generate speech using Gemini TTS API
  Future<void> speak(String text,
      {String? customVoice, String? style, String context = 'general'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.trim().isEmpty) {
      AppLogger.warning('Cannot speak empty text');
      return;
    }

    try {
      AppLogger.info(
          'Generating speech with Gemini TTS: ${text.length > 50 ? '${text.substring(0, 50)}...' : text}');

      final voiceToUse = customVoice ?? _selectedVoice;
      final enhancedText = style != null ? '$style: $text' : text;

      // Track TTS usage for cost optimization analytics
      final costEstimate = _estimateGeminiTTSCost(enhancedText);
      await _analytics.trackTTSUsage(
        text: text, // Track original text, not enhanced
        context: context,
        serviceType: 'Gemini TTS',
        voice: voiceToUse,
        style: style,
        costEstimate: costEstimate,
      );

      final audioData = await _generateAudio(enhancedText, voiceToUse);

      if (_audioPlayer != null) {
        await _playAudio(audioData);
        AppLogger.info('Successfully played Gemini TTS audio');
      } else {
        AppLogger.info(
            'Audio generated successfully (${audioData.length} bytes) - AudioPlayer not available for playback');
      }
    } catch (error) {
      AppLogger.error('Failed to generate/play Gemini TTS audio', error);
      rethrow;
    }
  }

  /// Generate audio data from Gemini TTS API
  Future<Uint8List> _generateAudio(String text, String voice) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': text}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': voice}
          }
        }
      }
    };

    AppLogger.info('Gemini TTS Request URL: $url');
    AppLogger.info('Gemini TTS Request Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse('$url?key=$_apiKey'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    AppLogger.info('Gemini TTS Response Status: ${response.statusCode}');
    AppLogger.info('Gemini TTS Response Headers: ${response.headers}');
    AppLogger.info('Gemini TTS Response Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini TTS API error: ${response.statusCode} - ${response.body}');
    }

    final responseData = jsonDecode(response.body);

    // Debug the response structure
    AppLogger.info('Response structure: ${responseData.keys}');
    if (responseData.containsKey('candidates')) {
      AppLogger.info('Candidates structure: ${responseData['candidates']}');
    }

    final audioBase64 = responseData['candidates'][0]['content']['parts'][0]
        ['inlineData']['data'];

    return base64Decode(audioBase64);
  }

  /// Play audio data using AudioPlayer
  Future<void> _playAudio(Uint8List audioData) async {
    if (_audioPlayer == null) {
      throw Exception('AudioPlayer not initialized - cannot play audio');
    }

    try {
      AppLogger.info('Converting PCM audio data to WAV format...');

      // Convert raw PCM data to WAV format (AudioPlayer compatible)
      final wavData = _convertPCMToWAV(audioData);

      // Save audio to temporary file with WAV extension
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/gemini_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavData);

      AppLogger.info(
          'Saved WAV audio file: ${tempFile.path}, original PCM size: ${audioData.length} bytes, WAV size: ${wavData.length} bytes');

      // Play the WAV file
      await _audioPlayer!.play(DeviceFileSource(tempFile.path));
      AppLogger.info('Successfully started audio playback');

      // Clean up temp file after a delay
      Future.delayed(const Duration(seconds: 30), () {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
          AppLogger.info('Cleaned up temporary audio file');
        }
      });
    } catch (error) {
      AppLogger.error('Failed to play audio', error);
      rethrow;
    }
  }

  /// Convert raw PCM audio data to WAV format for AudioPlayer compatibility
  Uint8List _convertPCMToWAV(Uint8List pcmData) {
    // WAV file format specifications for Gemini TTS audio
    // Gemini typically returns 16-bit PCM at 24kHz sample rate
    const int sampleRate = 24000;
    const int bitsPerSample = 16;
    const int channels = 1; // Mono
    const int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    const int blockAlign = channels * (bitsPerSample ~/ 8);

    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;

    // Create WAV header (44 bytes)
    final List<int> wavHeader = [
      // RIFF header (12 bytes)
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      fileSize & 0xff, (fileSize >> 8) & 0xff, (fileSize >> 16) & 0xff,
      (fileSize >> 24) & 0xff, // File size
      0x57, 0x41, 0x56, 0x45, // "WAVE"

      // Format chunk (24 bytes)
      0x66, 0x6d, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // Chunk size (16 for PCM)
      1, 0, // Audio format (1 = PCM)
      channels, 0, // Number of channels
      sampleRate & 0xff, (sampleRate >> 8) & 0xff, (sampleRate >> 16) & 0xff,
      (sampleRate >> 24) & 0xff, // Sample rate
      byteRate & 0xff, (byteRate >> 8) & 0xff, (byteRate >> 16) & 0xff,
      (byteRate >> 24) & 0xff, // Byte rate
      blockAlign, 0, // Block align
      bitsPerSample, 0, // Bits per sample

      // Data chunk header (8 bytes)
      0x64, 0x61, 0x74, 0x61, // "data"
      dataSize & 0xff, (dataSize >> 8) & 0xff, (dataSize >> 16) & 0xff,
      (dataSize >> 24) & 0xff, // Data size
    ];

    // Combine WAV header with PCM data
    final wavData = Uint8List(wavHeader.length + pcmData.length);
    wavData.setRange(0, wavHeader.length, wavHeader);
    wavData.setRange(wavHeader.length, wavData.length, pcmData);

    AppLogger.info(
        'Converted PCM to WAV: ${pcmData.length} bytes PCM -> ${wavData.length} bytes WAV');
    return wavData;
  }

  /// Stop current audio playback
  Future<void> stop() async {
    try {
      await _audioPlayer?.stop();
    } catch (error) {
      AppLogger.error('Failed to stop audio playback', error);
    }
  }

  /// Test current voice settings
  Future<void> testVoice() async {
    await speak(
        'This is a test of the Gemini text to speech system. How does this sound?');
  }

  /// Test boxing-specific voice
  Future<void> testBoxingVoice() async {
    await speak('One two slip two',
        style: 'Say with high energy and motivation');
  }

  /// Test workout voice
  Future<void> testWorkoutVoice() async {
    await speak('Three more reps, you got this!',
        style: 'Say with encouragement');
  }

  // Getters and setters
  String get selectedVoice => _selectedVoice;
  String get selectedModel => _selectedModel;
  List<String> get voices => availableVoices;
  bool get isInitialized => _isInitialized;

  /// Set selected voice
  Future<void> setVoice(String voice) async {
    if (availableVoices.contains(voice)) {
      _selectedVoice = voice;
      await _saveSettings();
      AppLogger.info('Gemini TTS voice changed to: $voice');
    }
  }

  /// Set selected model
  Future<void> setModel(String model) async {
    _selectedModel = model;
    await _saveSettings();
    AppLogger.info('Gemini TTS model changed to: $model');
  }

  /// Get voice description
  String getVoiceDescription(String voice) {
    return voiceDescriptions[voice] ?? 'Unknown';
  }

  /// Debug method to test API connectivity without AudioPlayer
  Future<Map<String, dynamic>> debugAPICall() async {
    try {
      AppLogger.info('Starting debug API call...');

      // Test API key first
      if (_apiKey == null || _apiKey!.isEmpty) {
        _apiKey = dotenv.env['GEMINI_API_KEY'];
        if (_apiKey == null || _apiKey!.isEmpty) {
          return {
            'error': 'API key not found in .env file',
            'success': false,
            'step': 'API Key Check'
          };
        }
      }

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent';

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': 'Hello world'}
            ]
          }
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Kore'}
            }
          }
        }
      };

      AppLogger.info('Debug API Call - URL: $url');
      AppLogger.info(
          'Debug API Call - API Key: ${_apiKey?.substring(0, 10)}...');

      final response = await http.post(
        Uri.parse('$url?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      final result = {
        'statusCode': response.statusCode,
        'headers': response.headers,
        'body': response.body,
        'success': response.statusCode == 200,
        'step': 'API Call Complete'
      };

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData.containsKey('candidates') &&
              responseData['candidates'].isNotEmpty &&
              responseData['candidates'][0].containsKey('content')) {
            result['audioDataFound'] = true;
            result['audioSize'] = responseData['candidates'][0]['content']
                        ['parts'][0]['inlineData']['data']
                    ?.length ??
                0;
          } else {
            result['audioDataFound'] = false;
          }
        } catch (parseError) {
          result['parseError'] = parseError.toString();
        }
      }

      return result;
    } catch (error) {
      AppLogger.error('Debug API call failed', error);
      return {
        'error': error.toString(),
        'success': false,
        'step': 'Exception Caught'
      };
    }
  }

  /// Estimate cost for Gemini TTS API call
  double _estimateGeminiTTSCost(String text) {
    // Gemini TTS pricing: approximately $0.000015 per character
    // This is an estimate based on typical TTS pricing models
    const double costPerCharacter = 0.000015;
    return text.length * costPerCharacter;
  }

  /// Get TTS analytics data
  Future<Map<String, dynamic>> getAnalytics(
      {DateTime? startDate, DateTime? endDate}) async {
    return await _analytics.getUsageAnalytics(
        startDate: startDate, endDate: endDate);
  }

  /// Get most used phrases for pre-generation
  Future<List<Map<String, dynamic>>> getMostUsedPhrases(
      {int limit = 50}) async {
    return await _analytics.getMostUsedPhrases(limit: limit);
  }

  /// Export analytics data
  Future<String> exportAnalyticsData() async {
    return await _analytics.exportAnalyticsData();
  }

  /// Get detailed initialization status for debugging
  Map<String, dynamic> getInitializationStatus() {
    return {
      'isInitialized': _isInitialized,
      'hasApiKey': _apiKey != null && _apiKey!.isNotEmpty,
      'apiKeyLength': _apiKey?.length ?? 0,
      'selectedVoice': _selectedVoice,
      'selectedModel': _selectedModel,
      'audioPlayerExists': _audioPlayer != null,
      'analyticsStatus': _analytics.getAnalyticsStatus(),
    };
  }
}
