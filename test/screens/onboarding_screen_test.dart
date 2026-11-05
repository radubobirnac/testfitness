import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/screens/onboarding_screen.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/services/user_profile_service.dart';

void main() {
  group('decideOnboarding', () {
    test('new user with no workouts -> show', () {
      expect(
          decideOnboarding(hasCompletedOnboarding: false, workoutCount: 0),
          OnboardingDecision.show);
    });

    test('existing workouts -> skip and mark done', () {
      expect(
          decideOnboarding(hasCompletedOnboarding: false, workoutCount: 12),
          OnboardingDecision.skipAndMarkDone);
    });

    test('already completed -> skip', () {
      expect(decideOnboarding(hasCompletedOnboarding: true, workoutCount: 0),
          OnboardingDecision.skip);
      expect(decideOnboarding(hasCompletedOnboarding: true, workoutCount: 5),
          OnboardingDecision.skip);
    });
  });

  group('shouldShowOnboarding', () {
    test('new user is shown setup and not marked done', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await shouldShowOnboarding(countWorkouts: () async => 0), isTrue);
      expect(await UserProfileService().hasCompletedOnboarding(), isFalse);
    });

    test('existing user is skipped and marked done', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await shouldShowOnboarding(countWorkouts: () async => 3), isFalse);
      expect(await UserProfileService().hasCompletedOnboarding(), isTrue);
    });

    test('completed user is skipped without counting workouts', () async {
      SharedPreferences.setMockInitialValues(
          {'has_completed_onboarding': true});
      var counted = false;
      expect(
          await shouldShowOnboarding(countWorkouts: () async {
            counted = true;
            return 0;
          }),
          isFalse);
      expect(counted, isFalse);
    });

    test('a failing workout count skips setup', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
          await shouldShowOnboarding(
              countWorkouts: () async => throw Exception('db')),
          isFalse);
    });
  });

  testWidgets('steps, unit + experience preferences and finishing',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool? finishedWithWorkout;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: OnboardingScreen(
        onFinished: (_, startWorkout) => finishedWithWorkout = startWorkout,
      ),
    ));
    await tester.pumpAndSettle();

    // Step 1: units.
    expect(find.text('Welcome to StrengthWave'), findsOneWidget);
    await tester.tap(find.text('Kilograms (kg)'));
    await tester.pumpAndSettle();
    expect(UserPreferencesService().getUseMetricUnits(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('use_metric_units'), isTrue);

    // Step 2: experience; beginners get a tip.
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Your experience'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-beginner-tip')), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('onboarding-experience-beginner')));
    await tester.pumpAndSettle();
    expect(UserPreferencesService().getExperienceLevel(),
        ExperienceLevel.beginner);
    expect(
        find.byKey(const ValueKey('onboarding-beginner-tip')), findsOneWidget);

    // Back returns to step 1 and keeps the unit choice.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to StrengthWave'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    // Step 3: start first workout.
    expect(find.text('Start your first workout'), findsOneWidget);
    expect(find.text('Explore first'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-start-workout')));
    await tester.pumpAndSettle();
    expect(finishedWithWorkout, isTrue);
    expect(await UserProfileService().hasCompletedOnboarding(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip marks setup complete and explores', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool? finishedWithWorkout;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        onFinished: (_, startWorkout) => finishedWithWorkout = startWorkout,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(finishedWithWorkout, isFalse);
    expect(await UserProfileService().hasCompletedOnboarding(), isTrue);
  });
}
