import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/screens/workouts_screen.dart';

void main() {
  const longName =
      'Extremely Long Upper Body Hypertrophy Workout With Supersets And Drop Sets';

  Future<void> pumpCard(
    WidgetTester tester, {
    VoidCallback? onRepeat,
    VoidCallback? onDelete,
    VoidCallback? onToggleComplete,
    bool completed = false,
    bool overdue = false,
    bool showDescription = true,
    List<WorkoutSet> sets = const [],
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: ListView(
            children: [
              WorkoutListCard(
                workout: Workout(
                  id: 'w1',
                  name: longName,
                  description: 'Some description',
                  isCompleted: completed,
                  sets: sets,
                ),
                exerciseCount: 12,
                displayDate: DateTime(2026, 11, 4),
                showDescription: showDescription,
                isOverdue: overdue,
                weightUnitLabel: 'kg',
                onTap: () {},
                onToggleComplete: onToggleComplete ?? () {},
                onRepeat: onRepeat ?? () {},
                onDelete: onDelete ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  String metaOf(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('workout_card_meta')))
      .textSpan!
      .toPlainText();

  testWidgets('long name at 360dp lays out without overflow', (tester) async {
    await pumpCard(tester);
    expect(tester.takeException(), isNull);

    final title = tester.widget<Text>(find.text(longName));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);

    // Leading status toggle | title | overflow menu, no overlap.
    final titleRect = tester.getRect(find.text(longName));
    final menuRect = tester.getRect(find.byTooltip('More actions'));
    final completeRect = tester.getRect(find.byTooltip('Mark as complete'));
    expect(completeRect.right, lessThanOrEqualTo(titleRect.left));
    expect(titleRect.right, lessThanOrEqualTo(menuRect.left));

    // Both controls meet the 48dp minimum.
    expect(completeRect.width, greaterThanOrEqualTo(48));
    expect(completeRect.height, greaterThanOrEqualTo(48));
    expect(menuRect.width, greaterThanOrEqualTo(48));
    expect(menuRect.height, greaterThanOrEqualTo(48));
  });

  testWidgets('compact height and meta line', (tester) async {
    await pumpCard(tester, showDescription: false);
    expect(metaOf(tester), '12 exercises · 0 sets');
    expect(find.text('Wed, Nov 4'), findsOneWidget);
    final card = tester.getSize(find.byType(Card));
    expect(card.height, inInclusiveRange(64, 80));

    await pumpCard(tester);
    final withDescription = tester.getSize(find.byType(Card));
    expect(withDescription.height, lessThanOrEqualTo(96));
    final description = tester.widget<Text>(find.text('Some description'));
    expect(description.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed card shows unit-aware volume, dark mode',
      (tester) async {
    await pumpCard(
      tester,
      completed: true,
      brightness: Brightness.dark,
      sets: const [
        WorkoutSet(
            id: 's1', exerciseId: 'a', reps: 10, weight: 100, isCompleted: true),
        WorkoutSet(
            id: 's2', exerciseId: 'a', reps: 5, weight: 40, isWarmup: true,
            isCompleted: true),
        WorkoutSet(id: 's3', exerciseId: 'b', reps: 8, weight: 50),
      ],
    );
    expect(metaOf(tester), '12 exercises · 3 sets · 1,000 kg');
    expect(find.byTooltip('Mark as incomplete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overdue card shows an error-coloured label', (tester) async {
    await pumpCard(tester, overdue: true);
    expect(metaOf(tester), startsWith('Overdue · '));
    final context = tester.element(find.byType(WorkoutListCard));
    final error = Theme.of(context).colorScheme.error;
    final icon = tester.widget<Icon>(find.descendant(
        of: find.byTooltip('Mark as complete'), matching: find.byType(Icon)));
    expect(icon.color, error);
  });

  testWidgets('complete toggle invokes callback', (tester) async {
    var toggled = 0;
    await pumpCard(tester, onToggleComplete: () => toggled++);
    await tester.tap(find.byTooltip('Mark as complete'));
    expect(toggled, 1);
  });

  testWidgets('overflow menu shows Repeat and Delete', (tester) async {
    var repeated = 0;
    await pumpCard(tester, onRepeat: () => repeated++);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    expect(repeated, 1);
  });

  testWidgets('Save as routine is disabled for a workout without sets',
      (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<Object?>>(find.ancestor(
      of: find.text('Save as routine'),
      matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
    ));
    expect(item.enabled, isFalse);
  });

  testWidgets('delete requires confirmation', (tester) async {
    var deleted = 0;
    await pumpCard(tester, onDelete: () => deleted++);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Workout'), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });
}
