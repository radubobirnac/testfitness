import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/screens/exercise_history_screen.dart';
import 'package:testfitness/screens/progress_screen.dart';
import 'package:testfitness/ui/progress_period.dart';

/// Records events instead of touching the database.
class _FakeWorkoutBloc extends WorkoutBloc {
  _FakeWorkoutBloc(List<Workout> workouts) {
    emit(WorkoutState(workouts: workouts));
  }

  final List<WorkoutEvent> events = [];

  @override
  void add(WorkoutEvent event) {
    events.add(event);
    if (event is WorkoutLoadRequested) {
      scheduleMicrotask(() {
        if (isClosed) return;
        emit(state.copyWith(isLoading: true));
        emit(state.copyWith(isLoading: false));
      });
    }
  }
}

final now = DateTime(2026, 11, 5, 12); // Thursday

const exercises = [
  Exercise(id: 'bench', name: 'Bench Press', muscleGroup: 'Chest'),
  Exercise(id: 'squat', name: 'Back Squat', muscleGroup: 'Legs'),
  Exercise(id: 'row', name: 'Barbell Row', muscleGroup: 'Back'),
  Exercise(id: 'ohp', name: 'Overhead Press with a Very Long Name',
      muscleGroup: 'Shoulders'),
];

Workout _done(String id, DateTime date, double load) => Workout(
      id: id,
      name: 'Session $id',
      scheduledDate: date,
      completedDate: date,
      isCompleted: true,
      sets: [
        for (final e in exercises)
          for (var s = 0; s < 3; s++)
            WorkoutSet(
              id: '${id}_${e.id}_$s',
              exerciseId: e.id,
              reps: 8,
              weight: load,
              isCompleted: true,
              completedAt: date,
            ),
      ],
    );

/// Two sessions a week for ~14 weeks with slowly rising loads.
final sampleWorkouts = <Workout>[
  for (var w = 0; w < 14; w++) ...[
    _done('a$w', now.subtract(Duration(days: 7 * w + 1)), 200.0 - w * 3),
    _done('b$w', now.subtract(Duration(days: 7 * w + 3)), 190.0 - w * 3),
  ],
];

