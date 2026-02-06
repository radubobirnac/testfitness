import 'package:testfitness/data/default_exercises.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/utils/app_logger.dart';

class ExerciseSeedService {
  static Future<int> ensureDefaultExercises(DatabaseInterface db) async {
    final existing = await db.getExercises();
    final existingKeys = <String>{};
    for (final exercise in existing) {
      existingKeys.add(_keyFor(exercise.name));
    }

    final defaults = buildDefaultExercises();
    var added = 0;
    for (final exercise in defaults) {
      final key = _keyFor(exercise.name);
      if (existingKeys.contains(key)) {
        continue;
      }
      await db.insertExercise(exercise);
      existingKeys.add(key);
      added++;
    }

    if (added > 0) {
      AppLogger.database('Seeded default exercises', 'Added $added');
    }

    return added;
  }

  static String _keyFor(String name) {
    return name.trim().toLowerCase();
  }
}
