import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';
import 'enhanced_tts_service.dart';
import 'workout_audio_files.dart';

/// High-quality audio player service for workout audio using pre-recorded OpenAI TTS files
///
/// This service replaces the default Flutter TTS with high-quality pre-recorded audio files
/// generated using OpenAI's TTS API. It provides:
/// - Offline audio playback after initial setup
/// - High-quality voice with consistent pronunciation
/// - Fast, reliable audio playback
/// - Fallback to system TTS if audio files are missing
/// - Pre-loading for better performance
class WorkoutAudioPlayer {
  static final WorkoutAudioPlayer _instance = WorkoutAudioPlayer._internal();
  factory WorkoutAudioPlayer() => _instance;
  WorkoutAudioPlayer._internal();

  // Audio players for different categories
  final Map<String, AudioPlayer> _players = {};
  final Map<String, bool> _preloadedCategories = {};

  // Settings
  double _volume = 0.9;
  bool _isInitialized = false;
  bool _useFallbackTTS = false;

  // Fallback TTS (Enhanced TTS Service)
  EnhancedTTSService? _fallbackTTS;

  /// Initialize the audio player service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('Initializing WorkoutAudioPlayer...');

      // Initialize audio players for each category
      final categories = [
        'timing',
        'motivation',
        'instructions',
        'rest',
        'combinations'
      ];

      for (final category in categories) {
        _players[category] = AudioPlayer();
        await _players[category]!.setPlayerMode(PlayerMode.lowLatency);
        await _players[category]!.setVolume(_volume);
        _preloadedCategories[category] = false;
      }

      // Check if audio files exist
      await _checkAudioFilesAvailability();

      // ALWAYS initialize drill instructor TTS (for missing audio files)
      await _initializeFallbackTTS();

