import 'dart:async';

import 'package:flutter/material.dart';
import 'package:testfitness/services/vo2_max_service.dart';
import 'package:testfitness/services/heart_rate_service.dart';
import 'package:testfitness/services/user_profile_service.dart';
import 'package:testfitness/models/user_profile.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/offline_indicator.dart';
import 'package:testfitness/widgets/heart_rate_charts.dart';

/// Screen for VO2 max training with real-time heart rate zone coaching
class VO2MaxTrainingScreen extends StatefulWidget {
  const VO2MaxTrainingScreen({super.key});

  @override
  State<VO2MaxTrainingScreen> createState() => _VO2MaxTrainingScreenState();
}

class _VO2MaxTrainingScreenState extends State<VO2MaxTrainingScreen>
    with TickerProviderStateMixin {
  final VO2MaxService _vo2MaxService = VO2MaxService();
  final HeartRateService _heartRateService = HeartRateService();
  final UserProfileService _profileService = UserProfileService();

  UserProfile? _userProfile;

  // Training state
  bool _isTrainingActive = false;
  String _currentCoaching = '';
  HeartRateZoneStatus? _currentZoneStatus;

  // VO2 Max interval training state
  bool _isInInterval = false;
  int _currentInterval = 0;
  final int _totalIntervals = 5;
  final Duration _intervalDuration = const Duration(minutes: 1);
  final Duration _restDuration = const Duration(minutes: 2);
  final Duration _warmUpDuration = const Duration(minutes: 2);
  Duration _remainingTime = Duration.zero;
  Timer? _intervalTicker;
  DateTime? _phaseEndsAt;

  // Stream subscriptions (cancelled in dispose)
  StreamSubscription<String>? _coachingSubscription;
  StreamSubscription<HeartRateZoneStatus>? _zoneSubscription;
  StreamSubscription<int>? _heartRateSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  // Heart rate data
  int _currentHeartRate = 0;
  final List<HeartRateReading> _sessionReadings = [];
  int _targetHeartRate = 0;
  int _maxHeartRate = 0;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initializeAnimations();
    _setupStreams();
  }

  void _loadUserProfile() async {
    _userProfile = await _profileService.loadProfile();
    if (mounted) {
      setState(() {});
      _initializeService();
    }
  }

  void _initializeService() {
    if (_userProfile == null) {
      // Show error - profile is required for safe VO2 max training
      return;
    }

    _vo2MaxService.initialize(
      userAge: _userProfile!.age,
      restingHeartRate: _userProfile!.restingHeartRate ?? 60,
    );

    // Calculate target heart rates using user's age
    _maxHeartRate = _userProfile!.maxHeartRate;
    _targetHeartRate = _userProfile!.vo2MaxTargetHeartRate;
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupStreams() {
    // Listen to coaching messages
    _coachingSubscription = _vo2MaxService.coachingStream.listen((message) {
      if (mounted) {
        setState(() {
          _currentCoaching = message;
        });
      }
    });

    // Listen to zone status updates
    _zoneSubscription = _vo2MaxService.zoneStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentZoneStatus = status;
        });

        // Animate pulse based on zone
        if (status.isInVO2MaxZone) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      }
    });

    // Listen to real heart rate updates (only real strap data, never simulated)
    _heartRateSubscription =
        _heartRateService.heartRateStream.listen((heartRate) {
      if (mounted && _isTrainingActive) {
        setState(() {
          _currentHeartRate = heartRate;

          // Add to session readings
          _sessionReadings.add(HeartRateReading(
            heartRate: heartRate,
            timestamp: DateTime.now(),
          ));

          // Keep only last 10 minutes of data
          final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
          _sessionReadings
              .removeWhere((reading) => reading.timestamp.isBefore(cutoff));
        });

        // Process heart rate for VO2 max coaching
        _vo2MaxService.processHeartRate(heartRate);
      }
    });

    // Listen to connection status changes
    _connectionSubscription =
        _heartRateService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          if (!isConnected) {
            // Don't keep showing a stale reading/zone once the strap drops.
            _currentHeartRate = 0;
            _currentZoneStatus = null;
            _pulseController.stop();
          }
        });
      }
    });
  }

  void _startTraining() {
    setState(() {
      _isTrainingActive = true;
      _currentInterval = 0;
      _isInInterval = false;
      _remainingTime = _warmUpDuration; // Start with warm-up
      _sessionReadings.clear();
      _currentHeartRate = 0;
      _currentZoneStatus = null;
      _currentCoaching = '';
    });

    _vo2MaxService.startCoaching();
    _startIntervalTimer(_warmUpDuration);

    AppLogger.info('VO2 Max training session started');
  }

  void _stopTraining() {
    _cancelIntervalTimer();
    final wasActive = _isTrainingActive;
    _isTrainingActive = false;
    if (wasActive) _vo2MaxService.stopCoaching();
    if (!mounted) return;

    setState(() {});
    _pulseController.stop();

    AppLogger.info('VO2 Max training session stopped');
  }

  void _cancelIntervalTimer() {
    _intervalTicker?.cancel();
    _intervalTicker = null;
    _phaseEndsAt = null;
  }

  /// Single wall-clock driven ticker. Remaining time is always computed from
  /// [_phaseEndsAt], so it doesn't drift and catches up after the app has
  /// been in the background. Any previous ticker is cancelled first, so a
  /// quick Stop/Start can never run two countdowns at once.
  void _startIntervalTimer(Duration firstPhase) {
    _cancelIntervalTimer();
    _phaseEndsAt = DateTime.now().add(firstPhase);
    _intervalTicker = Timer.periodic(
        const Duration(milliseconds: 250), (_) => _onIntervalTick());
  }

  void _onIntervalTick() {
    final endsAt = _phaseEndsAt;
    if (!mounted || !_isTrainingActive || endsAt == null) {
      _cancelIntervalTimer();
      return;
    }

    final now = DateTime.now();
    var phaseEnd = endsAt;
    var phaseChanged = false;
    // Advance through every phase that has already elapsed (e.g. after the
    // app was backgrounded), chaining from the previous phase's end time.
    while (!now.isBefore(phaseEnd)) {
      final next = _advancePhase();
      if (next == null) {
        // Training complete
        _stopTraining();
        return;
      }
      phaseEnd = phaseEnd.add(next);
      phaseChanged = true;
    }
    _phaseEndsAt = phaseEnd;

    final remainingMs = phaseEnd.difference(now).inMilliseconds;
    final display = Duration(seconds: (remainingMs / 1000).ceil());
    if (phaseChanged || display != _remainingTime) {
      setState(() {
        _remainingTime = display;
      });
    }
  }

  /// Moves to the next phase and returns its duration, or null when the
  /// workout is finished. Caller is responsible for calling setState.
  Duration? _advancePhase() {
    if (_currentInterval == 0 && !_isInInterval) {
      // Warm-up done: start first interval
      _isInInterval = true;
      _currentInterval = 1;
      return _intervalDuration;
    } else if (_isInInterval) {
      // End interval, start rest
      _isInInterval = false;
      return _restDuration;
    } else if (_currentInterval < _totalIntervals) {
      // End rest, start next interval
      _isInInterval = true;
      _currentInterval++;
      return _intervalDuration;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return OfflineIndicator(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VO2 Max Training'),
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
        body: _userProfile == null
            ? _buildProfileRequiredView()
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTrainingStatus(),
                    const SizedBox(height: 24),
                    if (_isTrainingActive) _buildIntervalStatus(),
                    if (_isTrainingActive) const SizedBox(height: 24),
                    if (_isTrainingActive) _buildHeartRateDisplay(),
                    if (_isTrainingActive) const SizedBox(height: 24),
                    if (_isTrainingActive) _buildRealTimeChart(),
                    if (_isTrainingActive) const SizedBox(height: 24),
                    if (_isTrainingActive) _buildZoneIndicator(),
                    if (_isTrainingActive) const SizedBox(height: 24),
                    if (_isTrainingActive) _buildCoachingSection(),
                    if (!_isTrainingActive) _buildInstructions(),
                    const Spacer(),
                    _buildActionButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileRequiredView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 80,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          Text(
            'Profile Required',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'VO2 Max training requires your age for safe heart rate calculations.\n\n'
            'Without your age, we cannot determine safe target heart rates, which could be dangerous.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.health_and_safety, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Safety First',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age-based heart rate limits prevent dangerous overexertion',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/profile');
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Create Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26A69A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingStatus() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF26A69A), // Consistent teal color
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0), // Reduced padding
          child: Column(
            children: [
              Icon(
                _isTrainingActive ? Icons.favorite : Icons.favorite_border,
                size: 40, // Reduced icon size
                color: Colors.white,
              ),
              const SizedBox(height: 12), // Reduced spacing
              Text(
                _isTrainingActive
                    ? 'VO2 Max Training Active'
                    : 'VO2 Max Training',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6), // Reduced spacing
              Text(
                _userProfile != null
                    ? 'Age: ${_userProfile!.age} • Target: $_targetHeartRate BPM'
                    : 'Profile required for safe training',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalStatus() {
    String phaseText;
    Color phaseColor;

    if (_currentInterval == 0) {
      phaseText = 'WARM-UP';
      phaseColor = Colors.blue;
    } else if (_isInInterval) {
      phaseText = 'INTERVAL $_currentInterval/$_totalIntervals';
      phaseColor = Colors.red;
    } else {
      phaseText = 'REST';
      phaseColor = Colors.green;
    }

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: phaseColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                phaseText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_isInInterval)
                const Text(
                  'Push to 95% max heart rate!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                )
              else if (_currentInterval > 0)
                const Text(
                  'Active recovery - keep moving',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                )
              else
                const Text(
                  'Prepare for high intensity',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeartRateDisplay() {
    // Without a strap we show no heart-rate numbers at all rather than
    // made-up ones: VO2 max coaching depends on accurate HR.
    if (!_heartRateService.isConnected) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No heart-rate strap connected. Heart rate and zone '
                  'coaching are unavailable; the interval timer still works.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Heart Rate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  'Target: $_targetHeartRate BPM',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getHeartRateColor().withValues(alpha: 0.1),
                      border: Border.all(
                        color: _getHeartRateColor(),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_currentHeartRate',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getHeartRateColor(),
                                fontSize: 36,
                              ),
                        ),
                        Text(
                          'BPM',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: _getHeartRateColor(),
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeChart() {
    if (!_heartRateService.isConnected || _sessionReadings.isEmpty) {
      return const SizedBox.shrink();
    }
    return HeartRateCharts.buildRealTimeChart(
      _sessionReadings,
      context,
      targetHeartRate: _targetHeartRate,
      maxHeartRate: _maxHeartRate,
      timeWindow: const Duration(minutes: 5),
    );
  }

  Widget _buildZoneIndicator() {
    if (_currentZoneStatus == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Heart Rate Zone',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getZoneColor(_currentZoneStatus!.currentZone.color)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getZoneColor(_currentZoneStatus!.currentZone.color),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _currentZoneStatus!.currentZone.name,
                    style: TextStyle(
                      color:
                          _getZoneColor(_currentZoneStatus!.currentZone.color),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentZoneStatus!.currentZone.description,
                    style: TextStyle(
                      color:
                          _getZoneColor(_currentZoneStatus!.currentZone.color),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (_currentZoneStatus!.isInVO2MaxZone) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'OPTIMAL VO2 MAX ZONE!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoachingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'VO2 Max Coach',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              !_heartRateService.isConnected
                  ? _effortCueWithoutStrap()
                  : _currentCoaching.isNotEmpty
                      ? _currentCoaching
                      : 'Start your training to receive real-time coaching!',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Effort guidance by perceived exertion when no HR data is available.
  String _effortCueWithoutStrap() {
    if (_currentInterval == 0) {
      return 'Warm up at an easy, conversational pace. '
          '(No strap connected: coaching is by feel, not heart rate.)';
    }
    if (_isInInterval) {
      return 'Hard effort: about 9/10 - you can only say a word or two. '
          '(No strap connected: coaching is by feel, not heart rate.)';
    }
    return 'Recover: keep moving easily and let your breathing settle. '
        '(No strap connected: coaching is by feel, not heart rate.)';
  }

  Widget _buildInstructions() {
    final recommendations = _vo2MaxService.getTrainingRecommendations();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VO2 Max Training Guide',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Target Heart Rate', '${recommendations.targetHeartRate} BPM'),
            _buildInfoRow('Workout Duration', recommendations.workoutDuration),
            _buildInfoRow('Rest Between Sets', recommendations.restPeriods),
            _buildInfoRow('Training Frequency', recommendations.frequency),
            const SizedBox(height: 16),
            Text(
              'Training Tips',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...recommendations.tips.map((tip) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                          child:
                              Text(tip, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isTrainingActive ? _stopTraining : _startTraining,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTrainingActive
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isTrainingActive ? 'STOP TRAINING' : 'START VO2 MAX TRAINING',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!_heartRateService.isConnected) ...[
          Text(
            'Connect a heart rate monitor for real-time data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, '/heart-rate-monitor');
              if (mounted) setState(() {}); // Refresh UI after returning
            },
            icon: const Icon(Icons.bluetooth),
            label: const Text('Connect Heart Rate Monitor'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bluetooth_connected,
                  color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Heart rate monitor connected',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getHeartRateColor() {
    if (_currentZoneStatus == null) return Colors.blue;

    if (_currentZoneStatus!.isInVO2MaxZone) return Colors.red;
    return _getZoneColor(_currentZoneStatus!.currentZone.color);
  }

  Color _getZoneColor(String colorName) {
    switch (colorName) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _cancelIntervalTimer();
    _coachingSubscription?.cancel();
    _zoneSubscription?.cancel();
    _heartRateSubscription?.cancel();
    _connectionSubscription?.cancel();
    if (_isTrainingActive) {
      _isTrainingActive = false;
      _vo2MaxService.stopCoaching();
    }
    _pulseController.dispose();
    super.dispose();
  }
}
