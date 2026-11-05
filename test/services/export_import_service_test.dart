import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_goal.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/export_import_service.dart';

void main() {
  group('CSV escaping and parsing', () {
    test('escapes each field exactly once per RFC 4180', () {
      expect(ExportImportService.escapeCsvField('plain'), 'plain');
      expect(
          ExportImportService.escapeCsvField('Chest, Arms'), '"Chest, Arms"');
      expect(ExportImportService.escapeCsvField('say "hi"'), '"say ""hi"""');
      expect(ExportImportService.escapeCsvField('a\nb'), '"a\nb"');
    });

    test('parses quoted fields with commas, doubled quotes and newlines', () {
      const csv = 'a,b,c\r\n'
          '"Chest, Arms","He said ""go""","line1\nline2"\n'
          '\n'
          'x,,z\n';
      final rows = ExportImportService.parseCsv(csv);
      expect(rows, [
        ['a', 'b', 'c'],
        ['Chest, Arms', 'He said "go"', 'line1\nline2'],
        ['x', '', 'z'],
      ]);
    });

    test('export/import round-trips fields containing commas and quotes',
        () async {
      const exercise = Exercise(
        id: 'ex-1',
        name: 'Close-Grip "Bench" Press',
        muscleGroup: 'Chest, Arms',
        category: 'Strength',
      );
      final workout = Workout(
        id: 'w-1',
        name: 'Push, Day "A"',
        scheduledDate: DateTime(2026, 1, 5),
        completedDate: DateTime(2026, 1, 5),
        isCompleted: true,
        durationMinutes: 45,
        sets: [
          WorkoutSet.create(
              exerciseId: 'ex-1', reps: 8, weight: 60, isCompleted: true),
        ],
      );

      final csv = await ExportImportService.exportToCsv(
        [workout],
        exercises: const [exercise],
      );
      expect(csv, contains('"Chest, Arms"'));
      expect(csv, isNot(contains('""Chest, Arms""')));

      final result = await ExportImportService.importFromCsv(csv);
      expect(result.workouts, hasLength(1));
      expect(result.workouts.single.name, 'Push, Day "A"');
      expect(result.workouts.single.isCompleted, isTrue);
      expect(result.workouts.single.durationMinutes, 45);
      expect(result.workouts.single.sets.single.reps, 8);
      expect(result.workouts.single.sets.single.weight, 60);

      final imported = result.exercises.single;
      expect(imported.id, 'ex-1');
      expect(imported.name, 'Close-Grip "Bench" Press');
      expect(imported.muscleGroup, 'Chest, Arms');
      expect(imported.category, 'Strength');
    });
  });

  group('JSON backup', () {
    test('round-trips goals and metrics', () async {
      final goal = FitnessGoal(
        id: 'g-1',
        title: 'Bench 100',
        description: 'Bench press 100 kg',
        type: GoalType.exerciseSpecific,
        status: GoalStatus.active,
        createdDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        targetDate: DateTime.fromMillisecondsSinceEpoch(1800000000000),
        targetValue: 100,
        currentValue: 80,
        unit: 'kg',
      );
      final metric = FitnessMetric(
        id: 'm-1',
        type: MetricType.weight,
        value: 82.5,
        date: DateTime.fromMillisecondsSinceEpoch(1750000000000),
        unit: 'kg',
      );

      final json = await ExportImportService.exportToJson(
        workouts: const [],
        exercises: const [],
        goals: [goal],
        metrics: [metric],
      );
      final result = await ExportImportService.importFromJson(json);

      expect(result.goals, [goal]);
      expect(result.metrics, [metric]);
    });

    test('older backups without metrics still import', () async {
      final json = await ExportImportService.exportToJson(
        workouts: const [],
        exercises: const [],
      );
      final withoutMetrics = json.replaceAll(RegExp(r'"metrics": \[\],?'), '');
      final result = await ExportImportService.importFromJson(withoutMetrics);
      expect(result.metrics, isEmpty);
    });
  });
}
