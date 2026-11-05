import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/blocs/timer/rest_complete_announcer.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/enhanced_tts_service.dart';
import 'package:testfitness/services/rest_timer_manager.dart';

void main() {
  group('EnhancedTTSService voice parsing', () {
    // Shape of flutter_tts getVoices on Android: List<Object?> of
    // Map<Object?, Object?> (platform-channel data, not Map<String,String>).
    final List<Object?> rawAndroid = <Object?>[
      <Object?, Object?>{'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
      <Object?, Object?>{
        'name': 'en-gb-x-neural-network',
        'locale': 'en-GB',
        'quality': 400,
        'latency': 200,
        'network_required': '1',
      },
      <Object?, Object?>{'name': 'fr-fr-x-abc', 'locale': 'fr-FR'},
      <Object?, Object?>{'locale': 'de-DE'}, // no name -> dropped
      <Object?, Object?>{'name': null, 'locale': 'it-IT'}, // dropped
      'garbage', // not a map -> dropped
      null,
    ];

    test('the old cast approach throws on raw channel data', () {
      final casted = (rawAndroid as List).cast<Map<String, String>>();
      expect(() => casted.first, throwsA(isA<TypeError>()));
    });

    test('parseVoices converts raw maps to string maps', () {
      final voices = EnhancedTTSService.parseVoices(rawAndroid);
      expect(voices, hasLength(3));
      expect(voices, everyElement(isA<Map<String, String>>()));
      expect(voices[1]['quality'], '400');
      expect(voices[1]['network_required'], '1');
    });

    test('parseVoices tolerates null / non-list input', () {
      expect(EnhancedTTSService.parseVoices(null), isEmpty);
      expect(EnhancedTTSService.parseVoices('x'), isEmpty);
    });

    test('rankVoices puts neural/en-US first and is sortable', () {
      final ranked = EnhancedTTSService.rankVoices(
          EnhancedTTSService.parseVoices(rawAndroid));
      expect(ranked.first['name'], 'en-gb-x-neural-network');
      expect(ranked[1]['name'], 'en-us-x-sfg-local');
      expect(ranked.last['name'], 'fr-fr-x-abc');
    });

    test('findVoice returns null instead of throwing', () {
      final voices = EnhancedTTSService.parseVoices(rawAndroid);
      expect(EnhancedTTSService.findVoice(voices, 'fr-fr-x-abc')?['locale'],
          'fr-FR');
      expect(EnhancedTTSService.findVoice(voices, 'missing'), isNull);
      expect(EnhancedTTSService.findVoice(voices, ''), isNull);
      expect(EnhancedTTSService.findVoice(const [], 'x'), isNull);
    });
  });

  group('RestCompleteAnnouncer', () {
    late List<String> spoken;
    setUp(() => spoken = []);

    RestCompleteAnnouncer build({
      required bool phrases,
      required bool sound,
    }) =>
        RestCompleteAnnouncer(
          motivationalPhrasesEnabled: () async => phrases,
          timerSoundEnabled: () => sound,
          speak: (p) async => spoken.add(p),
        );

    test('speaks when Motivational Phrases and Timer Sound are on', () async {
      final ok = await build(phrases: true, sound: true)
          .announce('Go', completedWhileBackgrounded: false);
      expect(ok, isTrue);
      expect(spoken, ['Go']);
    });

    test('silent when Motivational Phrases is off', () async {
      await build(phrases: false, sound: true)
          .announce('Go', completedWhileBackgrounded: false);
      expect(spoken, isEmpty);
    });

    test('silent when Timer Sound is off', () async {
      await build(phrases: true, sound: false)
          .announce('Go', completedWhileBackgrounded: false);
      expect(spoken, isEmpty);
    });

    test('silent when the notification already alerted (background)',
        () async {
      await build(phrases: true, sound: true)
          .announce('Go', completedWhileBackgrounded: true);
      expect(spoken, isEmpty);
    });

    test('speech errors are swallowed', () async {
      final announcer = RestCompleteAnnouncer(
        motivationalPhrasesEnabled: () async => true,
        timerSoundEnabled: () => true,
        speak: (_) async => throw StateError('tts down'),
      );
      expect(
          await announcer.announce('Go', completedWhileBackgrounded: false),
          isFalse);
    });
  });

  test('quickMotivationPhrase is offline and context-aware', () {
    expect(AIService.quickMotivationPhrase('rest_complete', seed: 0),
        "Let's Go! 💪");
    expect(AIService.quickMotivationPhrase('workout_complete', seed: 1),
        'Amazing Job! 🌟');
    expect(AIService.quickMotivationPhrase('unknown', seed: 0),
        "Let's Go! 💪");
  });

  group('RestTimerManager completion notification', () {
    test('sound on uses the shipbell channel', () {
      final d =
          RestTimerManager.completionNotificationDetails(playSound: true);
      expect(d.android!.channelId, RestTimerManager.soundChannelId);
      expect(d.android!.playSound, isTrue);
      expect(d.android!.sound, isA<RawResourceAndroidNotificationSound>());
      expect(d.iOS!.presentSound, isTrue);
      expect(d.iOS!.sound, 'shipbell.wav');
    });

    test('sound off uses a separate silent channel that still vibrates', () {
      final d =
          RestTimerManager.completionNotificationDetails(playSound: false);
      expect(d.android!.channelId, RestTimerManager.silentChannelId);
      expect(d.android!.channelId, isNot(RestTimerManager.soundChannelId));
      expect(d.android!.playSound, isFalse);
      expect(d.android!.sound, isNull);
      expect(d.android!.enableVibration, isTrue);
      expect(d.iOS!.presentSound, isFalse);
      expect(d.iOS!.sound, isNull);
      expect(d.iOS!.presentAlert, isTrue);
    });
  });
}
