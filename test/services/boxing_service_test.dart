import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/services/boxing_service.dart';

class _FakeAudio implements BoxingAudio {
  int stopCalls = 0;
  final List<String> called = [];

  @override
  Future<void> playCountdown() async {}

  @override
  Future<void> announceRoundStart(int roundNumber) async {}

  @override
  Future<void> callCombination(String combination) async {
    called.add(combination);
  }

  @override
  Future<void> stopAll() async {
    stopCalls++;
  }
}

void main() {
  // testWidgets runs in a fake-async zone: timers and the binding clock only
  // advance when we pump, so timing is deterministic.
  group('BoxingService pause/resume', () {
    late _FakeAudio audio;
    late BoxingService service;
    late List<String> events;
    late List<String> combos;

    Future<void> start(WidgetTester tester,
        {int round = 10, int rest = 5, int rounds = 2}) async {
      audio = _FakeAudio();
      service = BoxingService.test(
          audio: audio, now: () => tester.binding.clock.now());
      events = [];
      combos = [];
      await service.startBoxingSession(
        style: 'traditional',
        difficulty: 'beginner',
        roundDurationSeconds: round,
        restDurationSeconds: rest,
        totalRounds: rounds,
        combinationIntervalSeconds: 2,
        onCombinationCall: combos.add,
        onRoundStart: (r) => events.add('start$r'),
        onRoundComplete: (r) => events.add('complete$r'),
        onRestStart: (s) => events.add('rest$s'),
        onSessionComplete: () => events.add('done'),
      );
    }

    testWidgets('pause freezes the round clock and resume continues from it',
        (tester) async {
      await start(tester);
      expect(service.phase, BoxingPhase.round);
      expect(events, ['start1']);

      await tester.pump(const Duration(seconds: 4));
      expect(combos.length, 2);
      service.pauseSession();
      expect(service.isPaused, isTrue);
      expect(service.phaseRemaining, const Duration(seconds: 6));

      // A long pause: nothing fires, no time is lost.
      await tester.pump(const Duration(seconds: 60));
      expect(events, ['start1']);
      expect(combos.length, 2);
      expect(service.phaseRemaining, const Duration(seconds: 6));

      service.resumeSession();
      await tester.pump(const Duration(seconds: 5));
      expect(events, ['start1']);
      await tester.pump(const Duration(seconds: 1));
      expect(events, ['start1', 'complete1', 'rest5']);
      expect(service.phase, BoxingPhase.rest);
      // 2 before pause + 2 after (at +2s, +4s); the round ends at +6s first.
      expect(combos.length, 4);

      service.stopSession();
    });

    testWidgets('pause during rest freezes rest, round number advances at start',
        (tester) async {
      await start(tester);
      await tester.pump(const Duration(seconds: 10)); // round 1 done
      await tester.pump(const Duration(seconds: 2)); // 3s of rest left
      service.pauseSession();
      await tester.pump(const Duration(seconds: 30));
      expect(service.phase, BoxingPhase.rest);
      expect(service.currentRound, 1);

      service.resumeSession();
      await tester.pump(const Duration(seconds: 3));
      expect(service.phase, BoxingPhase.round);
      expect(service.currentRound, 2);
      expect(events, ['start1', 'complete1', 'rest5', 'start2']);

      await tester.pump(const Duration(seconds: 10));
      expect(events.last, 'done');
      expect(service.phase, BoxingPhase.complete);
    });

    testWidgets('repeated pause/resume never leaves orphaned timers',
        (tester) async {
      await start(tester);
      for (var i = 0; i < 3; i++) {
        service.resumeSession(); // no-op when not paused
        service.pauseSession();
        service.pauseSession(); // no-op when already paused
        service.resumeSession();
      }
      await tester.pump(const Duration(seconds: 2));
      expect(combos.length, 1, reason: 'only one combination timer runs');

      service.stopSession();
      final callsAtStop = combos.length;
      await tester.pump(const Duration(minutes: 5));
      expect(combos.length, callsAtStop);
      expect(events, ['start1']);
      expect(service.phase, BoxingPhase.idle);
      expect(audio.stopCalls, greaterThan(0));
    });

    testWidgets('stop then dispose cancels everything', (tester) async {
      await start(tester);
      service.pauseSession();
      service.dispose();
      service.resumeSession(); // must not restart anything after dispose
      await tester.pump(const Duration(minutes: 5));
      expect(events, ['start1']);
      expect(combos, isEmpty);
    });
  });
}
