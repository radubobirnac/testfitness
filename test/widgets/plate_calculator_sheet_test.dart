import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/widgets/plate_calculator_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'use_metric_units': false});
  });

  Future<void> openSheet(WidgetTester tester, double weight,
      {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal, brightness: brightness),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  showPlateCalculatorSheet(context, weight: weight),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders per-side plates at 360dp without overflow',
      (tester) async {
    await openSheet(tester, 225);
    expect(find.text('225 lb'), findsOneWidget);
    expect(find.text('Bar: 45 lb'), findsOneWidget);
    expect(find.text('Per side: 45 + 45'), findsOneWidget);
    expect(find.byType(PlateBlock), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('heavy, inexact load still fits in dark mode', (tester) async {
    await openSheet(tester, 597.5, brightness: Brightness.dark);
    expect(find.textContaining('Per side'), findsOneWidget);
    expect(find.textContaining('Closest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('+/- adjusts the target by 5 lb', (tester) async {
    await openSheet(tester, 135);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('140 lb'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('130 lb'), findsOneWidget);
    expect(find.textContaining('Per side'), findsOneWidget);
  });

  testWidgets('Bar & plates editor toggles plates and recalculates',
      (tester) async {
    await openSheet(tester, 225);
    await tester.tap(find.text('Bar & plates'));
    await tester.pumpAndSettle();
    // Without 45s: 90 per side -> 35 + 35 + 10 + 10.
    final chip = find.widgetWithText(FilterChip, '45');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('Per side: 35 + 35 + 10 + 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
