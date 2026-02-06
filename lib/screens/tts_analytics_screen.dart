import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:testfitness/services/gemini_tts_service.dart';
import 'package:testfitness/utils/app_logger.dart';

/// TTS Analytics Dashboard for cost optimization insights
class TTSAnalyticsScreen extends StatefulWidget {
  const TTSAnalyticsScreen({super.key});

  @override
  State<TTSAnalyticsScreen> createState() => _TTSAnalyticsScreenState();
}

class _TTSAnalyticsScreenState extends State<TTSAnalyticsScreen> {
  final GeminiTTSService _ttsService = GeminiTTSService();

  bool _isLoading = false;
  Map<String, dynamic> _analyticsData = {};
  List<Map<String, dynamic>> _mostUsedPhrases = [];
  String _exportData = '';

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load analytics for the last 30 days
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final analytics = await _ttsService.getAnalytics(
        startDate: startDate,
        endDate: endDate,
      );

      final mostUsed = await _ttsService.getMostUsedPhrases(limit: 20);

      setState(() {
        _analyticsData = analytics;
        _mostUsedPhrases = mostUsed;
      });

      AppLogger.info('Loaded TTS analytics: ${analytics.keys}');
    } catch (error) {
      AppLogger.error('Failed to load TTS analytics', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $error')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final exportData = await _ttsService.exportAnalyticsData();
      setState(() {
        _exportData = exportData;
      });

      if (mounted) {
        _showExportDialog();
      }
    } catch (error) {
      AppLogger.error('Failed to export analytics', error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $error')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Analytics Export'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              const Text('Analytics data exported successfully!'),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _exportData,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _exportData));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('📋 Analytics data copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy to Clipboard'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostUsedPhrases() {
    if (_mostUsedPhrases.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
              'No usage data available yet. Start using TTS to see analytics!'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up),
                const SizedBox(width: 8),
                Text(
                  'Most Used Phrases (Pre-generation Candidates)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...(_mostUsedPhrases
                .take(10)
                .map((phrase) => _buildPhraseItem(phrase))),
            if (_mostUsedPhrases.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${_mostUsedPhrases.length - 10} more phrases',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhraseItem(Map<String, dynamic> phrase) {
    final text = phrase['original_text'] as String? ?? '';
    final usageCount = phrase['usage_count'] as int? ?? 0;
    final phraseContext = phrase['context'] as String? ?? '';
    final estimatedSavings = phrase['estimated_savings'] as double? ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  text.length > 60 ? '${text.substring(0, 60)}...' : text,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${usageCount}x',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Context: $phraseContext',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              if (estimatedSavings > 0)
                Text(
                  'Savings: \$${estimatedSavings.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 TTS Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAnalytics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Analytics',
          ),
          IconButton(
            onPressed: _isLoading ? null : _exportAnalytics,
            icon: const Icon(Icons.download),
            tooltip: 'Export Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  if (_analyticsData.isNotEmpty) ...[
                    const Text(
                      '📈 Usage Summary (Last 30 Days)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                  ],

                  // Most Used Phrases
                  const Text(
                    '🎯 Pre-generation Opportunities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildMostUsedPhrases(),

                  const SizedBox(height: 24),

                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline),
                              const SizedBox(width: 8),
                              Text(
                                'Cost Optimization Strategy',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Use the app normally to collect TTS usage data\n'
                            '2. Review "Most Used Phrases" to identify pre-generation candidates\n'
                            '3. Generate audio files once for frequently used phrases\n'
                            '4. Implement hybrid system: pre-recorded for common, live TTS for new\n'
                            '5. Monitor savings and optimize based on usage patterns',
                            style: TextStyle(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    // Extract summary data from analytics
    final savingsSummary =
        _analyticsData['savings_summary'] as Map<String, dynamic>? ?? {};
    final totalSavings =
        savingsSummary['total_potential_savings'] as double? ?? 0.0;
    final phrasesWithSavings =
        savingsSummary['phrases_with_savings'] as int? ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Potential Savings',
                '\$${totalSavings.toStringAsFixed(4)}',
                'From pre-generating common phrases',
                Icons.savings,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Optimization Candidates',
                '$phrasesWithSavings',
                'Phrases worth pre-generating',
                Icons.auto_awesome,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Phrases Tracked',
                '${_mostUsedPhrases.length}',
                'Unique phrases in database',
                Icons.format_quote,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Data Collection',
                'Active',
                'Analytics running in background',
                Icons.analytics,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
