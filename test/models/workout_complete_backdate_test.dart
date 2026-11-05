import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';

void main() {
  final planned = Workout(
    id: 'w1',
    name: 'Push Day',
    scheduledDate: DateTime(2026, 5, 12, 7, 30),
    sets: [
      WorkoutSet(id: 's1', exerciseId: 'bench', reps: 8, weight: 80),
      WorkoutSet(
        id: 's2',
        exerciseId: 'bench',
        reps: 8,
        weight: 80,
        isCompleted: true,
        completedAt: DateTime(2026, 5, 12, 8),
      ),
    ],
  );

  test('plannedCompletionTime is midday on the scheduled day', () {
    expect(planned.plannedCompletionTime, DateTime(2026, 5, 12, 12));
  });

  test('complete(at:, markSetsDone:) backdates workout and open sets', () {
    final done =
        planned.complete(at: planned.plannedCompletionTime, markSetsDone: true);

    expect(done.isCompleted, isTrue);
    expect(done.completedDate, DateTime(2026, 5, 12, 12));
    // Previously open set is now done on the planned day.
    expect(done.sets[0].isCompleted, isTrue);
    expect(done.sets[0].completedAt, DateTime(2026, 5, 12, 12));
    // Already-completed set keeps its own time.
    expect(done.sets[1].completedAt, DateTime(2026, 5, 12, 8));
    // Logged weights/reps are untouched.
    expect(done.sets.map((s) => s.weight), [80, 80]);
  });

  test('plain complete() still uses now and leaves sets alone', () {
    final before = DateTime.now();
    final done = planned.complete();
    expect(done.completedDate!.isBefore(before), isFalse);
    expect(done.sets[0].isCompleted, isFalse);
  });
}
