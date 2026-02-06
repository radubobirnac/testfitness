import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_goal.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/database_service_factory.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/services/database_interface.dart';
import 'package:testfitness/services/exercise_seed_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

/// Service for exporting and importing workout data
class ExportImportService {
  static const String _appName = 'StrengthWave';
  static const String _version = '1.0.0';

  /// Export all workout data to JSON
  static Future<String> exportToJson({
    required List<Workout> workouts,
    required List<Exercise> exercises,
    List<FitnessGoal>? goals,
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      final exportData = {
        'metadata': {
          'appName': _appName,
          'version': _version,
          'exportDate': DateTime.now().toIso8601String(),
          'totalWorkouts': workouts.length,
          'totalExercises': exercises.length,
        },
        'workouts': workouts.map(_workoutToExportMap).toList(),
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'goals': goals?.map((g) => g.toMap()).toList() ?? [],
        'userPreferences': userPreferences ?? {},
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      AppLogger.info(
          'Successfully exported ${workouts.length} workouts and ${exercises.length} exercises to JSON');

      return jsonString;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to export data to JSON', error, stackTrace);
      rethrow;
    }
  }

  /// Export workout data to CSV format
  static Future<String> exportToCsv(
    List<Workout> workouts, {
    List<Exercise> exercises = const [],
  }) async {
    try {
      final exerciseById = {
        for (final exercise in exercises) exercise.id: exercise,
      };
      final buffer = StringBuffer();

      // CSV Header
      buffer.writeln(
          'Date,Workout Name,Exercise ID,Exercise Name,Muscle Group,Category,Sets,Reps,Weight,Duration (min),Completed');

      for (final workout in workouts) {
        final dateStr = workout.completedDate != null
            ? DateFormat('yyyy-MM-dd').format(workout.completedDate!)
            : DateFormat('yyyy-MM-dd')
                .format(workout.scheduledDate ?? DateTime.now());

        if (workout.sets.isEmpty) {
          // Workout with no sets
          buffer.writeln(
              '$dateStr,"${_escapeCsv(workout.name)}","","No exercises","","",0,0,0,${workout.durationMinutes ?? 0},${workout.isCompleted}');
        } else {
          for (final set in workout.sets) {
            final exercise = exerciseById[set.exerciseId];
            final exerciseName = exercise?.name ?? set.exerciseId;
            final muscleGroup = exercise?.muscleGroup ?? '';
            final category = exercise?.category ?? '';
            buffer.writeln(
                '$dateStr,"${_escapeCsv(workout.name)}","${_escapeCsv(set.exerciseId)}","${_escapeCsv(exerciseName)}","${_escapeCsv(muscleGroup)}","${_escapeCsv(category)}",1,${set.reps},${set.weight},${workout.durationMinutes ?? 0},${workout.isCompleted}');
          }
        }
      }

      AppLogger.info(
          'Successfully exported ${workouts.length} workouts to CSV');
      return buffer.toString();
    } catch (error, stackTrace) {
      AppLogger.error('Failed to export data to CSV', error, stackTrace);
      rethrow;
    }
  }

  /// Generate progress report
  static Future<String> generateProgressReport(
    List<Workout> workouts,
    List<FitnessGoal>? goals,
  ) async {
    try {
      final completedWorkouts = workouts.where((w) => w.isCompleted).toList();
      final buffer = StringBuffer();

      buffer.writeln('# StrengthWave Progress Report');
      buffer.writeln(
          'Generated on: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}');
      buffer.writeln('');

      // Overall Statistics
      buffer.writeln('## Overall Statistics');
      buffer.writeln('- Total Workouts: ${workouts.length}');
      buffer.writeln('- Completed Workouts: ${completedWorkouts.length}');
      buffer.writeln(
          '- Completion Rate: ${workouts.isNotEmpty ? (completedWorkouts.length / workouts.length * 100).toStringAsFixed(1) : 0}%');

      final totalSets =
          completedWorkouts.fold<int>(0, (sum, w) => sum + w.sets.length);
      buffer.writeln('- Total Sets Completed: $totalSets');

      final uniqueExercises =
          completedWorkouts.expand((w) => w.exerciseIds).toSet().length;
      buffer.writeln('- Unique Exercises Tried: $uniqueExercises');
      buffer.writeln('');

      // Recent Activity
      buffer.writeln('## Recent Activity (Last 30 Days)');
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentWorkouts = completedWorkouts
          .where((w) =>
              w.completedDate != null &&
              w.completedDate!.isAfter(thirtyDaysAgo))
          .toList();

      buffer.writeln('- Workouts Completed: ${recentWorkouts.length}');
      buffer.writeln(
          '- Average per Week: ${(recentWorkouts.length / 4.3).toStringAsFixed(1)}');
      buffer.writeln('');

      // Goals Progress
      if (goals != null && goals.isNotEmpty) {
        buffer.writeln('## Goals Progress');
        for (final goal in goals) {
          final status = goal.isCompleted
              ? '✅ Completed'
              : goal.isOverdue
                  ? '⏰ Overdue'
                  : '🎯 In Progress';
          buffer.writeln(
              '- ${goal.title}: ${goal.progressPercentage.toStringAsFixed(1)}% $status');
        }
        buffer.writeln('');
      }

      // Most Active Days
      buffer.writeln('## Most Active Days');
      final dayStats = <String, int>{};
      for (final workout in completedWorkouts) {
        if (workout.completedDate != null) {
          final dayName = DateFormat('EEEE').format(workout.completedDate!);
          dayStats[dayName] = (dayStats[dayName] ?? 0) + 1;
        }
      }

      final sortedDays = dayStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedDays.take(3)) {
        buffer.writeln('- ${entry.key}: ${entry.value} workouts');
      }

      AppLogger.info('Successfully generated progress report');
      return buffer.toString();
    } catch (error, stackTrace) {
      AppLogger.error('Failed to generate progress report', error, stackTrace);
      rethrow;
    }
  }

