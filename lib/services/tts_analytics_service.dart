import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/services/database_service.dart';

/// TTS Usage Analytics Service for cost optimization
///
/// Tracks all TTS requests to identify frequently used phrases
/// for pre-generation and cost savings
class TTSAnalyticsService {
  static final TTSAnalyticsService _instance = TTSAnalyticsService._internal();
  factory TTSAnalyticsService() => _instance;
  TTSAnalyticsService._internal();

  Database? _database;
  bool _isInitialized = false;

  /// Initialize the analytics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _database = await DatabaseService().database;
      await _createAnalyticsTables();
      _isInitialized = true;
      AppLogger.info('TTS Analytics Service initialized successfully');
    } catch (error) {
      AppLogger.error('Failed to initialize TTS Analytics Service', error);
      rethrow;
    }
  }

  /// Create analytics tables if they don't exist
  Future<void> _createAnalyticsTables() async {
    if (_database == null) return;

    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS tts_usage_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        context TEXT NOT NULL,
        service_type TEXT NOT NULL,
        voice_used TEXT,
        style_used TEXT,
        character_count INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        cost_estimate REAL DEFAULT 0.0
      )
    ''');

    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS tts_phrase_frequency (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text_hash TEXT UNIQUE NOT NULL,
        original_text TEXT NOT NULL,
        context TEXT NOT NULL,
        usage_count INTEGER DEFAULT 1,
        first_used INTEGER NOT NULL,
        last_used INTEGER NOT NULL,
        total_characters INTEGER NOT NULL,
        estimated_savings REAL DEFAULT 0.0
      )
    ''');

    AppLogger.info('TTS Analytics tables created successfully');
  }

  /// Track a TTS usage event
  Future<void> trackTTSUsage({
    required String text,
    required String context,
    required String serviceType,
    String? voice,
    String? style,
    double costEstimate = 0.0,
  }) async {
    if (!_isInitialized) await initialize();
    if (_database == null) return;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final characterCount = text.length;

      // Insert usage record
      await _database!.insert('tts_usage_analytics', {
        'text': text,
        'context': context,
        'service_type': serviceType,
        'voice_used': voice,
        'style_used': style,
        'character_count': characterCount,
        'timestamp': timestamp,
        'cost_estimate': costEstimate,
      });

      // Update frequency tracking
      await _updatePhraseFrequency(text, context, characterCount, timestamp);

      AppLogger.info(
          'Tracked TTS usage: ${text.length > 50 ? '${text.substring(0, 50)}...' : text} [$serviceType]');
    } catch (error) {
      AppLogger.error('Failed to track TTS usage', error);
    }
  }

  /// Update phrase frequency for cost optimization analysis
  Future<void> _updatePhraseFrequency(
      String text, String context, int characterCount, int timestamp) async {
    if (_database == null) return;

    try {
      final textHash = _generateTextHash(text, context);

      // Check if phrase already exists
      final existing = await _database!.query(
        'tts_phrase_frequency',
        where: 'text_hash = ?',
        whereArgs: [textHash],
      );

      if (existing.isNotEmpty) {
        // Update existing record
        final currentCount = existing.first['usage_count'] as int;
        final totalChars = existing.first['total_characters'] as int;

        await _database!.update(
          'tts_phrase_frequency',
          {
            'usage_count': currentCount + 1,
            'last_used': timestamp,
            'total_characters': totalChars + characterCount,
            'estimated_savings': _calculateEstimatedSavings(
                currentCount + 1, totalChars + characterCount),
          },
          where: 'text_hash = ?',
          whereArgs: [textHash],
        );
      } else {
        // Insert new record
        await _database!.insert('tts_phrase_frequency', {
          'text_hash': textHash,
          'original_text': text,
          'context': context,
          'usage_count': 1,
          'first_used': timestamp,
          'last_used': timestamp,
          'total_characters': characterCount,
          'estimated_savings': 0.0,
        });
      }
    } catch (error) {
      AppLogger.error('Failed to update phrase frequency', error);
    }
  }

  /// Generate unique hash for text + context combination
  String _generateTextHash(String text, String context) {
    final combined = '${text.toLowerCase().trim()}_$context';
    return combined.hashCode.toString();
  }

  /// Calculate estimated cost savings for pre-generating this phrase
  double _calculateEstimatedSavings(int usageCount, int totalCharacters) {
    // Rough estimate: $0.000015 per character for Gemini TTS
    const double costPerCharacter = 0.000015;

    if (usageCount <= 1) return 0.0;

    // Savings = (usage_count - 1) * character_cost
    // We save on all uses after the first generation
    return (usageCount - 1) * totalCharacters * costPerCharacter;
  }

  /// Get most frequently used phrases for pre-generation
  Future<List<Map<String, dynamic>>> getMostUsedPhrases(
      {int limit = 50}) async {
    if (!_isInitialized) await initialize();
    if (_database == null) return [];

    try {
      final results = await _database!.query(
        'tts_phrase_frequency',
        orderBy: 'usage_count DESC, estimated_savings DESC',
        limit: limit,
      );

      AppLogger.info(
          'Retrieved ${results.length} most used phrases for analysis');
      return results;
    } catch (error) {
      AppLogger.error('Failed to get most used phrases', error);
      return [];
    }
  }

  /// Get usage analytics for a specific time period
  Future<Map<String, dynamic>> getUsageAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) await initialize();
    if (_database == null) return {};

    try {
      final start = startDate?.millisecondsSinceEpoch ?? 0;
      final end = endDate?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;

      // Total usage stats
      final totalUsage = await _database!.rawQuery('''
        SELECT 
          COUNT(*) as total_requests,
          SUM(character_count) as total_characters,
          SUM(cost_estimate) as total_estimated_cost,
          COUNT(DISTINCT context) as unique_contexts,
          service_type
        FROM tts_usage_analytics 
        WHERE timestamp BETWEEN ? AND ?
        GROUP BY service_type
      ''', [start, end]);

      // Top phrases by frequency
      final topPhrases = await _database!.rawQuery('''
        SELECT original_text, context, usage_count, estimated_savings
        FROM tts_phrase_frequency
        WHERE last_used BETWEEN ? AND ?
        ORDER BY usage_count DESC
        LIMIT 20
      ''', [start, end]);

      // Potential savings summary
      final savingsSummary = await _database!.rawQuery('''
        SELECT 
          SUM(estimated_savings) as total_potential_savings,
          COUNT(*) as phrases_with_savings,
          AVG(usage_count) as avg_usage_per_phrase
        FROM tts_phrase_frequency
        WHERE estimated_savings > 0 AND last_used BETWEEN ? AND ?
      ''', [start, end]);

      return {
        'period': {
          'start': DateTime.fromMillisecondsSinceEpoch(start),
          'end': DateTime.fromMillisecondsSinceEpoch(end),
        },
        'usage_by_service': totalUsage,
        'top_phrases': topPhrases,
        'savings_summary':
            savingsSummary.isNotEmpty ? savingsSummary.first : {},
        'generated_at': DateTime.now(),
      };
    } catch (error) {
      AppLogger.error('Failed to get usage analytics', error);
      return {};
    }
  }

  /// Export analytics data for external analysis
  Future<String> exportAnalyticsData() async {
    if (!_isInitialized) await initialize();

    try {
      final analytics = await getUsageAnalytics();
      final mostUsed = await getMostUsedPhrases(limit: 100);

      final exportData = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'analytics': analytics,
        'most_used_phrases': mostUsed,
      };

      final jsonData = jsonEncode(exportData);
      AppLogger.info(
          'Exported TTS analytics data (${jsonData.length} characters)');

      return jsonData;
    } catch (error) {
      AppLogger.error('Failed to export analytics data', error);
      return '{}';
    }
  }

  /// Clear old analytics data (keep last N days)
  Future<void> cleanupOldData({int keepDays = 90}) async {
    if (!_isInitialized) await initialize();
    if (_database == null) return;

    try {
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: keepDays))
          .millisecondsSinceEpoch;

      final deletedUsage = await _database!.delete(
        'tts_usage_analytics',
        where: 'timestamp < ?',
        whereArgs: [cutoffTime],
      );

      final deletedFrequency = await _database!.delete(
        'tts_phrase_frequency',
        where: 'last_used < ?',
        whereArgs: [cutoffTime],
      );

      AppLogger.info(
          'Cleaned up old TTS analytics: $deletedUsage usage records, $deletedFrequency frequency records');
    } catch (error) {
      AppLogger.error('Failed to cleanup old analytics data', error);
    }
  }

  /// Get current analytics status
  Map<String, dynamic> getAnalyticsStatus() {
    return {
      'is_initialized': _isInitialized,
      'database_available': _database != null,
      'service_version': '1.0.0',
    };
  }
}
