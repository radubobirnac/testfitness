import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/workouts_screen.dart';

import 'workouts_screen_layout_test.dart' as base;

void main() {
  late base.FakeWorkoutBloc bloc;

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    bloc = base.FakeWorkoutBloc(base.sampleWorkouts);
    addTearDown(bloc.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<WorkoutBloc>.value(
        value: bloc,
        child: WorkoutsScreen(
          isAiAvailable: () => false,
          routineRepository: RoutineRepository(),
          clock: () => base.now,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Planned header offers to mark all overdue done on their day',
      (tester) async {
    await pump(tester);

    // sampleWorkouts has one overdue planned workout (p2, Nov 1).
    final action = find.byKey(const Key('mark_overdue_done'));
    expect(action, findsOneWidget);
    expect(find.text('Mark overdue done'), findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Mark 1 overdue workout as done?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_mark_overdue_done')));
    await tester.pumpAndSettle();

    final sent =
        bloc.events.whereType<WorkoutsCompleteOnPlannedDayRequested>().single;
    expect(sent.workoutIds, ['p2']);
  });

  testWidgets('cancelling the bulk dialog sends nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('mark_overdue_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(bloc.events.whereType<WorkoutsCompleteOnPlannedDayRequested>(),
        isEmpty);
  });

  testWidgets('ticking an overdue workout asks when it was done',
      (tester) async {
    await pump(tester);

    final overdueCard = find.byKey(const ValueKey('workout_card_p2'));
    await tester.tap(find.descendant(
        of: overdueCard, matching: find.byTooltip('Mark as complete')));
    await tester.pumpAndSettle();

    expect(find.text('When did you do it?'), findsOneWidget);
    expect(find.text('On its planned day (Sun, Nov 1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('done_on_planned_day')));
    await tester.pumpAndSettle();
    expect(
        bloc.events
            .whereType<WorkoutsCompleteOnPlannedDayRequested>()
            .single
            .workoutIds,
        ['p2']);
  });

  testWidgets('"Today" completes it now', (tester) async {
    await pump(tester);
    final overdueCard = find.byKey(const ValueKey('workout_card_p2'));
    await tester.tap(find.descendant(
        of: overdueCard, matching: find.byTooltip('Mark as complete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('done_today')));
    await tester.pumpAndSettle();
    expect(bloc.events.whereType<WorkoutCompleteRequested>().single.workoutId,
        'p2');
  });

  testWidgets('non-overdue planned workout completes without asking',
      (tester) async {
    await pump(tester);
    final card = find.byKey(const ValueKey('workout_card_p1'));
    await tester.tap(find.descendant(
        of: card, matching: find.byTooltip('Mark as complete')));
    await tester.pumpAndSettle();
    expect(find.text('When did you do it?'), findsNothing);
    expect(bloc.events.whereType<WorkoutCompleteRequested>().single.workoutId,
        'p1');
  });
}
