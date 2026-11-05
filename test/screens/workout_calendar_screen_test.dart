import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/screens/workout_calendar_screen.dart';

WorkoutSet _set(String id, String ex,
        {bool done = true, DateTime? at, bool warmup = false}) =>
    WorkoutSet(
      id: id,
      exerciseId: ex,
      reps: 5,
      weight: 100,
      isCompleted: done,
      completedAt: at,
      isWarmup: warmup,
    );

void main() {
  final now = DateTime(2026, 11, 18, 10);

  final workouts = [
    // Done on 3 Nov by set time, although scheduled on 2 Nov.
    Workout(
      id: 'w1',
      name: 'Push Day',
      scheduledDate: DateTime(2026, 11, 2),
      sets: [
        _set('s1', 'bench', at: DateTime(2026, 11, 3, 18)),
        _set('s2', 'bench', at: DateTime(2026, 11, 3, 18, 5)),
        _set('s3', 'ohp', at: DateTime(2026, 11, 3, 18, 20)),
      ],
    ),
    // Done on 10 Nov via completedDate (no set times).
    Workout(
      id: 'w2',
      name: 'Pull Day',
      completedDate: DateTime(2026, 11, 10, 9),
      isCompleted: true,
      sets: [_set('s4', 'row')],
    ),
    // Only a completed warm-up: not done -> scheduled ring on 12 Nov.
    Workout(
      id: 'w3',
      name: 'Leg Day',
      scheduledDate: DateTime(2026, 11, 12),
      sets: [
        _set('s5', 'squat', at: DateTime(2026, 11, 12, 7), warmup: true),
        _set('s6', 'squat', done: false),
      ],
    ),
    // Previous month.
    Workout(
      id: 'w4',
      name: 'October Session',
      sets: [_set('s7', 'deadlift', at: DateTime(2026, 10, 20, 8))],
    ),
  ];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: WorkoutCalendarScreen(
          workouts: workouts, now: now, useMetric: true),
    ));
    await tester.pumpAndSettle();
  }

  test('buildCalendarEntries uses the coach date and needs a working set', () {
    final entries = buildCalendarEntries(workouts);
    expect(entries[DateTime(2026, 11, 3)]!.single.isDone, isTrue);
    expect(entries[DateTime(2026, 11, 2)], isNull);
    expect(entries[DateTime(2026, 11, 10)]!.single.workout.id, 'w2');
    expect(entries[DateTime(2026, 11, 12)]!.single.isDone, isFalse);
    expect(entries[DateTime(2026, 10, 20)]!.single.isDone, isTrue);
  });

  testWidgets('shows dots on the right days and a month summary',
      (tester) async {
    await pump(tester);

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-done-2026-11-03')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-done-2026-11-10')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-scheduled-2026-11-12')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-done-2026-11-02')),
        findsNothing);
    expect(find.byKey(const ValueKey('calendar-done-2026-11-12')),
        findsNothing);
    // Weeks of 3 and 10 Nov are active (this week is not yet): streak 2.
    expect(find.text('2 workouts · 2-week streak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a day lists its workouts', (tester) async {
    await pump(tester);

    // Today (18 Nov) is selected by default and empty.
    expect(find.text('No workouts on this day'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-03')));
    await tester.pumpAndSettle();
    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('2 exercises · 3 sets · 1500 kg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-12')));
    await tester.pumpAndSettle();
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('Planned · 1 exercise · 2 sets'), findsOneWidget);
    expect(find.text('Push Day'), findsNothing);
  });

  testWidgets('arrows, swipe and Today change the month', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-done-2026-10-20')),
        findsOneWidget);
    expect(find.text('1 workout · 2-week streak'), findsOneWidget);

    await tester.tap(find.byTooltip('Today'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);

    // Swipe right -> previous month.
    await tester.fling(find.text('December 2026'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
