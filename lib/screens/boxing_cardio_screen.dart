import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:testfitness/services/boxing_service.dart';
import 'package:testfitness/services/heart_rate_service.dart';
import 'package:testfitness/services/user_profile_service.dart';
import 'package:testfitness/models/user_profile.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/offline_indicator.dart';
import 'package:testfitness/widgets/heart_rate_charts.dart';

/// Boxing cardio workout screen with combination callouts
class BoxingCardioScreen extends StatefulWidget {
  const BoxingCardioScreen({super.key});

  @override
  State<BoxingCardioScreen> createState() => _BoxingCardioScreenState();
}

class _BoxingCardioScreenState extends State<BoxingCardioScreen>
    with TickerProviderStateMixin {
  final BoxingService _boxingService = BoxingService();
  final HeartRateService _heartRateService = HeartRateService();
  final UserProfileService _profileService = UserProfileService();

  UserProfile? _userProfile;

  // Session configuration
  String _selectedStyle = 'traditional'; // Boxing style
  String _selectedDifficulty = 'intermediate';
  int _roundDuration = 180; // 3 minutes
  final int _restDuration = 60; // 1 minute
  int _totalRounds = 3;
  int _combinationInterval = 4; // seconds between combinations

  // Heart rate monitoring (automatically enabled when connected)
  int _currentHeartRate = 0;
  final List<HeartRateReading> _sessionReadings = [];
  int _maxHeartRate = 0;
  int _avgHeartRate = 0;
  String _currentHeartRateZone = '';
  String _heartRateCoaching = '';

  // Session state
  bool _isSessionActive = false;
  bool _isPaused = false;
  bool _isResting = false;
  int _currentRound = 0;
  String _currentCombination = '';

  StreamSubscription<int>? _heartRateSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _combinationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _combinationAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.info('🥊 Boxing Cardio Screen: Initializing');
    _loadUserProfile();
    _initializeAnimations();
    _initializeHeartRateService();
    AppLogger.info('🥊 Boxing Cardio Screen: Initialization complete');
  }

  void _loadUserProfile() async {
    _userProfile = await _profileService.loadProfile();
    if (mounted) {
      setState(() {});
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _combinationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _combinationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _combinationController,
      curve: Curves.elasticOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  void _initializeHeartRateService() {
    _heartRateService.initialize();

    // Listen to heart rate updates (automatically track when connected and session active)
    _heartRateSubscription =
        _heartRateService.heartRateStream.listen((heartRate) {
      if (mounted && _heartRateService.isConnected && _isSessionActive) {
        setState(() {
          _currentHeartRate = heartRate;

          // Add to session readings
          _sessionReadings.add(HeartRateReading(
            heartRate: heartRate,
            timestamp: DateTime.now(),
          ));

          // Update max heart rate
          if (heartRate > _maxHeartRate) {
            _maxHeartRate = heartRate;
          }

          // Calculate average heart rate
          if (_sessionReadings.isNotEmpty) {
            _avgHeartRate = (_sessionReadings
                        .map((r) => r.heartRate)
                        .reduce((a, b) => a + b) /
                    _sessionReadings.length)
                .round();
          }
        });

        // Calculate heart rate zone and coaching using user's age
        if (_userProfile != null) {
          _currentHeartRateZone =
              _userProfile!.getHeartRateSafetyMessage(_currentHeartRate);
          _heartRateCoaching =
              _userProfile!.getHeartRateSafetyMessage(_currentHeartRate);
        } else {
          // Fallback for users without profile (conservative approach)
          final conservativeAge = 40; // Conservative age for safety
          final zones =
              _heartRateService.calculateHeartRateZones(conservativeAge);
          _currentHeartRateZone =
              _heartRateService.getCurrentZone(conservativeAge);

          // Provide basic coaching based on zone
          if (_currentHeartRate > zones.peakZone.minBpm) {
            _heartRateCoaching =
                'High intensity - create profile for personalized guidance';
          } else if (_currentHeartRate > zones.cardioZone.minBpm) {
            _heartRateCoaching =
                'Good cardio zone - create profile for better coaching';
          } else if (_currentHeartRate > zones.fatBurnZone.minBpm) {
            _heartRateCoaching = 'Fat burning zone';
          } else {
            _heartRateCoaching = 'Warm up more for better results';
          }
        }

        // Log heart rate for debugging
        AppLogger.debug(
            'Boxing session heart rate: $heartRate BPM (Zone: $_currentHeartRateZone)');
      }
    });

    // Listen to connection status changes
    _connectionSubscription =
        _heartRateService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          if (!isConnected) {
            AppLogger.warning(
                'Heart rate monitor disconnected during boxing session');
          } else {
            AppLogger.info('Heart rate monitor connected to boxing session');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    AppLogger.info('🥊 Boxing Cardio Screen: Disposing');
    _heartRateSubscription?.cancel();
    _connectionSubscription?.cancel();
    // Cancels every timer, drops the registered callbacks and stops TTS.
    _boxingService.stopSession();
    _pulseController.dispose();
    _combinationController.dispose();
    // Note: NOT disposing heart rate service - it's a singleton that persists across screens
    AppLogger.info('🥊 Boxing Cardio Screen: Disposed');
    super.dispose();
  }

  void _startSession() async {
    try {
      AppLogger.info('🥊 Boxing Session: Starting session');
      AppLogger.info(
          '🥊 Heart Rate Status: ${_heartRateService.isConnected ? "Connected" : "Not connected"}');

      setState(() {
        _isSessionActive = true;
        _isPaused = false;
        _isResting = false;
        _currentRound = 1;
        _currentCombination = 'Get Ready!';

        // Reset heart rate data for new session (always reset, will track if connected)
        _sessionReadings.clear();
        _currentHeartRate = 0;
        _maxHeartRate = 0;
        _avgHeartRate = 0;
      });

      HapticFeedback.heavyImpact();

      await _boxingService.startBoxingSession(
        style: _selectedStyle,
        difficulty: _selectedDifficulty,
        roundDurationSeconds: _roundDuration,
        restDurationSeconds: _restDuration,
        totalRounds: _totalRounds,
        onCombinationCall: _onCombinationCall,
        onRoundComplete: _onRoundComplete,
        onSessionComplete: _onSessionComplete,
        onRestStart: _onRestStart,
        onRoundStart: _onRoundStart,
        combinationIntervalSeconds: _combinationInterval,
      );
    } catch (e) {
      AppLogger.error('Failed to start boxing session', e);
      if (!mounted) return;
      _showErrorSnackBar('Failed to start boxing session: ${e.toString()}');
    }
  }

  /// Ask before ending an active session (the stop button is easy to hit
  /// mid-workout).
  Future<void> _confirmStopSession() async {
    if (!_isSessionActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
            'Your boxing session is still in progress. Do you want to end it now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && _isSessionActive) {
      _stopSession();
    }
  }

  void _stopSession() {
    HapticFeedback.mediumImpact();
    _boxingService.stopSession();
    if (!mounted) return;
    setState(() {
      _isSessionActive = false;
      _isPaused = false;
      _isResting = false;
      _currentRound = 0;
      _currentCombination = '';
    });
  }

  void _pauseSession() {
    HapticFeedback.lightImpact();
    if (_isPaused) {
      _boxingService.resumeSession();
    } else {
      _boxingService.pauseSession();
    }

    setState(() {
      _isPaused = _boxingService.isPaused;
    });
  }

  void _onCombinationCall(String combination) {
    if (!mounted) return;
    setState(() {
      _currentCombination = combination;
    });

    _combinationController.forward().then((_) {
      if (mounted) _combinationController.reset();
    });

    HapticFeedback.lightImpact();
  }

  /// A new round begins: leave rest styling and show the new round number.
  void _onRoundStart(int round) {
    if (!mounted) return;
    setState(() {
      _currentRound = round;
      _isResting = false;
      _currentCombination = round == 1 ? 'Get Ready!' : 'Round $round';
    });
  }

  void _onRoundComplete(int round) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
  }

  void _onRestStart(int restSeconds) {
    if (!mounted || restSeconds < 0) return;
    setState(() {
      _isResting = true;
      _currentCombination = 'Rest Time';
    });
  }

  void _onSessionComplete() {
    if (!mounted) return;
    setState(() {
      _isSessionActive = false;
      _isPaused = false;
      _isResting = false;
      _currentCombination = 'Session Complete! 🥊';
    });

    HapticFeedback.heavyImpact();
    _showSuccessSnackBar('Boxing session completed! Great work! 🥊');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OfflineIndicator(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Boxing Cardio'),
          actions: [
            if (_isSessionActive)
              IconButton(
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                onPressed: _pauseSession,
                tooltip: _isPaused ? 'Resume' : 'Pause',
              ),
            if (_isSessionActive)
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _confirmStopSession,
                tooltip: 'Stop Session',
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (!_isSessionActive) _buildConfigurationSection(),
              if (_isSessionActive) _buildActiveSessionSection(),
              if (_isSessionActive &&
                  _heartRateService.isConnected &&
                  _sessionReadings.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildHeartRateChart(),
              ],
              const SizedBox(height: 24),
              _buildControlButtons(),
              const SizedBox(height: 24),
              _buildDifficultyInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Configuration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Boxing style selection
            Text(
              'Boxing Style',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: _boxingService.getBoxingStyles().map((style) {
                final isSelected = _selectedStyle == style;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedStyle = style;
                          // Update boxing service style
                          _boxingService.setBoxingStyle(style);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        foregroundColor: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        elevation: isSelected ? 2 : 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        style.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Difficulty selection
            Text(
              'Difficulty Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: _boxingService.getDifficultyLevels().map((level) {
                final isSelected = _selectedDifficulty == level;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDifficulty = level;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        foregroundColor: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        elevation: isSelected ? 2 : 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        level.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Round configuration
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rounds',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('$_totalRounds rounds',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600])),
                      Slider(
                        value: _totalRounds.toDouble(),
                        min: 1,
                        max: 12,
                        divisions: 11,
                        label: '$_totalRounds rounds',
                        onChanged: (value) {
                          setState(() {
                            _totalRounds = value.round();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Round Time',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                          '${(_roundDuration / 60).toStringAsFixed(1)} minutes',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600])),
                      Slider(
                        value: _roundDuration.toDouble(),
                        min: 60,
                        max: 300,
                        divisions: 8,
                        label: '${(_roundDuration / 60).toStringAsFixed(1)}m',
                        onChanged: (value) {
                          setState(() {
                            _roundDuration = value.round();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Heart rate monitoring status
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('Heart Rate Monitor',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Icon(
                  _heartRateService.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: _heartRateService.isConnected
                      ? Colors.green
                      : Colors.grey,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _heartRateService.isConnected
                        ? 'Connected - Heart rate will be tracked during session'
                        : 'Not connected - Connect for real-time heart rate tracking',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _heartRateService.isConnected
                              ? Colors.green
                              : Colors.grey[600],
                        ),
                  ),
                ),
                if (!_heartRateService.isConnected)
                  TextButton(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/heart-rate-monitor');
                      if (mounted) setState(() {}); // Refresh UI after returning
                    },
                    child: Text(
                      'Connect',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/heart-rate-monitor');
                      if (mounted) setState(() {}); // Refresh UI after returning
                    },
                    child: Text(
                      'Manage',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Combination timing
            Text('Combination Timing',
                style: Theme.of(context).textTheme.titleMedium),
            Text('$_combinationInterval seconds between calls',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
            Slider(
              value: _combinationInterval.toDouble(),
              min: 2,
              max: 8,
              divisions: 6,
              label: '${_combinationInterval}s',
              onChanged: (value) {
                setState(() {
                  _combinationInterval = value.round();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionSection() {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              // Round indicator with better styling
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(25),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Round $_currentRound of $_totalRounds',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                ),
              ),

              const SizedBox(height: 24),

              // Current combination display with improved design
              AnimatedBuilder(
                animation: _combinationAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_combinationAnimation.value * 0.05),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Status indicator with icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isResting
                                    ? Icons.pause_circle
                                    : Icons.sports_mma,
                                color: _isResting
                                    ? Colors.blue[600]
                                    : Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isResting ? 'REST TIME' : 'COMBINATION',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: _isResting
                                          ? Colors.blue[600]
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Main combination text
                          Text(
                            _currentCombination,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _isResting
                                      ? Colors.blue[700]
                                      : Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: 1.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Heart rate display during session
              if (_heartRateService.isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'CURRENT',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_currentHeartRate',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'BPM',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'MAX',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_maxHeartRate',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'AVG',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_avgHeartRate',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'ZONE',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _currentHeartRateZone,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Heart rate coaching message
                if (_heartRateCoaching.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _heartRateCoaching,
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Session status
              if (_isPaused)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'PAUSED',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    if (!_isSessionActive) {
      return SizedBox(
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: ElevatedButton.icon(
                onPressed: _startSession,
                icon: const Icon(Icons.sports_mma,
                    size: 28), // Better boxing icon
                label: const Text(
                  'START BOXING SESSION',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            );
          },
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pauseSession,
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(_isPaused ? 'RESUME' : 'PAUSE'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isPaused
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _confirmStopSession,
            icon: const Icon(Icons.stop),
            label: const Text('STOP'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateChart() {
    return HeartRateCharts.buildRealTimeChart(
      _sessionReadings,
      context,
      timeWindow: const Duration(minutes: 3), // Show last 3 minutes for boxing
    );
  }

  Widget _buildDifficultyInfo() {
    final sampleCombinations = _boxingService.getSampleCombinations(
        _selectedDifficulty, _selectedStyle);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_mma,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedStyle.toUpperCase()} ${_selectedDifficulty.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getStyleDescription(_selectedStyle),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sample combinations you\'ll hear:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sampleCombinations.take(6).map((combo) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    combo,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🥊 Boxing Guide',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Punches: 1=Jab, 2=Cross, 3=Left Hook, 4=Right Hook, 5=Left Uppercut, 6=Right Uppercut',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Defense: Slip, Duck, Roll, Block, Parry',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get description for boxing style
  String _getStyleDescription(String style) {
    switch (style) {
      case 'traditional':
        return 'Traditional boxing emphasizes fundamental techniques, balanced offense and defense, and classic combinations.';
      case 'cuban':
        return 'Cuban style focuses on rhythm, footwork, counter-punching, and fluid movement with technical precision.';
      case 'soviet':
        return 'Soviet style emphasizes systematic training, technical conditioning, and methodical power development.';
      default:
        return 'Classic boxing combinations and techniques.';
    }
  }
}
