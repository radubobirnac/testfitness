import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/data/default_exercises.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/utils/muscle_map.dart';

void main() {
  final library = buildDefaultExercises();
  Exercise byName(String name) => library.firstWhere((e) => e.name == name);
  MuscleProfile of(String name) => MuscleMap.of(byName(name));
  MuscleProfile custom(String name, {String? group}) => MuscleMap.of(
      Exercise(id: 'c-$name', name: name, muscleGroup: group, isCustom: true));

  group('curated table', () {
    test('every built-in exercise has a curated entry with a primary muscle',
        () {
      expect(library, isNotEmpty);
      for (final e in library) {
        expect(MuscleMap.curated(e.name), isNotNull,
            reason: '"${e.name}" is missing from the curated MuscleMap table');
        expect(MuscleMap.of(e).primary, isNotEmpty,
            reason: '"${e.name}" has no primary muscle');
      }
    });

    test('no stale curated entries', () {
      final names = library.map((e) => e.name.toLowerCase()).toSet();
      for (final key in MuscleMap.curatedNames) {
        expect(names, contains(key), reason: 'stale entry "$key"');
      }
      expect(MuscleMap.curatedNames.length, names.length);
    });

    test('lookup is case-insensitive', () {
      expect(MuscleMap.curated('BENCH PRESS'), isNotNull);
      expect(custom('  bench press ').primary, {Muscle.chest});
    });
  });

  group('spot checks', () {
    test('bench press', () {
      final p = of('Bench Press');
      expect(p.primary, {Muscle.chest});
      expect(p.secondary, containsAll([Muscle.triceps, Muscle.shoulders]));
      expect(p.compound, isTrue);
      expect(p.hits(Muscle.triceps), isTrue);
      expect(p.primarily(Muscle.triceps), isFalse);
    });

    test('close-grip bench press', () {
      final p = of('Close-Grip Bench Press');
      expect(p.primary, {Muscle.chest, Muscle.triceps});
      expect(p.secondary, contains(Muscle.shoulders));
    });

    test('barbell row and pull-up are back with biceps secondary', () {
      for (final name in ['Barbell Row', 'Pull-up', 'Lat Pulldown']) {
        final p = of(name);
        expect(p.primary, {Muscle.back}, reason: name);
        expect(p.secondary, contains(Muscle.biceps), reason: name);
        expect(p.compound, isTrue, reason: name);
      }
    });

    test('curls are biceps isolation, pushdown is triceps', () {
      expect(of('Barbell Curl').primary, {Muscle.biceps});
      expect(of('Barbell Curl').secondary, contains(Muscle.forearms));
      expect(of('Barbell Curl').compound, isFalse);
      expect(of('Triceps Pushdown').primary, {Muscle.triceps});
      expect(of('Reverse Grip Barbell Curl').primary, {Muscle.forearms});
    });

    test('dip is triceps primary with chest secondary', () {
      expect(of('Dip').primary, {Muscle.triceps});
      expect(of('Dip').secondary, contains(Muscle.chest));
    });

    test('squat, deadlift, RDL, calf raise, plank', () {
      expect(of('Squat').primary, {Muscle.quads, Muscle.glutes});
      expect(
          of('Squat').secondary, containsAll([Muscle.hamstrings, Muscle.core]));
      expect(of('Deadlift').primary,
          {Muscle.hamstrings, Muscle.glutes, Muscle.back});
      expect(of('Romanian Deadlift').primary.first, Muscle.hamstrings);
      expect(of('Romanian Deadlift').primary, contains(Muscle.glutes));
      expect(of('Barbell Calf Raise').primary, {Muscle.calves});
      expect(of('Plank').primary, {Muscle.core});
      expect(of('Treadmill').primary, {Muscle.cardio});
    });

    test('labels', () {
      expect(Muscle.biceps.label, 'Biceps');
      expect(Muscle.hamstrings.label, 'Hamstrings');
      for (final m in Muscle.values) {
        expect(m.label, isNotEmpty);
      }
    });
  });

  group('heuristics for custom names', () {
    test('arms', () {
      expect(custom('Incline Dumbbell Curl').primary, {Muscle.biceps});
      expect(custom('Spider Curls').primary, {Muscle.biceps});
      expect(custom('Rope Pushdown').primary, {Muscle.triceps});
      expect(custom('Overhead Tricep Extension').primary, {Muscle.triceps});
      expect(custom('EZ Skull Crusher').primary, {Muscle.triceps});
      expect(custom('Weighted Dips').primary, {Muscle.triceps});
    });

    test('legs', () {
      expect(custom('Bulgarian Split Squat').primary,
          {Muscle.quads, Muscle.glutes});
      expect(custom('Walking Lunges').primary, contains(Muscle.quads));
      expect(custom('Lying Leg Curl').primary, {Muscle.hamstrings});
      expect(custom('Nordic Curl').primary, {Muscle.hamstrings});
      expect(custom('DB RDL').primary.first, Muscle.hamstrings);
      expect(custom('Glute Bridge').primary, {Muscle.glutes});
      expect(custom('Cable Glute Kickback').primary, {Muscle.glutes});
      expect(custom('Single-Leg Calf Raise').primary, {Muscle.calves});
    });

    test('upper body', () {
      expect(custom('Seated Cable Row').primary, {Muscle.back});
      expect(custom('Neutral Grip Pulldown').primary, {Muscle.back});
      expect(custom('Weighted Chin-ups').primary, {Muscle.back});
      expect(custom('Arnold Press').primary, {Muscle.shoulders});
      expect(custom('Cable Lateral Raise').primary, {Muscle.shoulders});
      expect(custom('Rear Delt Fly').primary, {Muscle.shoulders});
      expect(custom('Incline Dumbbell Bench').primary, {Muscle.chest});
      expect(custom('Low-to-High Cable Flye').primary, {Muscle.chest});
    });

    test('core and cardio', () {
      expect(custom('Hanging Knee Raise').primary, {Muscle.core});
      expect(custom('Decline Sit-up').primary, {Muscle.core});
      expect(custom('Pallof Press').primary, {Muscle.core});
      expect(custom('Mountain Climbers').primary, {Muscle.core});
      expect(custom('Assault Bike Sprints').primary, {Muscle.cardio});
    });
  });

  group('coarse fallback', () {
    test('uses muscleGroup when the name says nothing', () {
      expect(custom('Mystery Move', group: 'Arms').primary,
          {Muscle.biceps, Muscle.triceps});
      expect(custom('Thing', group: 'Legs').primary,
          {Muscle.quads, Muscle.hamstrings, Muscle.glutes});
      expect(custom('Thing', group: 'Chest, Back').primary,
          {Muscle.chest, Muscle.back});
      expect(custom('Thing', group: 'Shoulder').primary, {Muscle.shoulders});
    });

    test('unknown everything gives an empty profile', () {
      expect(custom('Mystery Move').primary, isEmpty);
      expect(custom('Mystery Move', group: 'Neck').primary, isEmpty);
    });
  });
}
