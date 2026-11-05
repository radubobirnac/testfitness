import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/services/user_preferences_service.dart';

void main() {
  group('workout preferences', () {
    test('defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final service =
          UserPreferencesService.withPrefs(await SharedPreferences.getInstance());
      expect(service.getWorkoutPreferences(), {
        'defaultBodyParts': 2,
        'defaultDurationMinutes': 45,
        'excludeCore': false,
        'workoutFocus': 'balanced',
        'preferredBodyParts': <String>[],
      });
    });

    test('set and read back, without a user profile', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = UserPreferencesService.withPrefs(prefs);
      await service.setWorkoutPreference('defaultBodyParts', 3);
      await service.setWorkoutPreference('defaultDurationMinutes', 60);
      await service.setWorkoutPreference('excludeCore', true);
      await service.setWorkoutPreference('workoutFocus', 'strength');
      await service
          .setWorkoutPreference('preferredBodyParts', ['Chest', 'Legs']);

      final reloaded = UserPreferencesService.withPrefs(prefs);
      expect(reloaded.getWorkoutPreferences(), {
        'defaultBodyParts': 3,
        'defaultDurationMinutes': 60,
        'excludeCore': true,
        'workoutFocus': 'strength',
        'preferredBodyParts': ['Chest', 'Legs'],
      });
    });

    test('invalid values are normalised', () async {
      SharedPreferences.setMockInitialValues({});
      final service =
          UserPreferencesService.withPrefs(await SharedPreferences.getInstance());
      await service.setWorkoutPreference('defaultBodyParts', 4);
      await service.setWorkoutPreference('workoutFocus', 'nonsense');
      await service
          .setWorkoutPreference('preferredBodyParts', ['Chest', 'Tail']);
      final p = service.getWorkoutPreferences();
      expect(p['defaultBodyParts'], 3);
      expect(p['workoutFocus'], 'balanced');
      expect(p['preferredBodyParts'], ['Chest']);
    });

    test('migrates once from user_profile.preferences', () async {
      SharedPreferences.setMockInitialValues({
        'user_profile': jsonEncode({
          'name': 'A',
          'preferences': {
            'defaultBodyParts': 1,
            'workoutFocus': 'endurance',
            'excludeCore': true,
            'preferredBodyParts': ['Back'],
          },
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = UserPreferencesService.withPrefs(prefs);
      await service.migrateWorkoutPreferencesFromProfile();
      final p = service.getWorkoutPreferences();
      expect(p['defaultBodyParts'], 1);
      expect(p['workoutFocus'], 'endurance');
      expect(p['excludeCore'], isTrue);
      expect(p['preferredBodyParts'], ['Back']);
      expect(p['defaultDurationMinutes'], 45);

      // Later changes are not overwritten by a second migration.
      await service.setWorkoutPreference('workoutFocus', 'strength');
      await service.migrateWorkoutPreferencesFromProfile();
      expect(service.getWorkoutPreferences()['workoutFocus'], 'strength');
    });
  });

  test('smart rest defaults to on and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = UserPreferencesService.withPrefs(prefs);
    expect(service.getSmartRestEnabled(), isTrue);
    await service.setSmartRestEnabled(false);
    expect(UserPreferencesService.withPrefs(prefs).getSmartRestEnabled(),
        isFalse);
  });
}
