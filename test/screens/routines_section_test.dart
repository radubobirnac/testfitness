import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/routines_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  testWidgets('empty Routines section shows hint', (tester) async {
    await pump(tester, const RoutinesSection(workouts: []));
    expect(find.text('Routines'), findsOneWidget);
    expect(find.text('Save a workout as a routine from its ⋮ menu'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists routines and reloads after a save', (tester) async {
    await pump(tester, const RoutinesSection(workouts: []));

    await tester.runAsync(() => RoutineRepository().saveRoutine(Routine(
          id: 'r1',
          name: 'Push Day',
          exercises: const [
            RoutineExercise(exerciseId: 'bench', sets: 3),
            RoutineExercise(exerciseId: 'ohp', sets: 3),
          ],
          createdAt: DateTime(2026, 1, 1),
        )));
    await tester.pumpAndSettle();

    expect(find.text('Push Day'), findsOneWidget);
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