final bodyWeight = [
  for (var i = 0; i < 6; i++)
    FitnessMetric(
      id: 'bw$i',
      type: MetricType.weight,
      value: 180 - i * 0.5,
      date: now.subtract(Duration(days: 60 - i * 10)),
      unit: 'lbs',
    ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeWorkoutBloc> pumpScreen(
    WidgetTester tester, {
    List<Workout>? workouts,
    List<FitnessMetric>? metrics,
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bloc = _FakeWorkoutBloc(workouts ?? sampleWorkouts);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: BlocProvider<WorkoutBloc>.value(
          value: bloc,
          child: ProgressScreen(
            clock: () => now,
            loadExercises: () async => exercises,
            loadBodyWeight: () async => metrics ?? bodyWeight,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  Finder scrollable() => find.byType(Scrollable).first;

  /// Scrolls through the whole page, failing on any overflow on the way.
  Future<void> expectSectionsWithoutOverflow(WidgetTester tester) async {
    expect(find.text('This week'), findsOneWidget);
    expect(find.byKey(const Key('progress_period')), findsOneWidget);
    for (final target in [
      find.text('Strength'),
      find.byKey(const Key('progress_period_stats')),
      find.byKey(const Key('progress_volume_chart')),
      find.byKey(const Key('progress_frequency_chart')),
      find.byKey(const Key('progress_muscle_balance')),
      find.text('Body'),
      find.byKey(const Key('progress_body_chart')),
      find.text('Top exercises'),
      find.byKey(const Key('progress_top_exercises')),
    ]) {
      await tester.scrollUntilVisible(target, 200, scrollable: scrollable());
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  }

  for (final (name, brightness, scale) in [
    ('light', Brightness.light, 1.0),
    ('dark', Brightness.dark, 1.0),
    ('light, text 1.3', Brightness.light, 1.3),
    ('dark, text 1.3', Brightness.dark, 1.3),
  ]) {
    testWidgets('360dp $name: sections present, no overflow', (tester) async {
      await pumpScreen(tester, brightness: brightness, textScale: scale);
      expect(tester.takeException(), isNull);
      await expectSectionsWithoutOverflow(tester);
    });
  }

  testWidgets('overflow menu holds Export and Import', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Export data'), findsOneWidget);
    expect(find.text('Import data'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);

    await tester.tap(find.text('Export data'));
    await tester.pumpAndSettle();
    expect(find.text('CSV Data'), findsOneWidget);
    expect(find.text('JSON Backup'), findsOneWidget);
    expect(find.text('Progress Report'), findsOneWidget);
    await tester.tapAt(const Offset(180, 40)); // dismiss sheet
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import data'));
    await tester.pumpAndSettle();
    expect(find.text('Import File (JSON/CSV)'), findsOneWidget);
    expect(find.text('Paste JSON Backup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period selector drives the strength captions', (tester) async {
    await pumpScreen(tester);
    final chart = find.byKey(const Key('progress_volume_chart'));
    Finder caption(String text) =>
        find.descendant(of: chart, matching: find.textContaining(text));

    Future<void> select(String label) async {
      await tester.scrollUntilVisible(find.text(label), -300,
          scrollable: scrollable());
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(chart, 300, scrollable: scrollable());
      await tester.pumpAndSettle();
    }

    await tester.scrollUntilVisible(chart, 300, scrollable: scrollable());
    expect(caption('per week, last 3 months'), findsOneWidget);
    await select('4W');
    expect(caption('per week, last 4 weeks'), findsOneWidget);
    await select('1Y');
    expect(caption('per month, last 12 months'), findsOneWidget);
    await select('All');
    expect(caption('all time'), findsOneWidget);

    // The running-total toggle switches the caption.
    await tester.tap(find.byKey(const Key('volume_cumulative_chip')));
    await tester.pumpAndSettle();
    expect(caption('Running total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty data shows one-line guidance per section',
      (tester) async {
    await pumpScreen(tester, workouts: const [], metrics: const []);
    expect(find.byKey(const ValueKey('weekly_check_in_empty')), findsOneWidget);
    expect(find.byKey(const Key('progress_strength_empty')), findsOneWidget);
    for (final key in ['progress_body_empty', 'progress_exercises_empty']) {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 200,
          scrollable: scrollable());
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a top exercise opens its history', (tester) async {
    await pumpScreen(tester);
    final tile = find.byKey(const Key('progress_exercise_squat'));
    await tester.scrollUntilVisible(tile, 200, scrollable: scrollable());
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseHistoryScreen), findsOneWidget);
  });

  group('ProgressMath', () {
    test('windows have the expected bucket counts', () {
      expect(ProgressMath.window(ProgressPeriod.fourWeeks, now).buckets,
          hasLength(4));
      expect(ProgressMath.window(ProgressPeriod.threeMonths, now).buckets,
          hasLength(13));
      expect(ProgressMath.window(ProgressPeriod.oneYear, now).buckets,
          hasLength(12));
      expect(ProgressMath.window(ProgressPeriod.all, now).isEmpty, isTrue);
      expect(
          ProgressMath.window(ProgressPeriod.all, now,
                  earliest: DateTime(2026, 9, 10))
              .buckets
              .map((b) => b.label),
          ["Sep '26", "Oct '26", "Nov '26"]);
    });

    test('totals, buckets and top exercises use completed sets', () {
      final w = ProgressMath.window(ProgressPeriod.fourWeeks, now);
      final t = ProgressMath.totals(sampleWorkouts, w.start, w.end);
      // 4-week window = current week + 3 previous, 2 sessions each.
      expect(t.workouts, 8);
      expect(t.sets, 8 * 12);
      expect(ProgressMath.workoutsPerBucket(sampleWorkouts, w).fold<int>(
          0, (a, b) => a + b), 8);
      final top = ProgressMath.topExercises(sampleWorkouts, w);
      expect(top, hasLength(4));
      expect(top.first.sessions, 8);
      expect(ProgressMath.formatChange(12.4), '↑ 12%');
      expect(ProgressMath.formatChange(-3), '↓ 3%');
    });
  });
}