  /// Save file to device storage
  static Future<String> saveToFile(String content, String filename) async {
    try {
      if (kIsWeb) {
        // For web, we'll use the share functionality or download
        throw UnsupportedError(
            'File saving not supported on web. Use share functionality instead.');
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content);

      AppLogger.info('Successfully saved file: ${file.path}');
      return file.path;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to save file', error, stackTrace);
      rethrow;
    }
  }

  /// Share content using platform share dialog
  static Future<void> shareContent(
      String content, String filename, String mimeType) async {
    try {
      if (kIsWeb) {
        // For web, copy to clipboard
        await Clipboard.setData(ClipboardData(text: content));
        AppLogger.info('Content copied to clipboard');
      } else {
        // For mobile, save to temp file and share
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(content);

        await Share.share(
          'StrengthWave Data Export',
          subject: filename,
        );

        AppLogger.info('Successfully shared file: $filename');
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to share content', error, stackTrace);
      rethrow;
    }
  }

  /// Save content to a user-selected file when supported
  static Future<String?> saveContentToFile(
      String content, String filename) async {
    try {
      if (kIsWeb) {
        return null;
      }

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $filename',
        fileName: filename,
      );
      if (path == null || path.isEmpty) {
        return null;
      }

      final file = File(path);
      await file.writeAsString(content);
      AppLogger.info('Successfully saved file: $path');
      return path;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to save content to file', error, stackTrace);
      return null;
    }
  }

  /// Import data from JSON string
  static Future<ImportResult> importFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate format
      if (!data.containsKey('metadata') || !data.containsKey('workouts')) {
        throw FormatException('Invalid StrengthWave export format');
      }

      final metadata = data['metadata'] as Map<String, dynamic>;
      if (metadata['appName'] != _appName) {
        throw FormatException('This file was not exported from StrengthWave');
      }

