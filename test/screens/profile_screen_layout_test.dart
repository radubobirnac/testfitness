import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/screens/app_loader.dart' show userThemeOverride;
import 'package:testfitness/screens/profile_screen.dart';
import 'package:testfitness/services/user_preferences_service.dart';

Future<PackageInfo> _fakeVersion() async => PackageInfo(
      appName: 'StrengthWave',
      packageName: 'com.example.testfitness',
      version: '1.2.3',
      buildNumber: '7',
    );

final _profileJson = jsonEncode({
  'id': 'u1',
  'name': 'Radu',
  'age': 35,
  'gender': 'male',
  'fitnessLevel': 'intermediate',
  'createdDate': DateTime(2026, 1, 1).toIso8601String(),
  'lastUpdated': DateTime(2026, 1, 1).toIso8601String(),
  'preferences': <String, dynamic>{},
});

void main() {
  setUp(() {
    UserPreferencesService().resetForTesting();
    userThemeOverride.value = false;
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    double height = 3000,
  }) async {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bloc = AppBloc()..add(const AppInitialize());
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: const ProfileScreen(versionLoader: _fakeVersion),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('grouped settings at 360dp, $brightness, text x$scale',
          (tester) async {
        SharedPreferences.setMockInitialValues({'user_profile': _profileJson});
        await pumpProfile(tester, brightness: brightness, textScale: scale);

        for (final header in [
          'Training',
          'Workout suggestions',
          'Voice & speech',
          'Appearance',
          'AI',
          'Developer', // tests run in debug mode
          'About',
        ]) {
          expect(find.text(header), findsWidgets, reason: header);
        }
        for (final key in [
          'profile-header',
          'profile-edit',
          'weight-unit-switch',
          'settings-rest-timer',
          'settings-bar-plates',
          'timer-sound-switch',
          'settings-workout-suggestions',
          'settings-voice',
          'theme-segmented',
          'settings-gemini-key',
          'settings-ai-chat',
          'settings-developer',
          'settings-version',
        ]) {
          expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
        }
        expect(find.text('Radu'), findsOneWidget);
        expect(find.text('Age 35 · Male · Max HR 185'), findsOneWidget);
        expect(find.text('StrengthWave 1.2.3 (build 7)'), findsOneWidget);
        expect(find.text('Not set'), findsOneWidget);
        expect(find.textContaining('Reset to Default'), findsNothing);

        // Rows are at least 48dp tall.
        for (final key in ['settings-rest-timer', 'settings-voice']) {
          expect(tester.getSize(find.byKey(ValueKey(key))).height,
              greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('no profile shows a "Set up profile" row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpProfile(tester);

    expect(find.byKey(const ValueKey('profile-set-up')), findsOneWidget);
    expect(find.text('Set up profile'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-header')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-set-up')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create Profile'), findsOneWidget);
  });

  testWidgets('theme segments map to System / Light / Dark', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpProfile(tester);

    expect(find.text("Following your device's light/dark setting"),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(userThemeOverride.value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), isTrue);
    expect(find.text('Always dark'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(prefs.getBool('dark_mode'), isFalse);
    expect(find.text('Always light'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('use-device-theme')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(userThemeOverride.value, isFalse);
    expect(prefs.containsKey('dark_mode'), isFalse);
  });

  testWidgets('weight unit and timer sound switches persist', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey('weight-unit-switch')));
    await tester.tap(find.byKey(const ValueKey('timer-sound-switch')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('use_metric_units'), isTrue);
    expect(prefs.getBool('play_sound_on_timer_end'), isFalse);
    expect(find.text('Kilograms (kg)'), findsOneWidget);
  });
}
