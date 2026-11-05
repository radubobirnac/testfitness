import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/screens/workout_summary_screen.dart';

void main() {
  final day1 = DateTime(2026, 10, 28, 18);
  final finish = DateTime(2026, 11, 4, 19, 0);

  WorkoutSet set(String id, String exerciseId, double weight, int reps,
          {bool done = true, DateTime? at}) =>
      WorkoutSet(
        id: id,
        exerciseId: exerciseId,
        weight: weight,
        reps: reps,
        isCompleted: done,
        completedAt: done ? at : null,
      );

  final previous = Workout(
    id: 'w1',
    name: 'Push A',
    scheduledDate: day1,
    completedDate: day1,
    isCompleted: true,
    sets: [
      set('p1', 'bench', 100, 5, at: day1),
      set('p2', 'bench', 100, 5, at: day1),
    ],
  );

  final current = Workout(
    id: 'w2',
    name: 'Push B',
    scheduledDate: finish,
    completedDate: finish,
    isCompleted: true,
    durationMinutes: 45,
    sets: [
      set('c1', 'bench', 105, 5, at: finish.subtract(const Duration(minutes: 45))),
      set('c2', 'bench', 105, 4, at: finish.subtract(const Duration(minutes: 40))),
      set('c3', 'bench', 105, 3, done: false),
      set('c4', 'pullup', 0, 10, at: finish.subtract(const Duration(minutes: 30))),
    ],
  );

  Widget app({required Brightness brightness, required Widget home}) =>
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal, brightness: brightness),
        ),
        home: home,
      );

  WorkoutSummaryScreen summary() => WorkoutSummaryScreen(
        workout: current,
        allWorkouts: [previous, current],
        exerciseNames: const {'bench': 'Bench Press', 'pullup': 'Pull-up'},
        useMetric: true,
      );

  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows totals, best sets and new records at 360dp in dark mode',
      (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app(brightness: Brightness.dark, home: summary()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Push B'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);

    // Only completed sets count: 3 sets, 19 reps, 105*9 = 945 kg.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('945'), findsOneWidget);
    expect(find.text('Volume (kg)'), findsOneWidget);

    expect(find.byKey(const ValueKey('summary-records')), findsOneWidget);
    expect(find.textContaining('new record'), findsOneWidget);

    expect(find.text('105 kg × 5'), findsOneWidget);
    expect(find.text('×10'), findsOneWidget);
  });

  testWidgets('first-time exercises are not celebrated as records',
      (tester) async {
    await setPhoneSize(tester);
    final first = Workout(
      id: 'w3',
      name: 'Solo',
      completedDate: finish,
      isCompleted: true,
      sets: [set('s1', 'bench', 60, 8, at: finish)],
    );
    await tester.pumpWidget(app(
      brightness: Brightness.light,
      home: WorkoutSummaryScreen(
        workout: first,
        allWorkouts: [first],
        exerciseNames: const {'bench': 'Bench Press'},
        useMetric: false,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('60 lb × 8'), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-records')), findsNothing);
  });

  testWidgets('shows average RPE per exercise only when rated',
      (tester) async {
    await setPhoneSize(tester);
    final rated = Workout(
      id: 'w4',
      name: 'Rated',
      completedDate: finish,
      isCompleted: true,
      sets: [
        set('r1', 'bench', 60, 8, at: finish).copyWith(rpe: 8),
        set('r2', 'bench', 60, 8, at: finish).copyWith(rpe: 9),
        set('r3', 'bench', 60, 8, at: finish),
        set('r4', 'pullup', 0, 10, at: finish),
      ],
    );
    await tester.pumpWidget(app(
      brightness: Brightness.dark,
      home: WorkoutSummaryScreen(
        workout: rated,
        allWorkouts: [rated],
        exerciseNames: const {'bench': 'Bench Press', 'pullup': 'Pull-up'},
        useMetric: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('3 sets · avg RPE 8.5'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);
  });

  testWidgets('Done returns to the first route', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(app(
      brightness: Brightness.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => summary()),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Workout complete'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Workout complete'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
