import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:testfitness/data/default_exercises.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Service for handling database operations
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Get the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      AppLogger.database("Getting database path");
      String path;
      try {
        path = join(await getDatabasesPath(), 'fitness_app.db');
        AppLogger.database("Database path is: $path");
      } catch (e) {
        // Fallback path in case getDatabasesPath() fails
        AppLogger.warning(
            "Failed to get standard database path, using fallback", e);
        path = 'fitness_app.db'; // Use app directory
      }

      AppLogger.database("Opening database at $path");
      return await openDatabase(
        path,
        // v2: fitness_metrics table. v3: workout_sets.is_warmup column.
        version: 3,
        onCreate: (db, version) async {
          AppLogger.database("Creating database tables");
          await _createDatabase(db, version);
          AppLogger.database("Database tables created successfully");
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          AppLogger.database(
              "Upgrading database from $oldVersion to $newVersion");
          // v1 -> v2: add the fitness_metrics table
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE fitness_metrics(
                id TEXT PRIMARY KEY,
                type INTEGER NOT NULL,
                customName TEXT,
                value REAL NOT NULL,
                date INTEGER NOT NULL,
                unit TEXT,
                notes TEXT
              )
            ''');
            AppLogger.database("Added fitness_metrics table");
          }
          // v2 -> v3: warm-up flag on sets (existing sets are working sets)
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE workout_sets '
                'ADD COLUMN is_warmup INTEGER NOT NULL DEFAULT 0');
            AppLogger.database("Added workout_sets.is_warmup column");
          }
        },
        onOpen: (db) {
          AppLogger.database("Database opened successfully");
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error("Error initializing database", e, stackTrace);
      rethrow;
    }
  }

  /// Create the database tables
  Future<void> _createDatabase(Database db, int version) async {
    // Create exercises table
    await db.execute('''
      CREATE TABLE exercises(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        muscleGroup TEXT,
        category TEXT,
        imageUrl TEXT,
        isCustom INTEGER NOT NULL
      )
    ''');

    // Create workouts table
    await db.execute('''
      CREATE TABLE workouts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        scheduledDate INTEGER,
        completedDate INTEGER,
        isCompleted INTEGER NOT NULL,
        durationMinutes INTEGER,
        notes TEXT
      )
    ''');

    // Create workout sets table
    await db.execute('''
      CREATE TABLE workout_sets(
        id TEXT PRIMARY KEY,
        workoutId TEXT NOT NULL,
        exerciseId TEXT NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL NOT NULL,
        isCompleted INTEGER NOT NULL,
        completedAt INTEGER,
        restTimeSeconds INTEGER,
        notes TEXT,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (workoutId) REFERENCES workouts (id) ON DELETE CASCADE,
        FOREIGN KEY (exerciseId) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    // Create fitness metrics table
    await db.execute('''
      CREATE TABLE fitness_metrics(
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        customName TEXT,
        value REAL NOT NULL,
        date INTEGER NOT NULL,
        unit TEXT,
        notes TEXT
      )
    ''');

    // Insert some default exercises
    await _insertDefaultExercises(db);
  }

  /// Insert default exercises
  Future<void> _insertDefaultExercises(Database db) async {
    final defaultExercises = buildDefaultExercises();
    for (final exercise in defaultExercises) {
      await db.insert('exercises', exercise.toMap());
    }
  }

  // CRUD operations for exercises

  /// Get all exercises
  Future<List<Exercise>> getExercises() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('exercises');
    return List.generate(maps.length, (i) => Exercise.fromMap(maps[i]));
  }

  /// Get exercise by ID
  Future<Exercise?> getExercise(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Exercise.fromMap(maps.first);
  }

  /// Insert a new exercise
  Future<void> insertExercise(Exercise exercise) async {
    final db = await database;
    await db.insert(
      'exercises',
      exercise.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an exercise
  Future<void> updateExercise(Exercise exercise) async {
    final db = await database;
    await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  /// Delete an exercise
  Future<void> deleteExercise(String id) async {
    final db = await database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD operations for workouts

  /// Get all workouts with their sets
  Future<List<Workout>> getWorkouts() async {
    final db = await database;
    final List<Map<String, dynamic>> workoutMaps = await db.query('workouts');

    final List<Workout> workouts = [];
    for (final workoutMap in workoutMaps) {
      final String workoutId = workoutMap['id'];
      final List<Map<String, dynamic>> setMaps = await db.query(
        'workout_sets',
        where: 'workoutId = ?',
        whereArgs: [workoutId],
      );

      final List<WorkoutSet> sets = List.generate(
        setMaps.length,
        (i) => WorkoutSet.fromMap(setMaps[i]),
      );

      workouts.add(Workout.fromMap(workoutMap, sets));
    }

    return workouts;
  }

  /// Get workout by ID with its sets
  Future<Workout?> getWorkout(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> workoutMaps = await db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (workoutMaps.isEmpty) return null;

    final List<Map<String, dynamic>> setMaps = await db.query(
      'workout_sets',
      where: 'workoutId = ?',
      whereArgs: [id],
    );

    final List<WorkoutSet> sets = List.generate(
      setMaps.length,
      (i) => WorkoutSet.fromMap(setMaps[i]),
    );

    return Workout.fromMap(workoutMaps.first, sets);
  }

  /// Insert a new workout with its sets
  Future<void> insertWorkout(Workout workout) async {
    final db = await database;
    await db.transaction((txn) async {
      // Insert workout
      await txn.insert(
        'workouts',
        workout.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert sets
      for (final set in workout.sets) {
        final setMap = _setToRow(set, workout.id);
        await txn.insert(
          'workout_sets',
          setMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Update a workout and its sets
  Future<void> updateWorkout(Workout workout) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update workout
      await txn.update(
        'workouts',
        workout.toMap(),
        where: 'id = ?',
        whereArgs: [workout.id],
      );

      // Delete existing sets
      await txn.delete(
        'workout_sets',
        where: 'workoutId = ?',
        whereArgs: [workout.id],
      );

      // Insert updated sets
      for (final set in workout.sets) {
        final setMap = _setToRow(set, workout.id);
        await txn.insert(
          'workout_sets',
          setMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// A [WorkoutSet] as a `workout_sets` row. The model's `isWarmup` key is
  /// stored in the snake_case `is_warmup` column ([WorkoutSet.fromMap] reads
  /// either spelling).
  static Map<String, dynamic> _setToRow(WorkoutSet set, String workoutId) {
    final row = set.toMap();
    row['workoutId'] = workoutId;
    row['is_warmup'] = set.isWarmup ? 1 : 0;
    row.remove('isWarmup');
    return row;
  }

  /// Delete a workout and its sets
  Future<void> deleteWorkout(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete sets first (due to foreign key constraint)
      await txn.delete('workout_sets', where: 'workoutId = ?', whereArgs: [id]);

      // Delete workout
      await txn.delete('workouts', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Get all fitness metrics
  Future<List<FitnessMetric>> getMetrics() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('fitness_metrics');

    return maps
        .map(FitnessMetric.tryFromMap)
        .whereType<FitnessMetric>()
        .toList();
  }

  /// Get metrics of a specific type
  Future<List<FitnessMetric>> getMetricsByType(MetricType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fitness_metrics',
      where: 'type = ?',
      whereArgs: [type.index],
      orderBy: 'date DESC',
    );

    return maps
        .map(FitnessMetric.tryFromMap)
        .whereType<FitnessMetric>()
        .toList();
  }

  /// Get metrics within a date range
  Future<List<FitnessMetric>> getMetricsByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fitness_metrics',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'date DESC',
    );

    return maps
        .map(FitnessMetric.tryFromMap)
        .whereType<FitnessMetric>()
        .toList();
  }

  /// Get metrics of a specific type within a date range
  Future<List<FitnessMetric>> getMetricsByTypeAndDateRange(
      MetricType type, DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fitness_metrics',
      where: 'type = ? AND date >= ? AND date <= ?',
      whereArgs: [
        type.index,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch
      ],
      orderBy: 'date DESC',
    );

    return maps
        .map(FitnessMetric.tryFromMap)
        .whereType<FitnessMetric>()
        .toList();
  }

  /// Get the most recent metric of a specific type
  Future<FitnessMetric?> getLatestMetricByType(MetricType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fitness_metrics',
      where: 'type = ?',
      whereArgs: [type.index],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return FitnessMetric.tryFromMap(maps.first);
    }
    return null;
  }

  /// Insert a new fitness metric
  Future<void> insertMetric(FitnessMetric metric) async {
    final db = await database;
    await db.insert(
      'fitness_metrics',
      metric.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a fitness metric
  Future<void> updateMetric(FitnessMetric metric) async {
    final db = await database;
    await db.update(
      'fitness_metrics',
      metric.toMap(),
      where: 'id = ?',
      whereArgs: [metric.id],
    );
  }

  /// Delete a fitness metric
  Future<void> deleteMetric(String id) async {
    final db = await database;
    await db.delete(
      'fitness_metrics',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
