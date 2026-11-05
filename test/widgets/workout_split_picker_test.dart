import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/split_workout_builder.dart';
import 'package:testfitness/utils/muscle_map.dart';
import 'package:testfitness/widgets/workout_split_picker.dart';

final _now = DateTime(2026, 11, 5, 12);

const _exercises = [
  Exercise(id: 'bench', name: 'Bench Press', muscleGroup: 'Chest'),
  Exercise(id: 'fly', name: 'Cable Fly', muscleGroup: 'Chest'),
  Exercise(id: 'row', name: 'Barbell Row', muscleGroup: 'Back'),
  Exercise(id: 'pulldown', name: 'Lat Pulldown', muscleGroup: 'Back'),
  Exercise(id: 'pullup', name: 'Pull-Up', muscleGroup: 'Back'),
  Exercise(id: 'curl', name: 'Barbell Curl', muscleGroup: 'Arms'),
  Exercise(id: 'hammer', name: 'Hammer Curl', muscleGroup: 'Arms'),
  Exercise(id: 'pushdown', name: 'Triceps Pushdown', muscleGroup: 'Arms'),
  Exercise(id: 'squat', name: 'Squat', muscleGroup: 'Legs'),
  Exercise(id: 'rdl', name: 'Romanian Deadlift', muscleGroup: 'Legs'),
  Exercise(id: 'ohp', name: 'Overhead Press', muscleGroup: 'Shoulders'),
  Exercise(id: 'plank', name: 'Plank', muscleGroup: 'Core'),
];

/// Chest trained yesterday (bench 100 × 8).
final _history = [
  Workout(
    id: 'w1',
    name: 'Push',
    isCompleted: true,
    completedDate: _now.subtract(const Duration(days: 1)),
    sets: [
      for (var i = 0; i < 3; i++)
        WorkoutSet(
          id: 's$i',
          exerciseId: 'bench',
          reps: 8,
          weight: 100,
          isCompleted: true,
          completedAt: _now.subtract(const Duration(days: 1)),
        ),
    ],
  ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    List<Exercise> exercises = _exercises,
    ValueChanged<SplitPickerResult>? onStart,
  }) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: WorkoutSplitPicker(
        history: _history,
        exercises: exercises,
        useMetric: true,
        now: _now,
        routineRepository: RoutineRepository(),
        onStart: onStart,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('shows suggestion, 6 presets and custom (${brightness.name})',
        (tester) async {
      await pump(tester, brightness: brightness);

      expect(find.text('Choose your workout'), findsOneWidget);
      expect(find.textContaining('Suggested for today: '), findsOneWidget);
      expect(find.textContaining('the most rested'), findsOneWidget);
      for (final split in WorkoutSplit.presets) {
        expect(find.byKey(Key('split_${split.id}')), findsOneWidget);
        expect(find.text(split.name), findsOneWidget);
      }
      expect(find.text('Back · Biceps'), findsOneWidget);
      expect(find.text('Chest: trained 1 day ago'), findsWidgets);
      expect(find.text('Back: not trained yet'), findsWidgets);
      expect(find.byKey(const Key('split_custom')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('custom flow cannot pick the same muscle twice', (tester) async {
    await pump(tester, brightness: Brightness.dark);
    await tapVisible(tester, find.byKey(const Key('split_custom')));

    expect(find.text('Pick your main muscle'), findsOneWidget);
    expect(find.text(Muscle.cardio.label), findsNothing);
    await tapVisible(tester, find.byKey(const Key('muscle_back')));

    expect(find.text('Pick a second muscle'), findsOneWidget);
    final back = tester.widget<OutlinedButton>(
        find.byKey(const Key('muscle_back')));
    expect(back.onPressed, isNull);
    final biceps = tester.widget<OutlinedButton>(
        find.byKey(const Key('muscle_biceps')));
    expect(biceps.onPressed, isNotNull);
    expect(tester.getSize(find.byKey(const Key('muscle_biceps'))).height,
        greaterThanOrEqualTo(48));

    await tapVisible(tester, find.byKey(const Key('muscle_biceps')));
    expect(find.text('Back & Biceps'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recently trained split asks before starting', (tester) async {
    await pump(tester);
    await tapVisible(tester, find.byKey(const Key('split_chest_triceps')));

    expect(find.textContaining('trained in the last 48 h. Start anyway?'),
        findsOneWidget);
    await tester.tap(find.text('Pick another'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your workout'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('split_chest_triceps')));
    await tester.tap(find.text('Start anyway'));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsOneWidget);
    // History target for bench: 100 × 8 (or progressed) · 3 sets.
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.textContaining('× 8 · 3 sets'), findsWidgets);
  });

  testWidgets('preview lists exercises, saves routine and starts',
      (tester) async {
    SplitPickerResult? started;
    await pump(tester, onStart: (r) => started = r);
    await tapVisible(tester, find.byKey(const Key('split_back_biceps')));

    expect(find.text('Back & Biceps'), findsOneWidget);
    expect(find.text('Barbell Row'), findsOneWidget);
    expect(find.text('Barbell Curl'), findsOneWidget);
    expect(find.textContaining('· 3 sets'), findsWidgets);
    // No AI key in tests: no AI toggle.
    expect(find.text('Use AI to build it'), findsNothing);

    await tester.tap(find.text('Save as routine'));
    await tester.pumpAndSettle();
    expect(find.text('Saved "Back & Biceps" as a routine'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(RoutineRepository.storageKey)!) as List;
    expect(stored, hasLength(1));
    expect((stored.first as Map)['name'], 'Back & Biceps');

    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    expect(started, isNotNull);
    expect(started!.workout.name, 'Back & Biceps');
    expect(started!.workout.exerciseIds, contains('row'));
    expect(started!.message, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI toggle falls back to the coach plan on failure',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SplitPickerResult? started;
    await tester.pumpWidget(MaterialApp(
      home: WorkoutSplitPicker(
        history: _history,
        exercises: _exercises,
        useMetric: true,
        now: _now,
        aiAvailable: true,
        aiBuilder: (split, history, pool) async => throw Exception('offline'),
        onStart: (r) => started = r,
      ),
    ));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('split_back_biceps')));

    await tester.tap(find.text('Use AI to build it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();

    expect(started, isNotNull);
    expect(started!.workout.name, 'Back & Biceps');
    expect(started!.workout.sets, isNotEmpty);
    expect(started!.message, contains('coach plan'));
  });

  testWidgets('empty library shows a friendly message', (tester) async {
    await pump(tester, exercises: const []);
    await tapVisible(tester, find.byKey(const Key('split_legs')));

    expect(find.textContaining('No exercises for'), findsOneWidget);
    expect(find.text('Start workout'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('AI prompt split instruction', () {
    const split = AiSplitRequest(
        name: 'Back & Biceps', main: ['Back'], secondary: ['Biceps']);
    expect(AIService.splitInstruction(split),
        startsWith('Build a Back & Biceps workout: main back, secondary biceps.'));
  });

  test('describe helpers', () {
    expect(describeMuscles([Muscle.back, Muscle.biceps]), 'Back & biceps');
    expect(describeMuscles([Muscle.quads, Muscle.hamstrings, Muscle.glutes]),
        'Quads, hamstrings & glutes');
    expect(describeTrained(null, _now), 'not trained yet');
    expect(describeTrained(_now.subtract(const Duration(days: 1)), _now),
        'trained 1 day ago');
    expect(describeTrained(_now, _now), 'trained today');
  });
}
