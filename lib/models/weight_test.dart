import 'package:uuid/uuid.dart';

/// Weight test model for tracking strength testing sessions
class WeightTest {
  final String id;
  final String userId;
  final String exerciseId;
  final String exerciseName;
  final DateTime testDate;
  final WeightTestType testType;
  final int targetReps;
  final List<WeightTestSet> testSets;
  final double? recommendedWeight;
  final double? confidenceScore;
  final String? notes;
  final DateTime createdAt;
  final bool isCompleted;

  WeightTest({
    String? id,
    required this.userId,
    required this.exerciseId,
    required this.exerciseName,
    required this.testDate,
    required this.testType,
    required this.targetReps,
    required this.testSets,
    this.recommendedWeight,
    this.confidenceScore,
    this.notes,
    DateTime? createdAt,
    this.isCompleted = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Create a copy with updated values
  WeightTest copyWith({
    String? id,
    String? userId,
    String? exerciseId,
    String? exerciseName,
    DateTime? testDate,
    WeightTestType? testType,
    int? targetReps,
    List<WeightTestSet>? testSets,
    double? recommendedWeight,
    double? confidenceScore,
    String? notes,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return WeightTest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      testDate: testDate ?? this.testDate,
      testType: testType ?? this.testType,
      targetReps: targetReps ?? this.targetReps,
      testSets: testSets ?? this.testSets,
      recommendedWeight: recommendedWeight ?? this.recommendedWeight,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'testDate': testDate.toIso8601String(),
      'testType': testType.name,
      'targetReps': targetReps,
      'testSets': testSets.map((set) => set.toMap()).toList(),
      'recommendedWeight': recommendedWeight,
      'confidenceScore': confidenceScore,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  /// Create from map (database)
  factory WeightTest.fromMap(Map<String, dynamic> map) {
    return WeightTest(
      id: map['id'],
      userId: map['userId'],
      exerciseId: map['exerciseId'],
      exerciseName: map['exerciseName'],
      testDate: DateTime.parse(map['testDate']),
      testType: WeightTestType.values.firstWhere(
        (type) => type.name == map['testType'],
        orElse: () => WeightTestType.progressiveLoading,
      ),
      targetReps: map['targetReps'],
      testSets: (map['testSets'] as List<dynamic>)
          .map((setMap) => WeightTestSet.fromMap(setMap))
          .toList(),
      recommendedWeight: map['recommendedWeight']?.toDouble(),
      confidenceScore: map['confidenceScore']?.toDouble(),
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  /// Calculate 1RM using Brzycki formula
  double? calculateOneRepMax() {
    if (testSets.isEmpty) return null;
    
    // Find the heaviest successful set
    WeightTestSet? heaviestSet;
    for (var set in testSets) {
      if (set.reps > 0 && !set.formBreakdown) {
        if (heaviestSet == null || set.weight > heaviestSet.weight) {
          heaviestSet = set;
        }
      }
    }
    
    if (heaviestSet == null) return null;
    
    // Brzycki formula: 1RM = weight / (1.0278 - (0.0278 × reps))
    return heaviestSet.weight / (1.0278 - (0.0278 * heaviestSet.reps));
  }

  /// Get recommended working weight based on percentage of 1RM
  double? getWorkingWeight({double percentage = 0.8}) {
    final oneRepMax = calculateOneRepMax();
    if (oneRepMax == null) return null;
    
    return oneRepMax * percentage;
  }
}

/// Individual set within a weight test
class WeightTestSet {
  final int setNumber;
  final double weight;
  final int reps;
  final int? rpe; // Rate of Perceived Exertion (1-10)
  final bool formBreakdown;
  final String? notes;
  final DateTime timestamp;

  WeightTestSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.rpe,
    this.formBreakdown = false,
    this.notes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
      'rpe': rpe,
      'formBreakdown': formBreakdown,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from map (database)
  factory WeightTestSet.fromMap(Map<String, dynamic> map) {
    return WeightTestSet(
      setNumber: map['setNumber'],
      weight: map['weight'].toDouble(),
      reps: map['reps'],
      rpe: map['rpe'],
      formBreakdown: map['formBreakdown'] ?? false,
      notes: map['notes'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  /// Create a copy with updated values
  WeightTestSet copyWith({
    int? setNumber,
    double? weight,
    int? reps,
    int? rpe,
    bool? formBreakdown,
    String? notes,
    DateTime? timestamp,
  }) {
    return WeightTestSet(
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      rpe: rpe ?? this.rpe,
      formBreakdown: formBreakdown ?? this.formBreakdown,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Types of weight tests available
enum WeightTestType {
  progressiveLoading('Progressive Loading'),
  reversePyramid('Reverse Pyramid'),
  rpeAssessment('RPE Assessment'),
  oneRepMax('One Rep Max');

  const WeightTestType(this.displayName);
  final String displayName;
}

/// Weight recommendation result
class WeightRecommendation {
  final double recommendedWeight;
  final double confidenceScore;
  final String reasoning;
  final Map<String, double> percentageWeights; // 65%, 75%, 85%, etc.
  final String progressionPlan;

  WeightRecommendation({
    required this.recommendedWeight,
    required this.confidenceScore,
    required this.reasoning,
    required this.percentageWeights,
    required this.progressionPlan,
  });
}

/// Progression plan for future workouts
class ProgressionPlan {
  final String strategy;
  final double weeklyIncrease;
  final int reassessmentWeeks;
  final List<String> tips;

  ProgressionPlan({
    required this.strategy,
    required this.weeklyIncrease,
    required this.reassessmentWeeks,
    required this.tips,
  });
}
