import 'package:equatable/equatable.dart';
import 'package:testfitness/utils/error_handler.dart';
import 'package:uuid/uuid.dart';

/// Represents types of fitness metrics that can be tracked
enum MetricType {
  weight, // Body weight
  bodyFat, // Body fat percentage
  muscle, // Muscle mass
  waist, // Waist circumference
  chest, // Chest circumference
  arms, // Arm circumference
  thighs, // Thigh circumference
  custom, // Custom metric defined by user
}

/// Extension to provide string representations and units for metric types
extension MetricTypeExtension on MetricType {
  String get displayName {
    switch (this) {
      case MetricType.weight:
        return 'Weight';
      case MetricType.bodyFat:
        return 'Body Fat';
      case MetricType.muscle:
        return 'Muscle Mass';
      case MetricType.waist:
        return 'Waist';
      case MetricType.chest:
        return 'Chest';
      case MetricType.arms:
        return 'Arms';
      case MetricType.thighs:
        return 'Thighs';
      case MetricType.custom:
        return 'Custom';
    }
  }

  String defaultUnit(bool useMetric) {
    switch (this) {
      case MetricType.weight:
        return useMetric ? 'kg' : 'lbs';
      case MetricType.bodyFat:
      case MetricType.muscle:
        return '%';
      case MetricType.waist:
      case MetricType.chest:
      case MetricType.arms:
      case MetricType.thighs:
        return useMetric ? 'cm' : 'in';
      case MetricType.custom:
        return '';
    }
  }
}

/// Represents a single fitness metric measurement
class FitnessMetric extends Equatable {
  final String id;
  final MetricType type;
  final String? customName; // Only used when type is MetricType.custom
  final double value;
  final DateTime date;
  final String? unit;
  final String? notes;

  const FitnessMetric({
    required this.id,
    required this.type,
    required this.value,
    required this.date,
    this.customName,
    this.unit,
    this.notes,
  });

  /// Create a new fitness metric with a generated ID
  factory FitnessMetric.create({
    required MetricType type,
    required double value,
    required DateTime date,
    String? customName,
    String? unit,
    String? notes,
  }) {
    return FitnessMetric(
      id: const Uuid().v4(),
      type: type,
      value: value,
      date: date,
      customName:
          type == MetricType.custom ? (customName ?? 'Custom Metric') : null,
      unit: unit,
      notes: notes,
    );
  }

  /// Create a copy of this metric with modified properties
  FitnessMetric copyWith({
    MetricType? type,
    double? value,
    DateTime? date,
    String? customName,
    String? unit,
    String? notes,
  }) {
    return FitnessMetric(
      id: id,
      type: type ?? this.type,
      value: value ?? this.value,
      date: date ?? this.date,
      customName: customName ?? this.customName,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
    );
  }

  /// Convert metric to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'customName': customName,
      'value': value,
      'date': date.millisecondsSinceEpoch,
      'unit': unit,
      'notes': notes,
    };
  }

  /// Create a metric from a database map
  factory FitnessMetric.fromMap(Map<String, dynamic> map) {
    try {
      final metricTypeIndex = map['type'] as int;
      final metricType = MetricType.values[metricTypeIndex];

      return FitnessMetric(
        id: map['id'],
        type: metricType,
        customName: map['customName'],
        value: map['value'] is int
            ? (map['value'] as int).toDouble()
            : map['value'],
        date: DateTime.fromMillisecondsSinceEpoch(map['date']),
        unit: map['unit'],
        notes: map['notes'],
      );
    } catch (e) {
      ErrorHandler.handleParsingError(e, null, 'FitnessMetric.fromMap');
      rethrow;
    }
  }

  /// Like [FitnessMetric.fromMap] but returns null for a damaged record, so
  /// callers can skip it instead of showing an invented "0, today" value.
  static FitnessMetric? tryFromMap(Map<String, dynamic> map) {
    try {
      return FitnessMetric.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Get the display name for this metric
  String get displayName {
    return type == MetricType.custom && customName != null
        ? customName!
        : type.displayName;
  }

  @override
  List<Object?> get props => [
        id,
        type,
        customName,
        value,
        date,
        unit,
        notes,
      ];
}
