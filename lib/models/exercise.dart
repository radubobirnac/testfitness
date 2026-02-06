import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Represents a single exercise in the fitness app
class Exercise extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? muscleGroup;
  final String? category; // Equipment category (e.g., Barbell, Dumbbell)
  final String? imageUrl;
  final bool isCustom;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    this.muscleGroup,
    this.category,
    this.imageUrl,
    this.isCustom = false,
  });

  /// Create a new exercise with a generated ID
  factory Exercise.create({
    required String name,
    String? description,
    String? muscleGroup,
    String? category,
    String? imageUrl,
    bool isCustom = true,
  }) {
    return Exercise(
      id: const Uuid().v4(),
      name: name,
      description: description,
      muscleGroup: muscleGroup,
      category: category,
      imageUrl: imageUrl,
      isCustom: isCustom,
    );
  }

  /// Create a copy of this exercise with modified properties
  Exercise copyWith({
    String? name,
    String? description,
    String? muscleGroup,
    String? category,
    String? imageUrl,
    bool? isCustom,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  /// Convert exercise to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'muscleGroup': muscleGroup,
      'category': category,
      'imageUrl': imageUrl,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  /// Create an exercise from a database map
  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      muscleGroup: map['muscleGroup'],
      category: map['category'],
      imageUrl: map['imageUrl'],
      isCustom: map['isCustom'] == 1,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    muscleGroup,
    category,
    imageUrl,
    isCustom,
  ];
}
