import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout.dart';
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
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              WorkoutListCard(
                workout: Workout(
                  id: 'w1',
                  name: longName,
                  description: 'Some description',
                  isCompleted: completed,
                ),
                exerciseCount: 12,
                displayDate: DateTime(2026, 11, 4),
                showDescription: true,
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

  testWidgets('long name at 360dp lays out without overflow', (tester) async {
    await pumpCard(tester);
    expect(tester.takeException(), isNull);

    final title = tester.widget<Text>(find.text(longName));
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.ellipsis);

    // Title does not run underneath the action buttons.
    final titleRect = tester.getRect(find.text(longName));
    final menuRect = tester.getRect(find.byTooltip('More actions'));
    final completeRect = tester.getRect(find.byTooltip('Mark as complete'));
    expect(titleRect.right, lessThanOrEqualTo(completeRect.left));
    expect(completeRect.right, lessThanOrEqualTo(menuRect.left));

    // Both controls meet the 48dp minimum.
    expect(completeRect.width, greaterThanOrEqualTo(48));
    expect(completeRect.height, greaterThanOrEqualTo(48));
    expect(menuRect.width, greaterThanOrEqualTo(48));
    expect(menuRect.height, greaterThanOrEqualTo(48));
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