      _isInitialized = true;
      AppLogger.info('WorkoutAudioPlayer initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize WorkoutAudioPlayer', e);
      _useFallbackTTS = true;
      await _initializeFallbackTTS();
      _isInitialized = true;
    }
  }

  /// Check if pre-recorded audio files are available
  Future<void> _checkAudioFilesAvailability() async {
    try {
      // Try to load a real generated audio file to check if assets exist
      final testAsset = WorkoutAudioFiles.timing.values.first;
      await rootBundle.load(testAsset);

      AppLogger.info('Pre-recorded audio files detected');
      _useFallbackTTS = false;
    } catch (e) {
      AppLogger.warning(
          'Pre-recorded audio files not found, DISABLING BORING TTS per user preference');
      // User wants NO boring TTS - disable fallback completely
      _useFallbackTTS = false;
    }
  }

  /// Initialize drill instructor TTS service
  Future<void> _initializeFallbackTTS() async {
    try {
      // Initialize the Enhanced TTS Service with DRILL INSTRUCTOR settings
      _fallbackTTS = EnhancedTTSService();
      await _fallbackTTS!.initialize();

      // Configure for DRILL INSTRUCTOR voice
      await _fallbackTTS!.setSpeechRate(0.8); // Faster, more commanding
      await _fallbackTTS!.setPitch(1.2); // Higher pitch for authority
      await _fallbackTTS!.setVolume(1.0); // Maximum volume
      await _fallbackTTS!.setEnthusiasmLevel(5); // Maximum enthusiasm

      AppLogger.info(
          '🎖️ DRILL INSTRUCTOR TTS initialized and ready to COMMAND!');
    } catch (e) {
      AppLogger.error('Failed to initialize drill instructor TTS', e);
    }
  }

  /// Pre-load audio files for a specific category for better performance
  Future<void> preloadCategory(String category) async {
    if (!_isInitialized) await initialize();
    if (_useFallbackTTS || _preloadedCategories[category] == true) return;

    try {
      AppLogger.info('Pre-loading audio category: $category');

      // Pre-load common files for this category
      final commonFiles = _getCommonFilesForCategory(category);

      for (final audioPath in commonFiles) {
        try {
          await _players[category]!.setSource(AssetSource(audioPath));
          await Future.delayed(
              const Duration(milliseconds: 50)); // Small delay between loads
        } catch (e) {
          AppLogger.warning('Failed to preload $audioPath: $e');
        }
      }

      _preloadedCategories[category] = true;
      AppLogger.info('Pre-loaded $category category');
    } catch (e) {
      AppLogger.error('Failed to preload category $category', e);
    }
  }

  /// Get common audio files for a category (most frequently used)
  List<String> _getCommonFilesForCategory(String category) {
    // Get the first few files from each category for preloading
    final categoryFiles = WorkoutAudioFiles.getCategory(category);
    final filePaths = categoryFiles.values.take(3).toList();

    // Remove the 'assets/' prefix since audioplayers expects relative paths
    return filePaths.map((path) => path.replaceFirst('assets/', '')).toList();
  }

  /// Play audio for specific text and category (DRILL INSTRUCTOR VOICE)
  Future<void> playAudio(String text, String category,
      {String context = 'general'}) async {
    if (!_isInitialized) await initialize();

    try {
      // Try to find and play pre-recorded audio first
      final audioPath = _getAudioPathForText(text, category);

      if (audioPath != null) {
        await _playPrerecordedAudio(audioPath, category);
      } else {
        // Use DRILL INSTRUCTOR TTS for missing audio
        AppLogger.info('🎖️ Using DRILL INSTRUCTOR TTS for: $text');
        await _fallbackTTS?.speak(text, context: 'boxing');
      }
    } catch (e) {
      AppLogger.error('Failed to play drill instructor audio for: $text', e);
      // Try drill instructor TTS as backup
      try {
        AppLogger.info('🎖️ Backup DRILL INSTRUCTOR TTS for: $text');
        await _fallbackTTS?.speak(text, context: 'boxing');
      } catch (ttsError) {
        AppLogger.error('Drill instructor TTS also failed', ttsError);
      }
    }
  }

  /// Play pre-recorded audio file
  Future<void> _playPrerecordedAudio(String audioPath, String category) async {
    final player = _players[category];
    if (player == null) return;

    try {
      await player.stop(); // Stop any currently playing audio

      // Remove 'assets/' prefix if present since AssetSource expects relative path
      final cleanPath =
          audioPath.startsWith('assets/') ? audioPath.substring(7) : audioPath;

      AppLogger.info('🎵 Attempting to play HIGH-ENERGY audio: $cleanPath');
      await player.play(AssetSource(cleanPath));

      AppLogger.info('✅ CRUSHING IT with audio: ${cleanPath.split('/').last}');
    } catch (e) {
      AppLogger.error('❌ Failed to play ENERGY audio: $audioPath', e);
      rethrow;
    }
  }

  /// Get audio file path for specific text using generated mappings
  String? _getAudioPathForText(String text, String category) {
    // Use the generated WorkoutAudioFiles class for accurate mappings
    return WorkoutAudioFiles.getAudioPath(text, category);
  }

  /// Stop all audio playback
  Future<void> stopAll() async {
    try {
      for (final player in _players.values) {
        await player.stop();
      }

      // Stop fallback TTS if active
      await _fallbackTTS?.stop();
    } catch (e) {
      AppLogger.error('Failed to stop all audio', e);
    }
  }

  /// Set volume for all players
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);

    try {
      for (final player in _players.values) {
        await player.setVolume(_volume);
      }
    } catch (e) {
      AppLogger.error('Failed to set volume', e);
    }
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    try {
      for (final player in _players.values) {
        await player.dispose();
      }
      _players.clear();
      _preloadedCategories.clear();
      _isInitialized = false;
    } catch (e) {
      AppLogger.error('Failed to dispose WorkoutAudioPlayer', e);
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isUsingFallbackTTS => _useFallbackTTS;
  double get volume => _volume;
}
