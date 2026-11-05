import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/widgets/weekly_check_in_card.dart';

void main() {
  const bench = Exercise(id: 'bench', name: 'Bench Press', muscleGroup: 'Chest');
  final exercisesById = {bench.id: bench};

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );

  testWidgets('shows friendly empty state when there is no data',
      (tester) async {
    await tester.pumpWidget(wrap(WeeklyCheckInCard(
      checkIn: null,
      exercisesById: exercisesById,
      weightUnitLabel: 'Lbs',
    )));

    expect(find.text('Weekly check-in'), findsOneWidget);
    expect(find.byKey(const ValueKey('weekly_check_in_empty')), findsOneWidget);
  });

  testWidgets('renders stats, change, streak, records, groups and plateaus',
      (tester) async {
    final topSet = WorkoutSet(
      id: 's1',
      exerciseId: 'bench',
      reps: 5,
      weight: 205,
      isCompleted: true,
      completedAt: DateTime(2026, 11, 3),
    );
    final checkIn = WeeklyCheckIn(
      weekStart: DateTime(2026, 11, 2),
      workoutsThisWeek: 3,
      setsThisWeek: 42,
      volumeThisWeek: 11000,
      volumeLastWeek: 10000,
      setsPerMuscleGroup: const {'chest': 12, 'back': 9},
      neglectedMuscleGroups: const ['hamstrings', 'back'],
      recordsThisWeek: [
        PersonalRecord(
          exerciseId: 'bench',
          type: RecordType.heaviestWeight,
          value: 205,
          previous: 200,
          set: topSet,
        ),
      ],
      streakWeeks: 3,
      plateaus: [
        ExerciseTrend(
          exerciseId: 'bench',
          points: [MapEntry(DateTime(2026, 10, 1), 230)],
          changePercent: 0.5,
          plateau: true,
        ),
      ],
    );

    await tester.pumpWidget(wrap(WeeklyCheckInCard(
      checkIn: checkIn,
      exercisesById: exercisesById,
      weightUnitLabel: 'Lbs',
    )));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('11,000 lbs'), findsOneWidget);
    expect(find.text('↑ 10% vs last week'), findsOneWidget);
    expect(find.text('3-week streak'), findsOneWidget);
    expect(find.textContaining('heaviest 205 lbs', findRichText: true),
        findsOneWidget);
    expect(find.text('Chest · 12'), findsOneWidget);
    expect(find.text('Not trained in 7+ days: Hamstrings, Back'),
        findsOneWidget);
    expect(
        find.text('Bench Press has stalled for 3 sessions — try a lighter week'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