      // Parse workouts
      final workoutsList = data['workouts'] as List<dynamic>;
      final workouts = workoutsList
          .map((w) {
            final workoutMap = w as Map<String, dynamic>;
            final setsList = workoutMap['sets'] as List<dynamic>? ?? [];
            final sets = setsList
                .map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>))
                .toList();
            return Workout.fromMap(workoutMap, sets);
          })
          .toList();

      // Parse exercises
      final exercisesList = data['exercises'] as List<dynamic>? ?? [];
      final exercises = exercisesList
          .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
          .toList();

      // Parse goals
      final goalsList = data['goals'] as List<dynamic>? ?? [];
      final goals = goalsList
          .map((g) => FitnessGoal.fromMap(g as Map<String, dynamic>))
          .toList();

      // Parse preferences
      final preferences =
          data['userPreferences'] as Map<String, dynamic>? ?? {};

      AppLogger.info(
          'Successfully imported ${workouts.length} workouts, ${exercises.length} exercises, and ${goals.length} goals');

      return ImportResult(
        workouts: workouts,
        exercises: exercises,
        goals: goals,
        userPreferences: preferences,
        metadata: metadata,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to import data from JSON', error, stackTrace);
      rethrow;
    }
  }

  /// Import workout data from CSV string
  static Future<ImportResult> importFromCsv(
    String csvString, {
    CsvImportProfile profile = CsvImportProfile.auto,
  }) async {
    try {
      final rows = _parseCsv(csvString);
      if (rows.isEmpty) {
        throw FormatException('CSV is empty');
      }

      final headers = _normalizeHeaders(rows.first, profile);
      final dataRows = rows.skip(1);

      final exercisesByName = <String, Exercise>{};
      final exercisesById = <String, Exercise>{};
      final workoutsByKey = <String, _WorkoutImportBuilder>{};

      for (final row in dataRows) {
        if (row.every((cell) => cell.trim().isEmpty)) {
          continue;
        }

        final values = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          values[headers[i]] = row[i].trim();
        }

        final workoutName =
            values['workoutname'] ?? values['workout'] ?? 'Imported Workout';
        final date = _parseDate(values['date']);
        final completed = _parseBool(values['completed']);
        final durationMinutes = _parseInt(values['durationmin']);

        final exerciseId = values['exerciseid'];
        final exerciseName =
            values['exercisename'] ?? values['exercise'] ?? '';
        final muscleGroup = values['musclegroup'] ?? values['muscle'] ?? '';
        final category = values['category'] ?? 'Imported';

        if (exerciseName.isEmpty && (exerciseId == null || exerciseId.isEmpty)) {
          continue;
        }

        Exercise? exercise;
        if (exerciseId != null && exerciseId.isNotEmpty) {
          exercise = exercisesById[exerciseId];
        }

        exercise ??= exercisesByName[exerciseName.toLowerCase()];

        if (exercise == null && exerciseId != null && exerciseId.isNotEmpty) {
          exercise = Exercise(
            id: exerciseId,
            name: exerciseName.isNotEmpty ? exerciseName : exerciseId,
            description: 'Imported from CSV',
            muscleGroup: muscleGroup.isNotEmpty ? muscleGroup : null,
            category: category.isNotEmpty ? category : 'Imported',
            isCustom: true,
          );
        }

        exercise ??= Exercise.create(
          name: exerciseName.isNotEmpty ? exerciseName : exerciseId!,
          description: 'Imported from CSV',
          muscleGroup: muscleGroup.isNotEmpty ? muscleGroup : null,
          category: category.isNotEmpty ? category : 'Imported',
          isCustom: true,
        );

        exercisesById[exercise.id] = exercise;
        if (exerciseName.isNotEmpty) {
          exercisesByName[exerciseName.toLowerCase()] = exercise;
        }

        final reps = _parseInt(values['reps']) ?? 0;
        final weight = _parseDouble(values['weight']) ?? 0.0;

        final workoutKey =
            '${workoutName.toLowerCase()}|${date?.toIso8601String() ?? 'no-date'}';
        final builder = workoutsByKey.putIfAbsent(
          workoutKey,
          () => _WorkoutImportBuilder(
            name: workoutName,
            scheduledDate: date,
            completedDate: completed ? date : null,
            isCompleted: completed,
            durationMinutes: durationMinutes,
          ),
        );

        final setOrder = _parseInt(values['setorder']);
        builder.addSet(
          WorkoutSet.create(
            exerciseId: exercise.id,
            reps: reps,
            weight: weight,
            isCompleted: completed,
            completedAt: completed ? date : null,
            notes: setOrder != null ? 'set_order:$setOrder' : null,
          ),
        );
      }

      final workouts =
          workoutsByKey.values.map((builder) => builder.build()).toList();
      final exercises = exercisesById.values.toList();

      AppLogger.info(
          'Successfully imported ${workouts.length} workouts and ${exercises.length} exercises from CSV');

      return ImportResult(
        workouts: workouts,
        exercises: exercises,
        goals: const [],
        userPreferences: const {},
        metadata: {
          'appName': _appName,
          'version': _version,
          'format': 'csv',
        },
      );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to import data from CSV', error, stackTrace);
      rethrow;
    }
  }

  static Map<String, dynamic> _workoutToExportMap(Workout workout) {
    final map = workout.toMap();
    map['sets'] = workout.sets.map((set) => set.toMap()).toList();
    return map;
  }

  /// Apply import result to the local database and preferences
  static Future<String?> applyImportResult(
    ImportResult result, {
    ImportMode mode = ImportMode.merge,
  }) async {
    final db = DatabaseServiceFactory.getDatabaseService();
    String? backupPath;
    if (mode == ImportMode.replaceAll) {
      backupPath = await _createRollbackBackup(db);
      final existingWorkouts = await db.getWorkouts();
      for (final workout in existingWorkouts) {
        await db.deleteWorkout(workout.id);
      }

      final existingExercises = await db.getExercises();
      for (final exercise in existingExercises) {
        await db.deleteExercise(exercise.id);
      }
    }

    final exerciseIdRemap = await _buildExerciseIdRemap(
      db,
      result.exercises,
      mode,
    );

    for (final exercise in result.exercises) {
      final mappedId = exerciseIdRemap[exercise.id];
      if (mappedId == null || mappedId == exercise.id) {
        await db.insertExercise(exercise);
      }
    }

    for (final workout in result.workouts) {
      if (mode == ImportMode.merge) {
        await db.deleteWorkout(workout.id);
      }
      await db.insertWorkout(_remapWorkoutExercises(workout, exerciseIdRemap));
    }

    if (result.userPreferences.isNotEmpty) {
      await UserPreferencesService()
          .applyPreferences(result.userPreferences);
    }

    await ExerciseSeedService.ensureDefaultExercises(db);

    return backupPath;
  }

  /// Escape CSV special characters
  static String _escapeCsv(String value) {
    if (value.contains('"') || value.contains(',') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static List<List<String>> _parseCsv(String csvString) {
    final lines = const LineSplitter().convert(csvString);
    final rows = <List<String>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      rows.add(_parseCsvLine(line));
    }
    return rows;
  }

  static List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        final nextIsQuote = i + 1 < line.length && line[i + 1] == '"';
        if (nextIsQuote) {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }
    values.add(buffer.toString());
    return values;
  }

  static List<String> _normalizeHeaders(
    List<String> headers,
    CsvImportProfile profile,
  ) {
    final mapping = _profileHeaderMapping(profile);
    return headers.map((header) {
      final normalized = header
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '');
      return mapping[normalized] ?? _normalizeHeader(normalized);
    }).toList();
  }

  static Map<String, String> _profileHeaderMapping(
    CsvImportProfile profile,
  ) {
    switch (profile) {
      case CsvImportProfile.strengthWave:
        return const {};
      case CsvImportProfile.strong:
        return const {
          'date': 'date',
          'workoutname': 'workoutname',
          'workout': 'workoutname',
          'exercise': 'exercisename',
          'exercisename': 'exercisename',
          'setorder': 'setorder',
          'reps': 'reps',
          'weight': 'weight',
        };
      case CsvImportProfile.hevy:
        return const {
          'date': 'date',
          'workout': 'workoutname',
          'workoutname': 'workoutname',
          'exercise': 'exercisename',
          'exercisename': 'exercisename',
          'set': 'setorder',
          'reps': 'reps',
          'weight': 'weight',
        };
      case CsvImportProfile.generic:
      case CsvImportProfile.auto:
        return const {};
    }
  }

  static String _normalizeHeader(String normalized) {
    if (normalized.contains('workoutdate')) return 'date';
    if (normalized.contains('workoutname') || normalized == 'workout') {
      return 'workoutname';
    }
    if (normalized.contains('exerciseid')) return 'exerciseid';
    if (normalized.contains('exercisename') || normalized == 'exercise') {
      return 'exercisename';
    }
    if (normalized.contains('musclegroup') || normalized.contains('muscle')) {
      return 'musclegroup';
    }
    if (normalized.contains('category')) return 'category';
    if (normalized.contains('duration')) return 'durationmin';
    if (normalized.contains('completed')) return 'completed';
    if (normalized.contains('reps') || normalized.contains('repetitions')) {
      return 'reps';
    }
    if (normalized.contains('weight')) return 'weight';
    if (normalized.contains('date')) return 'date';
    return normalized;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    try {
      return DateTime.parse(trimmed);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd').parse(trimmed);
      } catch (_) {
        return null;
      }
    }
  }

  static bool _parseBool(String? value) {
    if (value == null) return false;
    final normalized = value.toLowerCase().trim();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  static int? _parseInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value.trim());
  }

  static double? _parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  static String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.md')) return 'text/markdown';
    return 'text/plain';
  }

  static Workout _remapWorkoutExercises(
    Workout workout,
    Map<String, String> exerciseIdRemap,
  ) {
    if (exerciseIdRemap.isEmpty) return workout;
    final remappedSets = workout.sets.map((set) {
      final newExerciseId = exerciseIdRemap[set.exerciseId] ?? set.exerciseId;
      if (newExerciseId == set.exerciseId) return set;
      return set.copyWith(exerciseId: newExerciseId);
    }).toList();
    return workout.copyWith(sets: remappedSets);
  }

  static Future<Map<String, String>> _buildExerciseIdRemap(
    DatabaseInterface db,
    List<Exercise> incomingExercises,
    ImportMode mode,
  ) async {
    if (mode == ImportMode.replaceAll) {
      return {};
    }

    final existing = await db.getExercises();
    final byKey = <String, Exercise>{};
    for (final exercise in existing) {
      final key = _exerciseKey(exercise.name, exercise.category);
      byKey[key] = exercise;
    }

    final remap = <String, String>{};
    for (final exercise in incomingExercises) {
      final key = _exerciseKey(exercise.name, exercise.category);
      final match = byKey[key];
      if (match != null) {
        remap[exercise.id] = match.id;
      }
    }
    return remap;
  }

  static String _exerciseKey(String name, String? category) {
    final normalizedName = name.trim().toLowerCase();
    final normalizedCategory = (category ?? '').trim().toLowerCase();
    return '$normalizedName|$normalizedCategory';
  }

  static Future<String?> _createRollbackBackup(DatabaseInterface db) async {
    try {
      if (kIsWeb) return null;
      final workouts = await db.getWorkouts();
      final exercises = await db.getExercises();
      final preferences = await UserPreferencesService().exportPreferences();
      final jsonData = await exportToJson(
        workouts: workouts,
        exercises: exercises,
        userPreferences: preferences,
      );
      final filename =
          'StrengthWave_Rollback_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.json';
      return await saveContentToFile(jsonData, filename);
    } catch (error, stackTrace) {
      AppLogger.error('Failed to create rollback backup', error, stackTrace);
      return null;
    }
  }
}

