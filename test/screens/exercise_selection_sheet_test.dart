import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/screens/exercise_selection_sheet.dart';

class _FakeExerciseRepository implements ExerciseRepository {
  _FakeExerciseRepository(this.exercises);

  final List<Exercise> exercises;

  @override
  Future<List<Exercise>> getExercises() async => exercises;

  @override
  Future<List<String>> getCategories() async => ['Any Category'];

  @override
  Future<List<String>> getBodyParts() async => ['Any Body Part'];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const squat = Exercise(id: 'squat', name: 'Squat');
  const bench = Exercise(id: 'bench', name: 'Bench Press');
  const row = Exercise(id: 'row', name: 'Barbell Row');
  final repo = _FakeExerciseRepository(const [squat, bench, row]);

  Future<void> pumpOpener(
    WidgetTester tester,
    Widget sheet,
    void Function(Object?) onResult,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showModalBottomSheet<Object>(
                context: context,
                isScrollControlled: true,
                builder: (_) => sheet,
              );
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('multi-select returns picked exercises in selection order',
      (tester) async {
    Object? result;
    await pumpOpener(
      tester,
      ExerciseSelectionSheet(multiSelect: true, repository: repo),
      (r) => result = r,
    );

    final addButton = find.byKey(const ValueKey('exercise-pick-add'));
    expect(tester.widget<ButtonStyleButton>(addButton).onPressed, isNull);

    await tester.tap(find.text('Barbell Row'));
    await tester.pump();
    await tester.tap(find.text('Squat'));
    await tester.pump();

    expect(find.text('Add 2 exercises'), findsOneWidget);

    // Selection survives a search filter change.
    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pump();
    expect(find.text('Squat'), findsNothing);
    expect(find.text('Add 2 exercises'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    await tester.tap(find.text('Add 2 exercises'));
    await tester.pumpAndSettle();

    expect(result, isA<List<Exercise>>());
    expect((result as List<Exercise>).map((e) => e.id), ['row', 'squat']);
  });

  testWidgets('already-added exercises are checked and disabled',
      (tester) async {
    await pumpOpener(
      tester,
      ExerciseSelectionSheet(
        multiSelect: true,
        excludedExerciseIds: const {'bench'},
        repository: repo,
      ),
      (_) {},
    );

    await tester.tap(find.text('Bench Press'));
    await tester.pump();
    expect(find.text('Add 0 exercises'), findsOneWidget);
    expect(find.text('Already in workout'), findsOneWidget);
  });

  testWidgets('single-select pops with the tapped exercise', (tester) async {
    Object? result;
    await pumpOpener(
      tester,
      ExerciseSelectionSheet(repository: repo),
      (r) => result = r,
    );

    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    expect(result, same(squat));
  });
}
