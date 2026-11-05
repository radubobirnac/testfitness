import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/screens/exercise_history_screen.dart';

void main() {
  const bench = Exercise(
    id: 'bench',
    name: 'Bench Press',
    category: 'Barbell',
    muscleGroup: 'Chest',
  );

  final now = DateTime.now();
  DateTime daysAgo(int d) => DateTime(now.year, now.month, now.day - d, 18);

  Workout workout(String id, int ago, List<(double, int)> sets,
      {bool warmup = false}) {
    final date = daysAgo(ago);
    return Workout(
      id: id,
      name: 'Push $id',
      scheduledDate: date,
      completedDate: date,
      isCompleted: true,
      sets: [
        if (warmup)
          WorkoutSet(
            id: '$id-wu',
            exerciseId: 'bench',
            weight: 40,
            reps: 8,
            isCompleted: true,
            completedAt: date,
            isWarmup: true,
          ),
        for (var i = 0; i < sets.length; i++)
          WorkoutSet(
            id: '$id-$i',
            exerciseId: 'bench',
            weight: sets[i].$1,
            reps: sets[i].$2,
            isCompleted: true,
            completedAt: date,
          ),
        WorkoutSet(
          id: '$id-other',
          exerciseId: 'squat',
          weight: 140,
          reps: 5,
          isCompleted: true,
          completedAt: date,
        ),
      ],
    );
  }

  final workouts = [
    workout('w1', 200, [(95, 5), (95, 5)]),
    workout('w2', 40, [(100, 5), (100, 5), (100, 5)], warmup: true),
    workout('w3', 20, [(105, 5), (105, 4)]),
    workout('w4', 5, [(105, 5), (105, 5), (110, 2)]),
  ];

  Widget app(Brightness brightness, Widget home) => MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal, brightness: brightness),
        ),
        home: home,
      );

  Future<void> pumpAt360(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('renders stats, records and sessions at 360dp ($brightness)',
        (tester) async {
      await pumpAt360(
        tester,
        app(brightness,
            ExerciseHistoryScreen(exercise: bench, workouts: workouts)),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Barbell · Chest'), findsOneWidget);

      // Header stats (default units are imperial when prefs are unset).
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      // Best e1RM: 105 × 5 → 122.5.
      expect(find.text('122.5 lb'), findsWidgets);
      expect(find.text('110 lb'), findsOneWidget); // heaviest
      expect(find.text('105 lb × 5'), findsWidgets); // best set
      expect(find.byKey(const Key('history-target')), findsOneWidget);
      expect(find.textContaining('Next:'), findsOneWidget);

      // Chart toggles present.
      expect(find.byKey(const Key('history-range-toggle')), findsOneWidget);

      // Records.
      await tester.scrollUntilVisible(
          find.text('Most volume in a session'), 200);
      expect(find.text('Best estimated 1RM'), findsOneWidget);
      expect(find.text('Heaviest weight'), findsWidgets);

      // Recent sessions, newest first; warm-ups and other exercises excluded.
      await tester.scrollUntilVisible(find.text('95×5, 95×5 lb'), 200);
      expect(find.text('105×5, 105×5, 110×2 lb'), findsOneWidget);
      expect(find.text('100×5, 100×5, 100×5 lb'), findsOneWidget);
      expect(find.textContaining('40×8'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows average RPE when sets are rated', (tester) async {
    final date = daysAgo(2);
    final rated = Workout(
      id: 'r1',
      name: 'Rated',
      completedDate: date,
      isCompleted: true,
      sets: [
        WorkoutSet(
            id: 'a',
            exerciseId: 'bench',
            weight: 100,
            reps: 5,
            isCompleted: true,
            completedAt: date,
            rpe: 7),
        WorkoutSet(
            id: 'b',
            exerciseId: 'bench',
            weight: 100,
            reps: 5,
            isCompleted: true,
            completedAt: date,
            rpe: 8),
      ],
    );
    await pumpAt360(
      tester,
      app(Brightness.light,
          ExerciseHistoryScreen(exercise: bench, workouts: [rated])),
    );
    final rpe = find.textContaining('RPE avg 7.5');
    await tester.scrollUntilVisible(rpe, 200);
    expect(rpe, findsOneWidget);
  });

  testWidgets('empty state when there is no history', (tester) async {
    await pumpAt360(
      tester,
      app(Brightness.dark,
          ExerciseHistoryScreen(exercise: bench, workouts: const [])),
    );
    expect(find.text('No history yet'), findsOneWidget);
    expect(find.text('Log a session to get a target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('range and metric toggles do not throw', (tester) async {
    await pumpAt360(
      tester,
      app(Brightness.light,
          ExerciseHistoryScreen(exercise: bench, workouts: workouts)),
    );
    for (final label in ['1 yr', 'All', '3 mo', 'Top set', 'e1RM']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows more than 20 sessions on demand', (tester) async {
    final many = [
      for (var i = 0; i < 25; i++) workout('m$i', i * 3 + 1, [(100, 5)]),
    ];
    await pumpAt360(
      tester,
      app(Brightness.light,
          ExerciseHistoryScreen(exercise: bench, workouts: many)),
    );
    final more = find.text('Show more (5)');
    await tester.scrollUntilVisible(more, 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
