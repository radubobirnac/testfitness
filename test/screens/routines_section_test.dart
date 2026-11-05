import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/routines_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final pushDay = Routine(
    id: 'r1',
    name: 'Push Day',
    exercises: const [
      RoutineExercise(exerciseId: 'bench', sets: 3),
      RoutineExercise(exerciseId: 'ohp', sets: 3),
    ],
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(body: Column(children: [child])),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Routines strip renders nothing without routines',
      (tester) async {
    await pump(tester, const RoutinesStrip(workouts: []));
    expect(find.text('Routines'), findsNothing);
    expect(find.text('Manage'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('strip lists compact routine chips and reloads after a save',
      (tester) async {
    await pump(tester, const RoutinesStrip(workouts: []));

    await tester.runAsync(() => RoutineRepository().saveRoutine(pushDay));
    await tester.pumpAndSettle();

    expect(find.text('Routines'), findsOneWidget);
    expect(find.text('Push Day'), findsOneWidget);
    expect(find.text('2 ex'), findsOneWidget);

    final chip = tester.getRect(find.ancestor(
        of: find.text('Push Day'), matching: find.byType(InkWell)));
    expect(chip.height, 56);
    final manage = tester.getRect(find.widgetWithText(TextButton, 'Manage'));
    expect(manage.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press a routine chip offers Rename and Delete',
      (tester) async {
    await tester.runAsync(() => RoutineRepository().saveRoutine(pushDay));
    await pump(tester, const RoutinesStrip(workouts: []));

    await tester.longPress(find.text('Push Day'));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Manage opens the full routine list', (tester) async {
    await tester.runAsync(() => RoutineRepository().saveRoutine(pushDay));
    await pump(tester, const RoutinesStrip(workouts: []));

    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('2 exercises · not used yet'), findsOneWidget);
    final menu = tester.getRect(find.byTooltip('Routine actions'));
    expect(menu.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home quick start is hidden without routines', (tester) async {
    await pump(tester, const RoutineQuickStart(workouts: []));
    expect(find.byType(FilledButton), findsNothing);
  });

  test('describeLastUsed', () {
    final now = DateTime(2026, 11, 5, 12);
    expect(describeLastUsed(null, now: now), 'not used yet');
    expect(describeLastUsed(DateTime(2026, 11, 5, 8), now: now),
        'last used today');
    expect(describeLastUsed(DateTime(2026, 11, 4, 23), now: now),
        'last used yesterday');
    expect(describeLastUsed(DateTime(2026, 11, 2), now: now),
        'last used 3 days ago');
    expect(describeLastUsed(DateTime(2026, 10, 1), now: now),
        'last used Oct 1');
  });
}
