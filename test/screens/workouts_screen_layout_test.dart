import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/workouts_screen.dart';

/// Records events instead of touching the database. A load request flips
/// isLoading so pull-to-refresh completes.
class FakeWorkoutBloc extends WorkoutBloc {
  FakeWorkoutBloc(List<Workout> workouts) {
    emit(WorkoutState(workouts: workouts));
  }

  final List<WorkoutEvent> events = [];

  @override
  void add(WorkoutEvent event) {
    events.add(event);
    if (event is WorkoutLoadRequested) {
      scheduleMicrotask(() {
        if (isClosed) return;
        emit(state.copyWith(isLoading: true));
        emit(state.copyWith(isLoading: false));
      });
    }
  }

  int get loadCount => events.whereType<WorkoutLoadRequested>().length;
}

final now = DateTime(2026, 11, 5, 12); // Thursday

List<WorkoutSet> _sets(int exercises, {bool done = false}) => [
      for (var e = 0; e < exercises; e++)
        for (var s = 0; s < 3; s++)
          WorkoutSet(
            id: 'set_${e}_$s',
            exerciseId: 'ex$e',
            reps: 10,
            weight: 50,
            isCompleted: done,
          ),
    ];

Workout _planned(String id, String name, DateTime date) => Workout(
    id: id, name: name, scheduledDate: date, sets: _sets(4));

Workout _done(String id, String name, DateTime date) => Workout(
      id: id,
      name: name,
      scheduledDate: date,
      completedDate: date,
      isCompleted: true,
      sets: _sets(5, done: true),
    );

final sampleWorkouts = <Workout>[
  _planned('p1', 'Leg Day', DateTime(2026, 11, 7)),
  _planned('p2', 'Overdue Push', DateTime(2026, 11, 1)),
  _done('d1', 'Upper A', DateTime(2026, 11, 4)),
  _done('d2', 'Lower A', DateTime(2026, 11, 2)),
  _done('d3', 'Upper B', DateTime(2026, 10, 28)),
  _done('d4', 'Lower B', DateTime(2026, 10, 26)),
  _done('d5', 'Full Body 1', DateTime(2026, 10, 10)),
  _done('d6', 'Full Body 2', DateTime(2026, 10, 5)),
  _done('d7', 'Back & Biceps', DateTime(2026, 9, 20)),
  _done('d8', 'Chest & Triceps', DateTime(2026, 9, 10)),
];

