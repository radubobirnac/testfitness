import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/screens/settings/voice_settings_screen.dart';
import 'package:testfitness/screens/settings/workout_suggestions_screen.dart';
import 'package:testfitness/services/user_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    UserPreferencesService().resetForTesting();
    // flutter_tts has no platform implementation in tests; answer its calls.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
            (call) async => call.method == 'getVoices' ? <Object>[] : 1);
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: brightness),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: page,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('WorkoutSuggestionsScreen', () {
    for (final brightness in Brightness.values) {
      testWidgets('controls fit at 360dp, $brightness, text x1.3',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        await pumpPage(tester, const WorkoutSuggestionsScreen(),
            brightness: brightness, textScale: 1.3);

        expect(find.byKey(const ValueKey('workout-body-parts-slider')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('workout-duration-slider')),
            findsOneWidget);
        expect(
            find.byKey(const ValueKey('workout-exclude-core')), findsOneWidget);
        expect(find.byKey(const ValueKey('workout-focus-balanced')),
            findsOneWidget);
        for (final part in UserPreferencesService.workoutBodyParts) {
          expect(find.byKey(ValueKey('workout-body-part-$part')),
              findsOneWidget);
        }
        expect(find.byKey(const ValueKey('workout-suggestions-reset')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('changes persist and reset restores defaults', (tester) async {
      SharedPreferences.setMockInitialValues({
        'workout_preferences_v1': '{"workoutFocus":"upper"}',
      });
      await pumpPage(tester, const WorkoutSuggestionsScreen());
      expect(find.text('Upper Body Priority'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('workout-body-part-Legs')));
      await tester.pump(const Duration(milliseconds: 200));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('workout_preferences_v1'), contains('"Legs"'));

      await tester
          .ensureVisible(find.byKey(const ValueKey('workout-suggestions-reset')));
      await tester.tap(find.byKey(const ValueKey('workout-suggestions-reset')));
      await tester.pump(const Duration(milliseconds: 200));
      final stored = prefs.getString('workout_preferences_v1')!;
      expect(stored, contains('"workoutFocus":"balanced"'));
      expect(stored, contains('"preferredBodyParts":[]'));
      expect(find.text('Balanced'), findsOneWidget);
    });
  });

  group('VoiceSettingsScreen', () {
    // Runs first: EnhancedTTSService is a singleton whose initialize()
    // future, once created inside one test's fake-async zone, never
    // completes for later tests, so the controls would stay disabled.
    testWidgets('motivational phrases switch persists, reset restores',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPage(tester, const VoiceSettingsScreen());

      await tester.tap(find.byKey(const ValueKey('tts-motivational-switch')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tts_use_motivational_phrases'), isTrue);

      await tester.tap(find.byKey(const ValueKey('voice-settings-reset')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(prefs.getBool('tts_use_motivational_phrases'), isFalse);
      expect(prefs.getDouble('tts_speech_rate'), kDefaultSpeechRate);
      expect(prefs.getDouble('tts_pitch'), kDefaultSpeechPitch);
    });

    for (final brightness in Brightness.values) {
      testWidgets('controls fit at 360dp, $brightness, text x1.3',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        await pumpPage(tester, const VoiceSettingsScreen(),
            brightness: brightness, textScale: 1.3);

        expect(find.byKey(const ValueKey('tts-rate-slider')), findsOneWidget);
        expect(find.byKey(const ValueKey('tts-pitch-slider')), findsOneWidget);
        expect(find.byKey(const ValueKey('tts-motivational-switch')),
            findsOneWidget);
        expect(find.text('Select Voice'), findsOneWidget);
        for (final label in ['Test Voice', 'Boxing', 'Timer', 'Stop All']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.byKey(const ValueKey('voice-settings-reset')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

  });
}
