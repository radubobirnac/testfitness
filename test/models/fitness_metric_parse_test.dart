import 'package:flutter_test/flutter_test.dart';
import 'package:testfitness/models/fitness_metric.dart';

void main() {
  group('FitnessMetric.tryFromMap', () {
    test('parses a valid record', () {
      final date = DateTime(2026, 11, 1);
      final metric = FitnessMetric.tryFromMap({
        'id': 'm1',
        'type': MetricType.weight.index,
        'value': 82,
        'date': date.millisecondsSinceEpoch,
        'unit': 'kg',
      });

      expect(metric, isNotNull);
      expect(metric!.value, 82.0);
      expect(metric.date, date);
    });

    test('returns null for a damaged record instead of inventing a 0 value',
        () {
      final metric = FitnessMetric.tryFromMap({
        'id': 'broken',
        'type': 'not-an-index',
        'value': null,
        'date': null,
      });

      expect(metric, isNull);
    });
  });
}
