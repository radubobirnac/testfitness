import 'dart:async';
import 'package:testfitness/utils/app_logger.dart';

/// Service for VO2 max training and heart rate zone coaching
class VO2MaxService {
  static final VO2MaxService _instance = VO2MaxService._internal();
  factory VO2MaxService() => _instance;
  VO2MaxService._internal();

  // Coaching state
  final StreamController<String> _coachingController =
      StreamController<String>.broadcast();
  final StreamController<HeartRateZoneStatus> _zoneController =
      StreamController<HeartRateZoneStatus>.broadcast();

  // User profile
  int _userAge = 30; // Default age
  int _restingHeartRate = 60; // Default RHR

  // Coaching settings
  bool _isCoachingActive = false;
  DateTime? _lastCoachingMessage;

  /// Whether a coaching session is in progress.
  bool get isCoachingActive => _isCoachingActive;

  // Streams
  Stream<String> get coachingStream => _coachingController.stream;
  Stream<HeartRateZoneStatus> get zoneStream => _zoneController.stream;

  /// Initialize the VO2 max service
  void initialize({int? userAge, int? restingHeartRate}) {
    _userAge = userAge ?? 30;
    _restingHeartRate = restingHeartRate ?? 60;
    AppLogger.info(
        'VO2MaxService initialized for age $_userAge, RHR $_restingHeartRate');
  }

  /// Start VO2 max coaching session
  void startCoaching() {
    _isCoachingActive = true;
    _lastCoachingMessage = null;
    _coachingController.add(
        'VO2 Max training started! Target your 95% max heart rate zone for optimal results.');
    AppLogger.info('VO2 Max coaching session started');
  }

  /// Stop VO2 max coaching session
  void stopCoaching() {
    if (!_isCoachingActive) return;
    _isCoachingActive = false;
    _lastCoachingMessage = null;
    _coachingController.add('VO2 Max training session complete. Great work!');
    AppLogger.info('VO2 Max coaching session stopped');
  }

  /// Process heart rate reading and provide coaching
  void processHeartRate(int heartRate) {
    if (!_isCoachingActive) return;

    final zones = calculateHeartRateZones(_userAge, _restingHeartRate);
    final currentZone = getCurrentZone(heartRate, zones);
    final zoneStatus = HeartRateZoneStatus(
      currentHeartRate: heartRate,
      currentZone: currentZone,
      zones: zones,
      isInVO2MaxZone: _isInVO2MaxZone(heartRate, zones),
    );

    _zoneController.add(zoneStatus);

    // Provide coaching based on current zone
    _provideZoneCoaching(zoneStatus);
  }

  /// Calculate heart rate zones using Karvonen method (more accurate)
  HeartRateZones calculateHeartRateZones(int age, int restingHeartRate) {
    final maxHeartRate = 220 - age;
    final heartRateReserve = maxHeartRate - restingHeartRate;

    // Using Karvonen formula: Target HR = ((Max HR - Resting HR) × %Intensity) + Resting HR
    return HeartRateZones(
      restingZone: HeartRateZone(
        name: 'Resting',
        minBpm: restingHeartRate,
        maxBpm: restingHeartRate + (heartRateReserve * 0.5).round(),
        color: 'blue',
        description: 'Recovery and rest',
        intensityPercent: 0.5,
      ),
      fatBurnZone: HeartRateZone(
        name: 'Fat Burn',
        minBpm: restingHeartRate + (heartRateReserve * 0.5).round(),
        maxBpm: restingHeartRate + (heartRateReserve * 0.6).round(),
        color: 'green',
        description: 'Light activity, fat burning',
        intensityPercent: 0.6,
      ),
      aerobicZone: HeartRateZone(
        name: 'Aerobic',
        minBpm: restingHeartRate + (heartRateReserve * 0.6).round(),
        maxBpm: restingHeartRate + (heartRateReserve * 0.7).round(),
        color: 'yellow',
        description: 'Moderate cardio, base building',
        intensityPercent: 0.7,
      ),
      anaerobicZone: HeartRateZone(
        name: 'Anaerobic',
        minBpm: restingHeartRate + (heartRateReserve * 0.7).round(),
        maxBpm: restingHeartRate + (heartRateReserve * 0.85).round(),
        color: 'orange',
        description: 'High intensity, lactate threshold',
        intensityPercent: 0.85,
      ),
      vo2MaxZone: HeartRateZone(
        name: 'VO2 Max',
        minBpm: restingHeartRate + (heartRateReserve * 0.85).round(),
        maxBpm: maxHeartRate,
        color: 'red',
        description: 'Maximum effort, VO2 max improvement',
        intensityPercent: 1.0,
      ),
    );
  }

  /// Get current heart rate zone
  HeartRateZone getCurrentZone(int heartRate, HeartRateZones zones) {
    if (heartRate <= zones.restingZone.maxBpm) return zones.restingZone;
    if (heartRate <= zones.fatBurnZone.maxBpm) return zones.fatBurnZone;
    if (heartRate <= zones.aerobicZone.maxBpm) return zones.aerobicZone;
    if (heartRate <= zones.anaerobicZone.maxBpm) return zones.anaerobicZone;
    return zones.vo2MaxZone;
  }

