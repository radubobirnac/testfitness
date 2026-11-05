import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/app/app_state.dart';

Future<AppState> _settle(AppBloc bloc, bool Function(AppState) until) =>
    bloc.stream.firstWhere(until).timeout(const Duration(seconds: 2));

void main() {
  test('AppInitialize loads stored settings and never overwrites them',
      () async {
    SharedPreferences.setMockInitialValues({
      'use_metric_units': true,
      'rest_timer_duration': 120,
      'play_sound_on_timer_end': false,
    });
    final bloc = AppBloc();
    addTearDown(bloc.close);

    bloc.add(const AppInitialize());
    final state = await _settle(bloc, (s) => s.isInitialized);
    expect(state.preferences['use_metric_units'], isTrue);
    expect(state.preferences['rest_timer_duration'], 120);
    expect(state.preferences['play_sound_on_timer_end'], isFalse);

    // What the settings screen does on open: reload, read-only.
    bloc.add(const AppPreferencesReloaded());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('use_metric_units'), isTrue);
    expect(prefs.getInt('rest_timer_duration'), 120);
    expect(prefs.getBool('play_sound_on_timer_end'), isFalse);
    expect(bloc.state.preferences['use_metric_units'], isTrue);
  });

  test('missing settings fall back to defaults without being written',
      () async {
    SharedPreferences.setMockInitialValues({});
    final bloc = AppBloc();
    addTearDown(bloc.close);

    bloc.add(const AppInitialize());
    final state = await _settle(bloc, (s) => s.isInitialized);
    expect(state.preferences['use_metric_units'], isFalse);
    expect(state.preferences['rest_timer_duration'], 90);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('use_metric_units'), isFalse);
    expect(prefs.containsKey('rest_timer_duration'), isFalse);
    expect(prefs.containsKey('play_sound_on_timer_end'), isFalse);
  });

  test('reload picks up a unit chosen after init (e.g. onboarding)', () async {
    SharedPreferences.setMockInitialValues({});
    final bloc = AppBloc();
    addTearDown(bloc.close);
    bloc.add(const AppInitialize());
    await _settle(bloc, (s) => s.isInitialized);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_metric_units', true);

    bloc.add(const AppPreferencesReloaded());
    final state =
        await _settle(bloc, (s) => s.preferences['use_metric_units'] == true);
    expect(state.preferences['use_metric_units'], isTrue);
    expect(prefs.getBool('use_metric_units'), isTrue);
  });

  test('updating one setting leaves the others untouched', () async {
    SharedPreferences.setMockInitialValues({'use_metric_units': true});
    final bloc = AppBloc();
    addTearDown(bloc.close);
    bloc.add(const AppInitialize());
    await _settle(bloc, (s) => s.isInitialized);

    bloc.add(const AppPreferencesUpdated({'rest_timer_duration': 150}));
    await _settle(bloc, (s) => s.preferences['rest_timer_duration'] == 150);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rest_timer_duration'), 150);
    expect(prefs.getBool('use_metric_units'), isTrue);
  });
}
