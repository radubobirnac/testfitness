import 'package:equatable/equatable.dart';

/// User profile model for storing personal information and fitness data
class UserProfile extends Equatable {
  final String id;
  final String name;
  final int age;
  final String gender; // 'male', 'female', 'other'
  final double? height; // in cm
  final double? weight; // in kg
  final int? restingHeartRate; // BPM
  final String fitnessLevel; // 'beginner', 'intermediate', 'advanced'
  final DateTime createdDate;
  final DateTime lastUpdated;
  final Map<String, dynamic> preferences;

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.height,
    this.weight,
    this.restingHeartRate,
    this.fitnessLevel = 'beginner',
    required this.createdDate,
    required this.lastUpdated,
    this.preferences = const {},
  });

  /// Calculate maximum heart rate using age-based formula
  int get maxHeartRate => 220 - age;

  /// Calculate target heart rate for VO2 max training (95% of max)
  int get vo2MaxTargetHeartRate => (maxHeartRate * 0.95).round();

  /// Calculate target heart rate for cardio training (70-85% of max)
  int get cardioTargetHeartRateMin => (maxHeartRate * 0.70).round();
  int get cardioTargetHeartRateMax => (maxHeartRate * 0.85).round();

  /// Calculate fat burn target heart rate (60-70% of max)
  int get fatBurnTargetHeartRateMin => (maxHeartRate * 0.60).round();
  int get fatBurnTargetHeartRateMax => (maxHeartRate * 0.70).round();

  /// Get safe heart rate warning threshold (90% of max)
  int get safeHeartRateThreshold => (maxHeartRate * 0.90).round();

  /// Check if a heart rate is safe for this user
  bool isHeartRateSafe(int heartRate) {
    return heartRate <= safeHeartRateThreshold;
  }

  /// Get heart rate safety message
  String getHeartRateSafetyMessage(int heartRate) {
    if (heartRate > maxHeartRate) {
      return 'DANGER: Heart rate exceeds maximum safe level!';
    } else if (heartRate > safeHeartRateThreshold) {
      return 'WARNING: Approaching maximum heart rate - slow down!';
    } else if (heartRate > vo2MaxTargetHeartRate) {
      return 'High intensity - excellent for VO2 max training!';
    } else if (heartRate > cardioTargetHeartRateMax) {
      return 'Great cardio intensity!';
    } else if (heartRate > cardioTargetHeartRateMin) {
      return 'Good cardio zone';
    } else if (heartRate > fatBurnTargetHeartRateMin) {
      return 'Fat burning zone';
    } else {
      return 'Light activity - warm up more for better results';
    }
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? name,
    int? age,
    String? gender,
    double? height,
    double? weight,
    int? restingHeartRate,
    String? fitnessLevel,
    DateTime? createdDate,
    DateTime? lastUpdated,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      createdDate: createdDate ?? this.createdDate,
      lastUpdated: lastUpdated ?? DateTime.now(),
      preferences: preferences ?? this.preferences,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'restingHeartRate': restingHeartRate,
      'fitnessLevel': fitnessLevel,
      'createdDate': createdDate.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'preferences': preferences,
    };
  }

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      gender: json['gender'] as String,
      height: json['height'] as double?,
      weight: json['weight'] as double?,
      restingHeartRate: json['restingHeartRate'] as int?,
      fitnessLevel: json['fitnessLevel'] as String? ?? 'beginner',
      createdDate: DateTime.parse(json['createdDate'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Create default profile for new users
  factory UserProfile.createDefault({
    required String id,
    required String name,
    required int age,
    required String gender,
  }) {
    final now = DateTime.now();
    return UserProfile(
      id: id,
      name: name,
      age: age,
      gender: gender,
      createdDate: now,
      lastUpdated: now,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        age,
        gender,
        height,
        weight,
        restingHeartRate,
        fitnessLevel,
        createdDate,
        lastUpdated,
        preferences,
      ];

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, age: $age, gender: $gender, '
        'maxHR: $maxHeartRate, vo2MaxTarget: $vo2MaxTargetHeartRate)';
  }
}

/// Gender options for user profile
class Gender {
  static const String male = 'male';
  static const String female = 'female';
  static const String other = 'other';

  static const List<String> all = [male, female, other];
  
  static String getDisplayName(String gender) {
    switch (gender) {
      case male:
        return 'Male';
      case female:
        return 'Female';
      case other:
        return 'Other';
      default:
        return 'Unknown';
    }
  }
}

/// Fitness level options
class FitnessLevel {
  static const String beginner = 'beginner';
  static const String intermediate = 'intermediate';
  static const String advanced = 'advanced';

  static const List<String> all = [beginner, intermediate, advanced];
  
  static String getDisplayName(String level) {
    switch (level) {
      case beginner:
        return 'Beginner';
      case intermediate:
        return 'Intermediate';
      case advanced:
        return 'Advanced';
      default:
        return 'Unknown';
    }
  }
  
  static String getDescription(String level) {
    switch (level) {
      case beginner:
        return 'New to fitness or returning after a break';
      case intermediate:
        return 'Regular exercise routine, some experience';
      case advanced:
        return 'Experienced athlete or fitness enthusiast';
      default:
        return '';
    }
  }
}
