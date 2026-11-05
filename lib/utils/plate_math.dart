/// Pure plate-loading math for the plate calculator.
///
/// All arithmetic is done in integer hundredths of a unit so values like
/// 102.5 kg or 1.25 kg plates never suffer floating-point drift.
library;

/// Result of loading a bar for a target weight.
class PlateLoad {
  /// The weight the user asked for.
  final double target;

  /// Weight of the empty bar.
  final double barWeight;

  /// Plates to put on EACH side, largest first.
  final List<double> platesPerSide;

  /// Total weight actually achieved (bar + both sides).
  final double achievedTotal;

  /// How far below the target the achieved total is (0 when exact).
  final double remainder;

  const PlateLoad({
    required this.target,
    required this.barWeight,
    required this.platesPerSide,
    required this.achievedTotal,
    required this.remainder,
  });

  /// Target is lighter than the empty bar.
  bool get isBelowBar => _toHundredths(target) < _toHundredths(barWeight);

  /// Target equals the bar weight exactly: no plates needed.
  bool get isBarOnly => _toHundredths(target) == _toHundredths(barWeight);

  /// Target was reached exactly.
  bool get isExact => !isBelowBar && _toHundredths(remainder) == 0;

  /// "45 + 25 + 10" (empty string when no plates).
  String get perSideLabel => platesPerSide.map(formatPlateWeight).join(' + ');

  /// Short status line for the UI, or null when the load is exact and
  /// needs plates. [unit] is the display unit label, e.g. "kg" or "lb".
  String? note(String unit) {
    if (isBelowBar) return 'Below bar weight';
    if (isBarOnly) return 'Just the bar';
    if (!isExact) {
      return 'Closest: ${formatPlateWeight(achievedTotal)} $unit — '
          '${formatPlateWeight(remainder)} $unit short';
    }
    return null;
  }
}

/// Computes the plates per side for [target] on a bar of [barWeight], given
/// the plate sizes in [availablePlates] (unlimited pairs of each).
///
/// Loads greedily, largest plate first. If greedy can't hit the target
/// exactly (possible with unusual plate sets, e.g. only 20s and 15s), a
/// small exhaustive search finds the closest achievable load that does not
/// exceed the target, preferring fewer plates.
PlateLoad calculatePlates({
  required double target,
  required double barWeight,
  required List<double> availablePlates,
}) {
  final targetH = _toHundredths(target);
  final barH = _toHundredths(barWeight);

  if (targetH <= barH) {
    return PlateLoad(
      target: target,
      barWeight: barWeight,
      platesPerSide: const [],
      achievedTotal: barWeight,
      remainder: 0,
    );
  }

  final plates = availablePlates
      .map(_toHundredths)
      .where((p) => p > 0)
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  // Odd hundredths can't be split evenly between sides; floor per side.
  final perSideH = (targetH - barH) ~/ 2;

  var chosen = _greedy(perSideH, plates);
  if (_sum(chosen) != perSideH) {
    final better = _closest(perSideH, plates);
    if (better != null && _sum(better) > _sum(chosen)) chosen = better;
  }

  final achievedH = barH + 2 * _sum(chosen);
  return PlateLoad(
    target: target,
    barWeight: barWeight,
    platesPerSide: chosen.map(_fromHundredths).toList(),
    achievedTotal: _fromHundredths(achievedH),
    remainder: _fromHundredths(targetH - achievedH),
  );
}

/// Formats a weight without trailing zeros: 45, 2.5, 1.25, 182.5.
String formatPlateWeight(double weight) {
  final h = _toHundredths(weight);
  if (h % 100 == 0) return (h ~/ 100).toString();
  var s = (h / 100).toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

int _toHundredths(double v) => (v * 100).round();
double _fromHundredths(int h) => h / 100;
int _sum(List<int> xs) => xs.fold(0, (a, b) => a + b);

List<int> _greedy(int perSide, List<int> platesDesc) {
  final result = <int>[];
  var remaining = perSide;
  for (final p in platesDesc) {
    while (p <= remaining) {
      result.add(p);
      remaining -= p;
    }
  }
  return result;
}

/// Unbounded "closest sum ≤ perSide, fewest plates" search, scaled down by
/// the GCD of the plate sizes. Returns null if the search space is too big.
List<int>? _closest(int perSide, List<int> platesDesc) {
  if (platesDesc.isEmpty) return const [];
  var g = platesDesc.first;
  for (final p in platesDesc) {
    g = _gcd(g, p);
  }
  final n = perSide ~/ g;
  if (n > 200000) return null;
  final units = platesDesc.map((p) => p ~/ g).toList();

  const inf = 1 << 30;
  final count = List<int>.filled(n + 1, inf);
  final via = List<int>.filled(n + 1, -1);
  count[0] = 0;
  for (var s = 1; s <= n; s++) {
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      if (u <= s && count[s - u] + 1 < count[s]) {
        count[s] = count[s - u] + 1;
        via[s] = i;
      }
    }
  }
  var best = n;
  while (best > 0 && count[best] == inf) {
    best--;
  }
  final result = <int>[];
  for (var s = best; s > 0; s -= units[via[s]]) {
    result.add(platesDesc[via[s]]);
  }
  result.sort((a, b) => b.compareTo(a));
  return result;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
