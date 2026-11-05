import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/utils/plate_math.dart';

const kgPlates = <double>[25, 20, 15, 10, 5, 2.5, 1.25];
const lbPlates = <double>[45, 35, 25, 10, 5, 2.5];

void main() {
  group('calculatePlates (lb)', () {
    test('exact load, largest first', () {
      final r = calculatePlates(
          target: 205, barWeight: 45, availablePlates: lbPlates);
      expect(r.platesPerSide, [45, 35]);
      expect(r.achievedTotal, 205);
      expect(r.isExact, isTrue);
      expect(r.note('lb'), isNull);
      expect(r.perSideLabel, '45 + 35');
    });

    test('225 lb is two 45s per side', () {
      final r = calculatePlates(
          target: 225, barWeight: 45, availablePlates: lbPlates);
      expect(r.platesPerSide, [45, 45]);
    });

    test('closest with remainder', () {
      // 71.25 per side; no 1.25 lb plates -> 45 + 25 + 1.25 impossible.
      final r = calculatePlates(
          target: 187.5, barWeight: 45, availablePlates: lbPlates);
      expect(r.platesPerSide, [45, 25]);
      expect(r.achievedTotal, 185);
      expect(r.remainder, 2.5);
      expect(r.isExact, isFalse);
      expect(r.note('lb'), 'Closest: 185 lb — 2.5 lb short');
    });

    test('missing plate sizes (no 45s)', () {
      final r = calculatePlates(
          target: 135, barWeight: 45, availablePlates: [35, 25, 10, 5]);
      expect(r.platesPerSide, [35, 10]);
      expect(r.isExact, isTrue);
    });

    test('finds exact load when greedy alone would miss', () {
      // 40 per side with only 25s and 20s: greedy 25 (15 short), best 20+20.
      final r = calculatePlates(
          target: 125, barWeight: 45, availablePlates: [25, 20]);
      expect(r.platesPerSide, [20, 20]);
      expect(r.isExact, isTrue);
    });

    test('no plates available', () {
      final r =
          calculatePlates(target: 95, barWeight: 45, availablePlates: []);
      expect(r.platesPerSide, isEmpty);
      expect(r.achievedTotal, 45);
      expect(r.remainder, 50);
      expect(r.note('lb'), 'Closest: 45 lb — 50 lb short');
    });
  });

  group('calculatePlates (kg)', () {
    test('exact', () {
      final r = calculatePlates(
          target: 100, barWeight: 20, availablePlates: kgPlates);
      expect(r.platesPerSide, [25, 15]);
      expect(r.isExact, isTrue);
    });

    test('102.5 kg has no float drift', () {
      final r = calculatePlates(
          target: 102.5, barWeight: 20, availablePlates: kgPlates);
      expect(r.platesPerSide, [25, 15, 1.25]);
      expect(r.achievedTotal, 102.5);
      expect(r.remainder, 0);
      expect(r.isExact, isTrue);
    });

    test('float-noisy target (0.1 + 0.2 style)', () {
      final r = calculatePlates(
          target: 20 + 0.1 + 0.2 + 2.2,
          barWeight: 20,
          availablePlates: kgPlates);
      expect(r.platesPerSide, [1.25]);
      expect(r.isExact, isTrue);
    });

    test('closest when 1.25s are missing', () {
      final r = calculatePlates(
          target: 62.5, barWeight: 20, availablePlates: [25, 20, 10, 5, 2.5]);
      expect(r.platesPerSide, [20]);
      expect(r.achievedTotal, 60);
      expect(r.remainder, 2.5);
      expect(r.note('kg'), 'Closest: 60 kg — 2.5 kg short');
    });

    test('odd hundredths cannot be split evenly', () {
      final r = calculatePlates(
          target: 20.03, barWeight: 20, availablePlates: kgPlates);
      expect(r.platesPerSide, isEmpty);
      expect(r.remainder, closeTo(0.03, 1e-9));
      expect(r.isExact, isFalse);
    });
  });

  group('bar edge cases', () {
    test('just the bar', () {
      final r = calculatePlates(
          target: 20, barWeight: 20, availablePlates: kgPlates);
      expect(r.platesPerSide, isEmpty);
      expect(r.isBarOnly, isTrue);
      expect(r.isBelowBar, isFalse);
      expect(r.note('kg'), 'Just the bar');
    });

    test('below bar weight', () {
      final r = calculatePlates(
          target: 30, barWeight: 45, availablePlates: lbPlates);
      expect(r.platesPerSide, isEmpty);
      expect(r.isBelowBar, isTrue);
      expect(r.isExact, isFalse);
      expect(r.achievedTotal, 45);
      expect(r.note('lb'), 'Below bar weight');
    });
  });

  test('formatPlateWeight', () {
    expect(formatPlateWeight(45), '45');
    expect(formatPlateWeight(2.5), '2.5');
    expect(formatPlateWeight(1.25), '1.25');
    expect(formatPlateWeight(182.5), '182.5');
    expect(formatPlateWeight(0.1 + 0.2), '0.3');
  });
}
