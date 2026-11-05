import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/services/rest_preferences_service.dart';

Exercise _ex(String id, String name, String? category) =>
    Exercise(id: id, name: name, category: category);

void main() {
  group('RestPreferencesService defaults', () {
    int rest(String name, String? category) =>
        RestPreferencesService.defaultRestSecondsFor(_ex('x', name, category));

    test('heavy barbell compounds rest 150 s', () {
      expect(rest('Squat', 'Barbell'), 150);
      expect(rest('Barbell Squat', null), 150);
      expect(rest('Deadlift', 'Barbell'), 150);
      expect(rest('Bench Press', 'Barbell'), 150);
      expect(rest('Overhead Press', 'Barbell'), 150);
    });

    test('other barbell / dumbbell compounds rest 120 s', () {
      expect(rest('Barbell Row', 'Barbell'), 120);
      expect(rest('Dumbbell Press', 'Dumbbell'), 120);
    });

    test('machine / cable rest 90 s', () {
      expect(rest('Leg Press', 'Machine'), 90);
      expect(rest('Lat Pulldown', 'Machine'), 90);
      expect(rest('Cable Row', 'Cable'), 90);
    });

    test('isolation lifts rest 60 s', () {
      expect(rest('Barbell Curl', 'Barbell'), 60);
      expect(rest('Dumbbell Curl', 'Dumbbell'), 60);
      expect(rest('Lateral Raise', 'Dumbbell'), 60);
      expect(rest('Triceps Pushdown', 'Cable'), 60);
      expect(rest('Leg Extension', 'Machine'), 60);
      expect(rest('Barbell Shrug', 'Barbell'), 60);
    });

    test('format', () {
      expect(RestPreferencesService.format(150), '2:30');
      expect(RestPreferencesService.format(60), '1:00');
      expect(RestPreferencesService.format(45), '0:45');
    });
  });

  group('RestPreferencesService overrides', () {
    final squat = _ex('squat', 'Squat', 'Barbell');
    final curl = _ex('curl', 'Dumbbell Curl', 'Dumbbell');

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('override, persist and reset to default', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = RestPreferencesService.withPrefs(prefs);
      expect(service.restSecondsFor(squat), 150);
      expect(service.restSecondsFor(curl), 60);

      await service.setRestSeconds('squat', 180);
      expect(service.restSecondsFor(squat), 180);
      expect(service.overrideFor('squat'), 180);
      expect(service.restSecondsFor(curl), 60);

      // A fresh instance reads the persisted override.
      final reloaded = RestPreferencesService.withPrefs(prefs);
      expect(reloaded.restSecondsFor(squat), 180);

      await reloaded.setRestSeconds('squat', null);
      expect(reloaded.restSecondsFor(squat), 150);
      expect(reloaded.overrideFor('squat'), isNull);
      expect(RestPreferencesService.withPrefs(prefs).restSecondsFor(squat),
          150);
    });

    test('malformed stored data falls back to defaults', () async {
      SharedPreferences.setMockInitialValues(
          {RestPreferencesService.storageKey: 'not json'});
      final prefs = await SharedPreferences.getInstance();
      final service = RestPreferencesService.withPrefs(prefs);
      expect(service.restSecondsFor(squat), 150);
    });
  });
}
