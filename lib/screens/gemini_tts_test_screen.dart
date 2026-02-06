import 'package:flutter/material.dart';
import 'package:testfitness/services/gemini_tts_service.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Test environment for Gemini TTS functionality
class GeminiTTSTestScreen extends StatefulWidget {
  const GeminiTTSTestScreen({super.key});

  @override
  State<GeminiTTSTestScreen> createState() => _GeminiTTSTestScreenState();
}

class _GeminiTTSTestScreenState extends State<GeminiTTSTestScreen> {
  final GeminiTTSService _ttsService = GeminiTTSService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _styleController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialized = false;
  String _selectedVoice = 'Kore';
  String _selectedModel = 'gemini-2.5-flash-preview-tts';
  String _status = 'Ready to test';

  // Predefined test phrases
  final List<Map<String, String>> _testPhrases = [
    {
      'text': 'Hello! This is a test of the Gemini text to speech system.',
      'style': 'Say cheerfully',
    },
    {
      'text': 'One two slip two, three four duck five',
      'style': 'Say with high energy like a boxing coach',
    },
    {
      'text': 'Three more reps, you got this!',
      'style': 'Say with motivation and encouragement',
    },
    {
      'text': 'Rest for 60 seconds, then we continue',
      'style': 'Say calmly and clearly',
    },
    {
      'text': 'Workout complete! Great job today.',
      'style': 'Say with pride and satisfaction',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _textController.text = _testPhrases[0]['text']!;
    _styleController.text = _testPhrases[0]['style']!;
  }

  @override
  void dispose() {
    _textController.dispose();
    _styleController.dispose();
    super.dispose();
  }

  Future<void> _initializeTTS() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing Gemini TTS...';
    });

    try {
      await _ttsService.initialize();
      setState(() {
        _isInitialized = true;
        _selectedVoice = _ttsService.selectedVoice;
        _selectedModel = _ttsService.selectedModel;
        _status = 'Ready to test';
      });
    } catch (error) {
      final errorMessage = _getErrorMessage(error);
      setState(() {
        _status = 'Failed to initialize: $errorMessage';
      });
      AppLogger.error('Failed to initialize Gemini TTS', error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSpeech() async {
    if (!_isInitialized || _textController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _status = 'Generating speech...';
    });

    try {
      final text = _textController.text.trim();
      final style = _styleController.text.trim();

      setState(() {
        _status = 'Calling Gemini API...';
      });

      await _ttsService.speak(
        text,
        customVoice: _selectedVoice,
        style: style.isNotEmpty ? style : null,
      );

      setState(() {
        _status = 'Speech generated and played successfully!';
      });

      // Show success dialog with details
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Speech Generation Success'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Text: "$text"'),
                if (style.isNotEmpty) Text('Style: "$style"'),
                Text('Voice: $_selectedVoice'),
                Text('Model: $_selectedModel'),
                const SizedBox(height: 16),
                const Text(
                  '🔊 Audio was generated and played successfully!',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      final errorMessage = _getErrorMessage(error);
      setState(() {
        _status = 'Error: $errorMessage';
      });

      // Show error dialog with details
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ Speech Generation Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Error: $errorMessage'),
                const SizedBox(height: 16),
                Text('Text: "${_textController.text.trim()}"'),
                Text('Voice: $_selectedVoice'),
                Text('Model: $_selectedModel'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      AppLogger.error('Failed to generate speech', error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _stopSpeech() async {
    try {
      await _ttsService.stop();
      setState(() {
        _status = 'Speech stopped';
      });
    } catch (error) {
      AppLogger.error('Failed to stop speech', error);
    }
  }

  Future<void> _debugAPI() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing API connectivity...';
    });

    try {
      final result = await _ttsService.debugAPICall();

      // Show detailed results in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result['success'] == true
                ? '✅ API Test Results'
                : '❌ API Test Failed'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDebugRow('Success', result['success'].toString()),
                  _buildDebugRow(
                      'Status Code', result['statusCode'].toString()),
                  _buildDebugRow('Step', result['step'] ?? 'Unknown'),
                  if (result['error'] != null)
                    _buildDebugRow('Error', result['error']),
                  if (result['audioDataFound'] != null)
                    _buildDebugRow('Audio Data Found',
                        result['audioDataFound'].toString()),
                  if (result['audioSize'] != null)
                    _buildDebugRow(
                        'Audio Size (bytes)', result['audioSize'].toString()),
                  if (result['parseError'] != null)
                    _buildDebugRow('Parse Error', result['parseError']),
                  const SizedBox(height: 16),
                  const Text('Raw Response:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result['body']?.toString() ?? 'No response body',
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace'),
                    ),
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

      setState(() {
        if (result['success'] == true) {
          _status = 'API test successful! Status: ${result['statusCode']}';
          if (result['audioDataFound'] == true) {
            _status += ' - Audio generated (${result['audioSize']} bytes)';
          }
        } else {
          _status =
              'API test failed: ${result['error'] ?? 'Status ${result['statusCode']}'}';
        }
      });

      // Log detailed results
      AppLogger.info('API Debug Result: $result');
    } catch (error) {
      final errorMessage = _getErrorMessage(error);
      setState(() {
        _status = 'API test error: $errorMessage';
      });
      AppLogger.error('API debug test failed', error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadTestPhrase(int index) {
    if (index >= 0 && index < _testPhrases.length) {
      setState(() {
        _textController.text = _testPhrases[index]['text']!;
        _styleController.text = _testPhrases[index]['style']!;
      });
    }
  }

  void _showDebugInfo() {
    final status = _ttsService.getInitializationStatus();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDebugRow('Initialized', status['isInitialized'].toString()),
              _buildDebugRow('Has API Key', status['hasApiKey'].toString()),
              _buildDebugRow(
                  'API Key Length', status['apiKeyLength'].toString()),
              _buildDebugRow('Selected Voice', status['selectedVoice']),
              _buildDebugRow('Selected Model', status['selectedModel']),
              _buildDebugRow(
                  'AudioPlayer Exists', status['audioPlayerExists'].toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _debugAPI();
                },
                child: const Text('Test API Call'),
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

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error == null) return 'Unknown error';

    // Handle different error types
    if (error is Exception) {
      return error.toString();
    } else if (error is Error) {
      return error.toString();
    } else if (error is String) {
      return error;
    } else {
      // For any other type, try to get a meaningful message
      final errorString = error.toString();
      if (errorString.startsWith('Instance of ')) {
        return 'Error type: ${error.runtimeType}';
      }
      return errorString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini TTS Test Environment'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showDebugInfo,
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Debug Info'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Voice Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Selection',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedVoice,
                      decoration: const InputDecoration(
                        labelText: 'Voice',
                        border: OutlineInputBorder(),
                      ),
                      items: _ttsService.voices.map((voice) {
                        final description =
                            _ttsService.getVoiceDescription(voice);
                        return DropdownMenuItem(
                          value: voice,
                          child: Text('$voice ($description)'),
                        );
                      }).toList(),
                      onChanged: _isInitialized
                          ? (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedVoice = value;
                                });
                                _ttsService.setVoice(value);
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedModel,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'gemini-2.5-flash-preview-tts',
                          child: Text('Gemini 2.5 Flash TTS (Fast)'),
                        ),
                        DropdownMenuItem(
                          value: 'gemini-2.5-pro-preview-tts',
                          child: Text('Gemini 2.5 Pro TTS (High Quality)'),
                        ),
                      ],
                      onChanged: _isInitialized
                          ? (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedModel = value;
                                });
                                _ttsService.setModel(value);
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Phrases
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Test Phrases',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _testPhrases.asMap().entries.map((entry) {
                        final index = entry.key;
                        return ElevatedButton(
                          onPressed: _isInitialized
                              ? () => _loadTestPhrase(index)
                              : null,
                          child: Text('Test ${index + 1}'),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Text Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Text',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Text to speak',
                        hintText:
                            'Enter the text you want to convert to speech...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _styleController,
                      decoration: const InputDecoration(
                        labelText: 'Style (optional)',
                        hintText:
                            'e.g., "Say cheerfully" or "Say with high energy"',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isInitialized && !_isLoading ? _testSpeech : null,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isLoading ? 'Generating...' : 'Test Speech'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isInitialized ? _stopSpeech : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Debug Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isInitialized && !_isLoading ? _debugAPI : null,
                icon: const Icon(Icons.bug_report),
                label: const Text('Debug API Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'About Gemini TTS',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.blue.shade700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 30 high-quality voices available\n'
                      '• Controllable style with natural language\n'
                      '• 24 languages supported\n'
                      '• High-quality 24kHz audio output\n'
                      '• Real-time generation and playback',
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
}
