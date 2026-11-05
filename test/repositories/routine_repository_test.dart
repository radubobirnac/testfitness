import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/repositories/routine_repository.dart';

Routine _routine(String id, String name, {DateTime? createdAt}) => Routine(
      id: id,
      name: name,
      exercises: const [RoutineExercise(exerciseId: 'bench', sets: 3)],
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('empty by default', () async {
    expect(await RoutineRepository().getRoutines(), isEmpty);
  });

  test('save, update, delete', () async {
    final repo = RoutineRepository();
    await repo.saveRoutine(_routine('a', 'Push'));
    await repo.saveRoutine(_routine('b', 'Pull', createdAt: DateTime(2026, 2)));

    var routines = await repo.getRoutines();
    expect(routines.map((r) => r.name), ['Pull', 'Push']);

    await repo.saveRoutine(_routine('a', 'Push Day'));
    routines = await repo.getRoutines();
    expect(routines.length, 2);
    expect(routines.firstWhere((r) => r.id == 'a').name, 'Push Day');

    await repo.deleteRoutine('b');
    routines = await repo.getRoutines();
    expect(routines.map((r) => r.id), ['a']);
  });

  test('markUsed sets lastUsedAt and moves routine first', () async {
    final repo = RoutineRepository();
    await repo.saveRoutine(_routine('a', 'Push'));
    await repo.saveRoutine(_routine('b', 'Pull', createdAt: DateTime(2026, 2)));

    await repo.markUsed('a');
    final routines = await repo.getRoutines();
    expect(routines.first.id, 'a');
    expect(routines.first.lastUsedAt, isNotNull);
    expect(routines.last.lastUsedAt, isNull);
  });

  test('persists under routines_v1 and tolerates corrupt data', () async {
    await RoutineRepository().saveRoutine(_routine('a', 'Push'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('routines_v1'), contains('Push'));

    await prefs.setString('routines_v1', 'not json');
    expect(await RoutineRepository().getRoutines(), isEmpty);
  });
}
