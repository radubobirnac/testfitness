import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/widgets/animated_feedback.dart';

void main() {
  late BuildContext ctx;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
  }

  testWidgets('success pill auto-dismisses after 2 s', (tester) async {
    await pumpApp(tester);
    AnimatedFeedback.showSuccess(ctx, 'Workout copied');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Workout copied'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Workout copied'), findsNothing);
  });

  testWidgets('tap dismisses immediately', (tester) async {
    await pumpApp(tester);
    AnimatedFeedback.showError(ctx, 'Could not save');
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('Could not save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save'), findsNothing);
    // The pending auto-dismiss timer must not fail after a manual dismiss.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('one pill at a time; repeats within 2 s are dropped',
      (tester) async {
    await pumpApp(tester);
    AnimatedFeedback.showSuccess(ctx, 'First');
    AnimatedFeedback.showSuccess(ctx, 'Second');
    AnimatedFeedback.showSuccess(ctx, 'Second');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
