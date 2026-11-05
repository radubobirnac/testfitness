import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/home_screen.dart';
import 'package:testfitness/screens/workouts_screen.dart';

/// Records events instead of touching the database.
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
}

/// Records tab switches.
class FakeAppBloc extends AppBloc {
  final List<AppEvent> events = [];

  @override
  void add(AppEvent event) => events.add(event);
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

Workout _planned(String id, String name, DateTime date) =>
    Workout(id: id, name: name, scheduledDate: date, sets: _sets(4));

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
  _planned('p3', 'Push Day', DateTime(2026, 11, 9)),
  _planned('p4', 'Pull Day', DateTime(2026, 11, 11)),
  _planned('p5', 'Arms Later', DateTime(2026, 11, 20)),
  // This week: 2 workouts, 30 sets, 15,000 kg. Last week: 2 workouts.
  _done('d1', 'Upper A', DateTime(2026, 11, 4)),
  _done('d2', 'Lower A', DateTime(2026, 11, 2)),
  _done('d3', 'Upper B', DateTime(2026, 10, 28)),
  _done('d4', 'Lower B', DateTime(2026, 10, 26)),
  _done('d5', 'Full Body 1', DateTime(2026, 10, 10)),
];

void main() {
  late FakeWorkoutBloc bloc;
  late FakeAppBloc appBloc;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(
    WidgetTester tester, {
    List<Workout>? workouts,
    int routines = 2,
    bool aiAvailable = false,
    Size size = const Size(360, 740),
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
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
    appBloc = FakeAppBloc();
    addTearDown(bloc.close);
    addTearDown(appBloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<WorkoutBloc>.value(value: bloc),
            BlocProvider<AppBloc>.value(value: appBloc),
          ],
          child: HomeScreen(
            isAiAvailable: () => aiAvailable,
            routineRepository: repository,
            clock: () => now,
            suggestionLoader: (_) async => 'Coach suggests: Squat 100 kg × 5',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder scrollable() => find.byType(Scrollable).first;

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final (label, brightness, scale) in [
    ('light', Brightness.light, 1.0),
    ('dark', Brightness.dark, 1.0),
    ('text x1.3', Brightness.light, 1.3),
  ]) {
    testWidgets('360dp $label: all sections present, no overflow',
        (tester) async {
      await pumpHome(tester, brightness: brightness, textScale: scale);
      expect(tester.takeException(), isNull);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Thursday, Nov 5'), findsOneWidget);
      expect(find.byKey(const Key('home_start_workout')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await scrollTo(tester, find.byKey(const Key('home_suggestion_card')));
      expect(find.text('Coach suggestion'), findsOneWidget);

      await scrollTo(tester, find.byKey(const Key('home_upcoming_see_all')));
      await scrollTo(tester, find.text('Routine 0'));
      await scrollTo(tester, find.byKey(const Key('home_week_summary')));
      await scrollTo(tester, find.text('Recent workouts'));
      await scrollTo(tester, find.byKey(const Key('home_tools')));
      for (final tool in [
        'Find Your Weight',
        'Boxing Cardio',
        'Heart Rate',
        'VO2 Max Training',
      ]) {
        await scrollTo(tester, find.text(tool));
      }
    });
  }

  testWidgets('touch targets are at least 48dp', (tester) async {
    await pumpHome(tester);
    for (final key in [
      'home_start_workout',
      'home_suggestion_start',
      'home_choose_workout',
      'home_suggestion_refresh',
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets('Start workout opens the shared start sheet', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('home_start_workout')));
    await tester.pumpAndSettle();

    expect(find.byType(StartWorkoutSheet), findsOneWidget);
    expect(find.text('Start a workout'), findsOneWidget);
    expect(find.text('Empty workout'), findsOneWidget);
    expect(find.text('Choose by muscle group'), findsOneWidget);
    expect(find.text("Coach's next workout"), findsOneWidget);
    expect(find.byKey(const Key('start_sheet_ai')), findsNothing);
    expect(find.text('From a routine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggestion card merges coach plan and split picker',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('Coach suggests: Squat 100 kg × 5'), findsOneWidget);
    expect(find.text('Start this'), findsOneWidget);
    expect(find.text('Choose another'), findsOneWidget);
    // The old separate cards / duplicate entry points are gone.
    expect(find.text('Choose your workout'), findsNothing);
    expect(find.text('Start Empty Workout'), findsNothing);
    expect(find.text('Track Progress'), findsNothing);
  });

  testWidgets('AI labels when AI is available', (tester) async {
    await pumpHome(tester, aiAvailable: true);
    expect(find.text('AI workout suggestion'), findsOneWidget);
    expect(find.text('Create AI workout'), findsOneWidget);
  });

  testWidgets('upcoming shows at most 3 planned workouts, soonest first',
      (tester) async {
    // Tall view so the whole Upcoming section is on screen.
    await pumpHome(tester, routines: 0, size: const Size(360, 1400));
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('Pull Day'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('Arms Later'), findsNothing);
    expect(find.text('Overdue Push'), findsNothing);
    expect(tester.getTopLeft(find.text('Leg Day')).dy,
        lessThan(tester.getTopLeft(find.text('Pull Day')).dy));
  });

  testWidgets('this week summary and recent workouts', (tester) async {
    await pumpHome(tester, routines: 0);
    await scrollTo(tester, find.byKey(const Key('home_week_summary')));
    final summary = find.byKey(const Key('home_week_summary'));
    expect(find.descendant(of: summary, matching: find.text('30')),
        findsOneWidget);
    expect(find.descendant(of: summary, matching: find.textContaining(RegExp(r'^15K'))),
        findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('Last wk 2')),
        findsOneWidget);

    await scrollTo(tester, find.text('Upper B'));
    // Last 3 completed only.
    expect(find.text('Lower A'), findsOneWidget);
    expect(find.text('Lower B'), findsNothing);
    expect(find.text('Full Body 1'), findsNothing);
    expect(find.byType(WorkoutListCard), findsWidgets);
  });

  testWidgets('See all / See progress switch tabs', (tester) async {
    await pumpHome(tester, routines: 0);
    await scrollTo(tester, find.byKey(const Key('home_upcoming_see_all')));
    await tester.tap(find.byKey(const Key('home_upcoming_see_all')));
    await scrollTo(tester, find.byKey(const Key('home_see_progress')));
    await tester.tap(find.byKey(const Key('home_see_progress')));
    await tester.pump();
    expect(appBloc.events, [const AppTabChanged(1), const AppTabChanged(3)]);
  });

  testWidgets('empty state: no upcoming or routines, recent hint',
      (tester) async {
    await pumpHome(tester, workouts: const [], routines: 0, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('Routines'), findsNothing);
    await scrollTo(tester, find.byKey(const Key('home_recent_empty')));
    await scrollTo(tester, find.byKey(const Key('home_tools')));
  });
}
