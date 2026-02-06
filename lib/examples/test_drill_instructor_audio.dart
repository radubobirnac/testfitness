import 'package:flutter/material.dart';
import 'package:testfitness/services/boxing_audio_controller.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Test screen for drill instructor audio system
class TestDrillInstructorAudio extends StatefulWidget {
  const TestDrillInstructorAudio({super.key});

  @override
  State<TestDrillInstructorAudio> createState() => _TestDrillInstructorAudioState();
}

class _TestDrillInstructorAudioState extends State<TestDrillInstructorAudio> {
  final BoxingAudioController _audioController = BoxingAudioController();
  String _status = 'Ready to test';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      setState(() {
        _status = 'Initializing drill instructor audio...';
      });

      await _audioController.initialize();

      setState(() {
        _status = 'Drill instructor audio ready!';
        _isInitialized = true;
      });

      AppLogger.info('Drill instructor audio test initialized successfully');
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize: ${e.toString()}';
      });
      AppLogger.error('Failed to initialize drill instructor audio test', e);
    }
  }

  Future<void> _testCountdown() async {
    try {
      setState(() {
        _status = 'Testing countdown...';
      });

      await _audioController.playCountdown();

      setState(() {
        _status = 'Countdown test complete!';
      });
    } catch (e) {
      setState(() {
        _status = 'Countdown test failed: ${e.toString()}';
      });
      AppLogger.error('Countdown test failed', e);
    }
  }

  Future<void> _testCombination(String combination) async {
    try {
      setState(() {
        _status = 'Testing combination: $combination';
      });

      await _audioController.callCombination(combination);

      setState(() {
        _status = 'Combination test complete: $combination';
      });
    } catch (e) {
      setState(() {
        _status = 'Combination test failed: ${e.toString()}';
      });
      AppLogger.error('Combination test failed for $combination', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎖️ Drill Instructor Audio Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.info, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Test buttons
            if (_isInitialized) ...[
              const Text(
                '🎖️ Drill Instructor Tests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Countdown test
              ElevatedButton.icon(
                onPressed: _testCountdown,
                icon: const Icon(Icons.timer),
                label: const Text('Test Countdown (3, 2, 1)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 12),

              // Combination tests
              const Text(
                '🥊 Boxing Combinations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCombinationButton('1-2'),
                  _buildCombinationButton('1-2-3'),
                  _buildCombinationButton('1-2-slip'),
                  _buildCombinationButton('1-2-slip-2'),
                  _buildCombinationButton('2-3-4'),
                  _buildCombinationButton('3-4-roll'),
                  _buildCombinationButton('1-2-3-duck'),
                  _buildCombinationButton('5-2-slip-3'),
                ],
              ),

              const SizedBox(height: 24),

              // Instructions
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 Test Instructions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• If audio files exist: You\'ll hear drill instructor voice\n'
                        '• If audio files missing: TTS fallback will be used\n'
                        '• Check logs for detailed information\n'
                        '• Test both countdown and combinations',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCombinationButton(String combination) {
    return ElevatedButton(
      onPressed: () => _testCombination(combination),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(combination),
    );
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }
}