  /// Check if heart rate is in VO2 max zone (95%+ of max)
  bool _isInVO2MaxZone(int heartRate, HeartRateZones zones) {
    final maxHeartRate = 220 - _userAge;
    final vo2MaxThreshold = (maxHeartRate * 0.95).round();
    return heartRate >= vo2MaxThreshold;
  }

  /// Provide zone-specific coaching
  void _provideZoneCoaching(HeartRateZoneStatus status) {
    final now = DateTime.now();

    // Limit coaching messages to every 15 seconds
    if (_lastCoachingMessage != null &&
        now.difference(_lastCoachingMessage!).inSeconds < 15) {
      return;
    }

    String message = '';

    if (status.isInVO2MaxZone) {
      message =
          '🔥 Perfect! You\'re in the VO2 Max zone! This is where the magic happens for cardiovascular improvement!';
    } else {
      switch (status.currentZone.name) {
        case 'Resting':
          message =
              '💙 You\'re in the resting zone. Time to push harder to reach your VO2 Max zone!';
          break;
        case 'Fat Burn':
          message =
              '💚 Fat burn zone - good start! Push harder to reach the VO2 Max zone for maximum benefit.';
          break;
        case 'Aerobic':
          message =
              '💛 Aerobic zone - you\'re building your base! Push harder to hit that VO2 Max zone.';
          break;
        case 'Anaerobic':
          message =
              '🧡 Anaerobic zone - you\'re getting close! Just a bit more to reach the VO2 Max zone!';
          break;
        case 'VO2 Max':
          if (!status.isInVO2MaxZone) {
            message =
                '❤️ VO2 Max zone! Push to 95%+ of your max heart rate for optimal training!';
          }
          break;
      }
    }

    if (message.isNotEmpty) {
      _coachingController.add(message);
      _lastCoachingMessage = now;
      AppLogger.info('VO2 Max coaching: $message');
    }
  }

  /// Get VO2 max training recommendations
  VO2MaxRecommendations getTrainingRecommendations() {
    final zones = calculateHeartRateZones(_userAge, _restingHeartRate);
    final vo2MaxTarget = (zones.vo2MaxZone.minBpm +
            (zones.vo2MaxZone.maxBpm - zones.vo2MaxZone.minBpm) * 0.95)
        .round();

    return VO2MaxRecommendations(
      targetHeartRate: vo2MaxTarget,
      workoutDuration: '4-6 minutes',
      restPeriods: '2-3 minutes between intervals',
      frequency: '2-3 times per week',
      tips: [
        'Warm up for 10-15 minutes before VO2 Max intervals',
        'Maintain 95%+ max heart rate for 4-6 minutes',
        'Allow full recovery between intervals',
        'Focus on breathing and form even at high intensity',
        'Track improvements in time to reach target zone',
      ],
    );
  }

  /// Estimate VO2 max based on heart rate data
  double estimateVO2Max({
    required int maxHeartRate,
    required int restingHeartRate,
    required int age,
    required double fitnessLevel, // 1.0 = average, 1.5 = good, 2.0 = excellent
  }) {
    // Simplified VO2 max estimation formula
    // More accurate methods would require actual testing
    final baseVO2Max = 15.3 * (maxHeartRate / restingHeartRate);
    final adjustedVO2Max = baseVO2Max * fitnessLevel;

    return adjustedVO2Max.clamp(20.0, 80.0); // Reasonable range
  }

  /// Dispose of resources
  void dispose() {
    _coachingController.close();
    _zoneController.close();
  }
}

/// Heart rate zone definition with intensity percentage
class HeartRateZone {
  final String name;
  final int minBpm;
  final int maxBpm;
  final String color;
  final String description;
  final double intensityPercent;

  HeartRateZone({
    required this.name,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
    required this.description,
    required this.intensityPercent,
  });
}

/// Complete heart rate zones
class HeartRateZones {
  final HeartRateZone restingZone;
  final HeartRateZone fatBurnZone;
  final HeartRateZone aerobicZone;
  final HeartRateZone anaerobicZone;
  final HeartRateZone vo2MaxZone;

  HeartRateZones({
    required this.restingZone,
    required this.fatBurnZone,
    required this.aerobicZone,
    required this.anaerobicZone,
    required this.vo2MaxZone,
  });
}

/// Current heart rate zone status
class HeartRateZoneStatus {
  final int currentHeartRate;
  final HeartRateZone currentZone;
  final HeartRateZones zones;
  final bool isInVO2MaxZone;

  HeartRateZoneStatus({
    required this.currentHeartRate,
    required this.currentZone,
    required this.zones,
    required this.isInVO2MaxZone,
  });
}

/// VO2 max training recommendations
class VO2MaxRecommendations {
  final int targetHeartRate;
  final String workoutDuration;
  final String restPeriods;
  final String frequency;
  final List<String> tips;

  VO2MaxRecommendations({
    required this.targetHeartRate,
    required this.workoutDuration,
    required this.restPeriods,
    required this.frequency,
    required this.tips,
  });
}