void main() {
  group('groupWorkoutsIntoSections', () {
    List<String> titles(List<WorkoutSection> s) =>
        s.map((e) => e.title).toList();

    test('newest first: Planned, This week, Last week, months', () {
      final sections = groupWorkoutsIntoSections(sampleWorkouts, now: now);
      expect(titles(sections), [
        'Planned',
        'This week',
        'Last week',
        'October 2026',
        'September 2026',
      ]);
      expect(sections.first.workouts.map((w) => w.id), ['p1', 'p2']);
      expect(sections[1].workouts.map((w) => w.id), ['d1', 'd2']);
      expect(sections[2].workouts.map((w) => w.id), ['d3', 'd4']);
    });

    test('oldest first reverses order within and between finished groups',
        () {
      final sections = groupWorkoutsIntoSections(sampleWorkouts,
          now: now, newestFirst: false);
      expect(titles(sections), [
        'Planned',
        'September 2026',
        'October 2026',
        'Last week',
        'This week',
      ]);
      expect(sections.first.workouts.map((w) => w.id), ['p2', 'p1']);
      expect(sections.last.workouts.map((w) => w.id), ['d2', 'd1']);
    });

    test('filters', () {
      expect(
          titles(groupWorkoutsIntoSections(sampleWorkouts,
              now: now, filter: WorkoutFilter.planned)),
          ['Planned']);
      expect(
          titles(groupWorkoutsIntoSections(sampleWorkouts,
                  now: now, filter: WorkoutFilter.done))
              .contains('Planned'),
          isFalse);
      expect(groupWorkoutsIntoSections(const [], now: now), isEmpty);
    });

    test('week boundaries start on Monday', () {
      expect(completedGroupLabel(DateTime(2026, 11, 2), now), 'This week');
      expect(completedGroupLabel(DateTime(2026, 11, 1, 23), now), 'Last week');
      expect(completedGroupLabel(DateTime(2026, 10, 26), now), 'Last week');
      expect(completedGroupLabel(DateTime(2026, 10, 25), now), 'October 2026');
    });

    test('overdue and meta helpers', () {
      expect(isWorkoutOverdue(sampleWorkouts[1], now), isTrue);
      expect(isWorkoutOverdue(sampleWorkouts[0], now), isFalse);
      expect(isWorkoutOverdue(sampleWorkouts[2], now), isFalse);
      expect(
        formatWorkoutMeta(
            exerciseCount: 5, setCount: 15, date: DateTime(2026, 11, 5)),
        '5 exercises · 15 sets · Thu, Nov 5',
      );
      expect(
        formatWorkoutMeta(
            exerciseCount: 1,
            setCount: 1,
            date: DateTime(2026, 11, 5),
            volume: 12400,
            unitLabel: 'lbs'),
        '1 exercise · 1 set · Thu, Nov 5 · 12,400 lbs',
      );
      expect(workoutVolume(sampleWorkouts[2]), 5 * 3 * 10 * 50);
    });
  });

  group('WorkoutsScreen', () {
    late FakeWorkoutBloc bloc;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpScreen(
      WidgetTester tester, {
      List<Workout>? workouts,
      int routines = 3,
      bool aiAvailable = false,
      Size size = const Size(375, 812),
      Brightness brightness = Brightness.light,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = RoutineRepository();
      for (var i = 0; i < routines; i++) {
        await tester.runAsync(() => repository.saveRoutine(Routine(
              id: 'r$i',
              name: 'Routine $i',
              exercises: const [
                RoutineExercise(exerciseId: 'a', sets: 3),
                RoutineExercise(exerciseId: 'b', sets: 3),
              ],
              createdAt: DateTime(2026, 1, 1 + i),
            )));
      }

      bloc = FakeWorkoutBloc(workouts ?? sampleWorkouts);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: BlocProvider<WorkoutBloc>.value(
            value: bloc,
            child: WorkoutsScreen(
              isAiAvailable: () => aiAvailable,
              routineRepository: repository,
              clock: () => now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Iterable<Rect> visibleCards(WidgetTester tester, double height) => find
        .byType(WorkoutListCard)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .where((r) => r.top >= 0 && r.bottom <= height);

    testWidgets('375x812: 6+ cards visible, grouped headers, routines strip',
        (tester) async {
      // Normal case: no overdue backlog (that adds a "Mark overdue done"
      // action to the Planned header; see workouts_overdue_test.dart).
      await pumpScreen(tester,
          workouts: sampleWorkouts.where((w) => w.id != 'p2').toList());
      expect(tester.takeException(), isNull);
      expect(bloc.loadCount, 1);

      final cards = visibleCards(tester, 812).toList();
      final height = tester.getSize(find.byType(WorkoutListCard).first).height;
      debugPrint('visible cards: ${cards.length}, card height: $height');
      expect(cards.length, greaterThanOrEqualTo(6));

      expect(find.text('Routines'), findsOneWidget);
      expect(find.text('Routine 0'), findsOneWidget);
      expect(find.text('Planned'), findsWidgets); // header + filter segment
      expect(find.text('This week'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Start workout'), findsOneWidget);

      // Months appear further down; the list scrolls as one.
      await tester.scrollUntilVisible(find.text('September 2026'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('no overflow at 360dp in dark mode', (tester) async {
      await pumpScreen(tester,
          size: const Size(360, 740), brightness: Brightness.dark);
      expect(tester.takeException(), isNull);
      final overdue = find.textContaining('Overdue · ', findRichText: true);
      expect(overdue, findsOneWidget);
    });

    testWidgets('filter switches between All, Planned and Done',
        (tester) async {
      await pumpScreen(tester, routines: 0);
      expect(find.text('Leg Day'), findsOneWidget);
      expect(find.text('Upper A'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Leg Day'), findsNothing);
      expect(find.text('Upper A'), findsOneWidget);

      await tester.tap(find.text('Planned').first);
      await tester.pumpAndSettle();
      expect(find.text('Leg Day'), findsOneWidget);
      expect(find.text('Overdue Push'), findsOneWidget);
      expect(find.text('Upper A'), findsNothing);
      expect(find.byType(WorkoutListCard), findsNWidgets(2));
    });

    testWidgets('empty Planned filter shows hint', (tester) async {
      await pumpScreen(tester,
          routines: 0,
          workouts: sampleWorkouts.where((w) => w.isCompleted).toList());
      await tester.tap(find.text('Planned'));
      await tester.pumpAndSettle();
      expect(find.text('No planned workouts'), findsOneWidget);
      expect(find.text('Tap Start workout to plan one'), findsOneWidget);
    });

    testWidgets('sort menu switches to oldest first', (tester) async {
      await pumpScreen(tester, routines: 0);
      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oldest first'));
      await tester.pumpAndSettle();
      final headers = ['Planned', 'September 2026'];
      // Planned stays on top, then the oldest month.
      final y0 = tester.getTopLeft(find.text(headers[0]).last).dy;
      final y1 = tester.getTopLeft(find.text(headers[1])).dy;
      expect(y0, lessThan(y1));
    });

    testWidgets('start sheet lists options; AI hidden when unavailable',
        (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Start workout'));
      await tester.pumpAndSettle();

      expect(find.text('Start a workout'), findsOneWidget);
      expect(find.text('Empty workout'), findsOneWidget);
      expect(find.text('Choose by muscle group'), findsOneWidget);
      expect(find.text("Coach's next workout"), findsOneWidget);
      expect(find.byKey(const Key('start_sheet_ai')), findsNothing);
      expect(find.text('From a routine'), findsOneWidget);
      expect(find.text('Routine 1'), findsWidgets);

      for (final key in ['start_sheet_empty', 'start_sheet_next']) {
        expect(tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('start sheet shows AI build when available, empty routines',
        (tester) async {
      await pumpScreen(tester, routines: 0, aiAvailable: true);
      await tester.tap(find.text('Start workout'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('start_sheet_ai')), findsOneWidget);
      expect(find.text('No routines yet'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads workouts', (tester) async {
      await pumpScreen(tester, routines: 0);
      expect(bloc.loadCount, 1);
      await tester.fling(
          find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(bloc.loadCount, 2);
    });
  });
}
