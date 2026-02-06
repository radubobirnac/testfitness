import 'package:testfitness/models/exercise.dart';

class ExerciseMetadata {
  static String resolveCategory(Exercise exercise) {
    final category = exercise.category?.trim() ?? '';
    if (category.isNotEmpty && !_isImportedLabel(category)) {
      return category;
    }

    final inferred = _inferCategoryFromName(exercise.name);
    if (inferred != null && inferred.isNotEmpty) {
      return inferred;
    }

    if (category.isNotEmpty) {
      return category;
    }

    return 'Imported';
  }

  static List<String> resolveBodyParts(Exercise exercise) {
    final parts = <String>{};
    final raw = exercise.muscleGroup?.trim() ?? '';
    if (raw.isNotEmpty) {
      for (final part in raw.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final lower = trimmed.toLowerCase();
        if (lower == 'general' || lower == 'multiple') continue;
        parts.add(_normalizeBodyPartLabel(trimmed));
      }
    }

    if (parts.isEmpty) {
      parts.addAll(_inferBodyPartsFromName(exercise.name));
    }

    return parts.toList();
  }

  static bool matchesBodyPart(Exercise exercise, String selected) {
    final selectedLower = selected.toLowerCase().trim();
    if (selectedLower.isEmpty) return false;
    final parts = resolveBodyParts(exercise)
        .map((part) => part.toLowerCase().trim())
        .toSet();
    return parts.contains(selectedLower);
  }

  static bool matchesCategory(Exercise exercise, String selected) {
    final selectedLower = selected.toLowerCase().trim();
    if (selectedLower.isEmpty) return false;
    final resolved = resolveCategory(exercise).toLowerCase().trim();
    return resolved == selectedLower;
  }

  static bool _isImportedLabel(String value) {
    return value.toLowerCase().trim() == 'imported';
  }

  static String? _inferCategoryFromName(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('dumbbell') || lower.contains('db ')) {
      return 'Dumbbell';
    }
    if (lower.contains('barbell') || lower.contains('bb ')) {
      return 'Barbell';
    }
    if (lower.contains('kettlebell') || lower.contains('kb ')) {
      return 'Kettlebell';
    }
    if (lower.contains('cable') ||
        lower.contains('pulldown') ||
        lower.contains('pushdown') ||
        lower.contains('crossover') ||
        lower.contains('face pull')) {
      return 'Cable';
    }
    if (lower.contains('assisted')) {
      return 'Assisted bodyweight';
    }
    if (lower.contains('bodyweight') ||
        lower.contains('pull-up') ||
        lower.contains('pull up') ||
        lower.contains('chin-up') ||
        lower.contains('chin up') ||
        lower.contains('push-up') ||
        lower.contains('push up') ||
        lower.contains('dip') ||
        lower.contains('plank')) {
      return 'Bodyweight';
    }
    if (lower.contains('machine') ||
        lower.contains('smith') ||
        lower.contains('hammer strength')) {
      return 'Machine';
    }
    if (lower.contains('treadmill') ||
        lower.contains('bike') ||
        lower.contains('rower') ||
        lower.contains('elliptical') ||
        lower.contains('stair') ||
        lower.contains('cardio')) {
      return 'Cardio';
    }

    return null;
  }

  static Set<String> _inferBodyPartsFromName(String name) {
    final parts = <String>{};
    final lower = name.toLowerCase();

    if (lower.contains('cardio') ||
        lower.contains('treadmill') ||
        lower.contains('bike') ||
        lower.contains('rower') ||
        lower.contains('elliptical') ||
        lower.contains('stair')) {
      parts.add('Cardio');
    }

    if (lower.contains('squat') ||
        lower.contains('lunge') ||
        lower.contains('leg') ||
        lower.contains('calf') ||
        lower.contains('hamstring') ||
        lower.contains('quad') ||
        lower.contains('glute') ||
        lower.contains('deadlift') ||
        lower.contains('hip thrust') ||
        lower.contains('leg press')) {
      parts.add('Legs');
    }

    if (lower.contains('bench') ||
        lower.contains('chest') ||
        lower.contains('pec') ||
        lower.contains('fly')) {
      parts.add('Chest');
    }

    if (lower.contains('back') ||
        lower.contains('row') ||
        lower.contains('pull') ||
        lower.contains('lat')) {
      parts.add('Back');
    }

    if (lower.contains('shoulder') ||
        lower.contains('deltoid') ||
        lower.contains('overhead') ||
        lower.contains('lateral raise') ||
        lower.contains('rear delt') ||
        lower.contains('upright row')) {
      parts.add('Shoulders');
    }

    if (lower.contains('bicep') ||
        lower.contains('tricep') ||
        lower.contains('curl') ||
        lower.contains('extension') ||
        lower.contains('skull') ||
        lower.contains('pushdown')) {
      parts.add('Arms');
    }

    if (lower.contains('core') ||
        lower.contains('abs') ||
        lower.contains('abdominal') ||
        lower.contains('plank') ||
        lower.contains('crunch')) {
      parts.add('Core');
    }

    return parts;
  }

  static String _normalizeBodyPartLabel(String label) {
    final lower = label.toLowerCase();
    if (lower == 'arms') return 'Arms';
    if (lower == 'back') return 'Back';
    if (lower == 'chest') return 'Chest';
    if (lower == 'core') return 'Core';
    if (lower == 'legs') return 'Legs';
    if (lower == 'shoulders' || lower == 'shoulder') return 'Shoulders';
    if (lower == 'cardio') return 'Cardio';
    if (lower == 'multiple') return 'Multiple';
    if (lower == 'general') return 'General';
    if (label.isEmpty) return label;
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}
