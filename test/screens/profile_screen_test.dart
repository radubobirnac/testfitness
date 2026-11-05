import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/screens/profile_screen.dart';
import 'package:testfitness/services/user_preferences_service.dart';

void main() {
  setUp(() => UserPreferencesService().resetForTesting());

  Future<AppBloc> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bloc = AppBloc()..add(const AppInitialize());
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const ProfileScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    return bloc;
  }

  testWidgets('opening settings keeps a stored kg choice', (tester) async {
    SharedPreferences.setMockInitialValues({'use_metric_units': true});
    await pumpProfile(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('use_metric_units'), isTrue);
    expect(prefs.containsKey('rest_timer_duration'), isFalse);
    expect(find.text('Kilograms (kg)'), findsOneWidget);
    expect(find.byKey(const ValueKey('weight-unit-note')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('smart rest switch reveals the global slider', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpProfile(tester);

    // Smart rest now lives in the Rest timer sheet.
    expect(find.text('Smart · by exercise type'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-rest-timer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Smart rest by exercise type'), findsOneWidget);
    expect(find.byKey(const ValueKey('global-rest-slider')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('smart-rest-switch')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Rest for every exercise'), findsOneWidget);
    expect(find.byKey(const ValueKey('global-rest-slider')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('smart_rest_enabled'), isFalse);
  });

  testWidgets('workout suggestions show stored focus and save without profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_preferences_v1':
          '{"workoutFocus":"strength","excludeCore":false}',
    });
    await pumpProfile(tester);

    expect(find.text('Workout suggestions'), findsWidgets);
    expect(find.text('Strength Focus · 2 body parts · 45 min'), findsOneWidget);

    // The controls live on the Workout suggestions subpage.
    await tester.tap(find.byKey(const ValueKey('settings-workout-suggestions')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Strength Focus'), findsOneWidget);
    expect(find.text('Enthusiasm Level: 3/5'), findsNothing);
    expect(find.text('Voice Emphasis'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('workout-exclude-core')));
    await tester.pump(const Duration(milliseconds: 200));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('workout_preferences_v1'),
        contains('"excludeCore":true'));
  });
}