/// Result of import operation
class ImportResult {
  final List<Workout> workouts;
  final List<Exercise> exercises;
  final List<FitnessGoal> goals;
  final Map<String, dynamic> userPreferences;
  final Map<String, dynamic> metadata;

  ImportResult({
    required this.workouts,
    required this.exercises,
    required this.goals,
    required this.userPreferences,
    required this.metadata,
  });
}

/// Export format options
enum ExportFormat {
  json,
  csv,
  progressReport,
}

/// CSV import profile options
enum CsvImportProfile {
  auto,
  strengthWave,
  generic,
  strong,
  hevy,
}

/// Import behavior options
enum ImportMode {
  merge,
  replaceAll,
}

class _WorkoutImportBuilder {
  final String name;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final bool isCompleted;
  final int? durationMinutes;
  final List<WorkoutSet> sets = [];

  _WorkoutImportBuilder({
    required this.name,
    required this.scheduledDate,
    required this.completedDate,
    required this.isCompleted,
    required this.durationMinutes,
  });

  void addSet(WorkoutSet set) {
    sets.add(set);
  }

  Workout build() {
    return Workout(
      id: const Uuid().v4(),
      name: name,
      scheduledDate: scheduledDate,
      completedDate: completedDate,
      isCompleted: isCompleted,
      durationMinutes: durationMinutes,
      sets: sets,
    );
  }
}

/// Export options
class ExportOptions {
  final ExportFormat format;
  final bool includeCompletedOnly;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool includeGoals;
  final bool includePreferences;

  const ExportOptions({
    required this.format,
    this.includeCompletedOnly = false,
    this.startDate,
    this.endDate,
    this.includeGoals = true,
    this.includePreferences = false,
  });
}
