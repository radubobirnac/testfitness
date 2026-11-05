import 'package:flutter/material.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/plate_math.dart';

/// Opens the plate calculator for [weight] (in the user's current unit).
/// Reads unit, bar weight and available plates from [UserPreferencesService].
Future<void> showPlateCalculatorSheet(BuildContext context,
    {required double weight}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => PlateCalculatorSheet(initialWeight: weight),
  );
}

/// Body of the plate calculator bottom sheet.
class PlateCalculatorSheet extends StatefulWidget {
  final double initialWeight;

  const PlateCalculatorSheet({super.key, required this.initialWeight});

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  final UserPreferencesService _prefs = UserPreferencesService();
  bool _loaded = false;
  bool _metric = false;
  double _bar = 45;
  List<double> _plates = const [];
  late double _target;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _target = widget.initialWeight < 0 ? 0 : widget.initialWeight;
    _load();
  }

  Future<void> _load() async {
    await _prefs.initialize();
    if (!mounted) return;
    setState(() {
      _metric = _prefs.getUseMetricUnits();
      _bar = _prefs.getBarWeight(metric: _metric);
      _plates = _prefs.getAvailablePlates(metric: _metric);
      _loaded = true;
    });
  }

  String get _unit => _metric ? 'kg' : 'lb';
  double get _step => _metric ? 2.5 : 5.0;

  void _adjust(int direction) {
    setState(() {
      // Snap to the step grid so 101 + 2.5 lands on 102.5, not 103.5.
      // Integer hundredths avoid float drift.
      final targetH = (_target * 100).round();
      final stepH = (_step * 100).round();
      final snappedH = direction > 0
          ? (targetH ~/ stepH + 1) * stepH
          : ((targetH + stepH - 1) ~/ stepH - 1) * stepH;
      _target = snappedH < 0 ? 0 : snappedH / 100;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!_loaded) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final load = calculatePlates(
        target: _target, barWeight: _bar, availablePlates: _plates);
    final note = load.note(_unit);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plate calculator',
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Decrease by ${formatPlateWeight(_step)} $_unit',
                onPressed: _target <= 0 ? null : () => _adjust(-1),
                icon: const Icon(Icons.remove),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${formatPlateWeight(_target)} $_unit',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Increase by ${formatPlateWeight(_step)} $_unit',
                onPressed: () => _adjust(1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bar: ${formatPlateWeight(_bar)} $_unit',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          BarbellView(load: load, availablePlates: _plates),
          const SizedBox(height: 16),
          Text(
            load.platesPerSide.isEmpty
                ? 'Per side: none'
                : 'Per side: ${load.perSideLabel}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: load.isExact || load.isBarOnly
                    ? scheme.onSurfaceVariant
                    : scheme.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => setState(() => _editing = !_editing),
              icon: Icon(_editing ? Icons.expand_less : Icons.tune),
              label: const Text('Bar & plates'),
            ),
          ),
          if (_editing)
            BarAndPlatesEditor(
              metric: _metric,
              onChanged: () => setState(() {
                _bar = _prefs.getBarWeight(metric: _metric);
                _plates = _prefs.getAvailablePlates(metric: _metric);
              }),
            ),
        ],
      ),
    );
  }
}

/// Side-on drawing of a loaded barbell: plates left and right of the bar,
/// heights proportional to plate weight. Scales down to fit narrow screens.
class BarbellView extends StatelessWidget {
  final PlateLoad load;
  final List<double> availablePlates;

  const BarbellView(
      {super.key, required this.load, required this.availablePlates});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plates = load.platesPerSide;
    final maxPlate = [
      ...availablePlates,
      ...plates,
    ].fold<double>(1, (m, p) => p > m ? p : m);

    // Colour by size rank among available plates (largest = primary, ...).
    final sizes = {...availablePlates, ...plates}.toList()
      ..sort((a, b) => b.compareTo(a));
    final palette = <(Color, Color)>[
      (scheme.primary, scheme.onPrimary),
      (scheme.secondary, scheme.onSecondary),
      (scheme.tertiary, scheme.onTertiary),
      (scheme.error, scheme.onError),
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      (scheme.inverseSurface, scheme.onInverseSurface),
    ];

    Widget plateBlock(double w) {
      final rank = sizes.indexOf(w);
      final (bg, fg) = palette[(rank < 0 ? 0 : rank) % palette.length];
      return PlateBlock(
          weight: w,
          height: 36 + 84 * (w / maxPlate),
          color: bg,
          labelColor: fg,
          borderColor: scheme.outline);
    }

    final sleeve = Container(
      width: 16,
      height: 10,
      color: scheme.outline,
    );
    final collar = Container(width: 6, height: 22, color: scheme.outline);
    final shaft = Container(
      width: 72,
      height: 8,
      color: scheme.onSurfaceVariant,
    );

    return Semantics(
      label: plates.isEmpty
          ? 'Empty bar'
          : 'Each side: ${load.perSideLabel}',
      child: SizedBox(
        height: 124,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              sleeve,
              // Left side: smallest plate outermost.
              ...plates.reversed.map(plateBlock),
              collar,
              shaft,
              collar,
              ...plates.map(plateBlock),
              sleeve,
            ],
          ),
        ),
      ),
    );
  }
}

/// One plate in [BarbellView], labelled with its weight.
class PlateBlock extends StatelessWidget {
  final double weight;
  final double height;
  final Color color;
  final Color labelColor;
  final Color borderColor;

  const PlateBlock({
    super.key,
    required this.weight,
    required this.height,
    required this.color,
    required this.labelColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          formatPlateWeight(weight),
          maxLines: 1,
          style: TextStyle(
              color: labelColor, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Edits bar weight and which plate sizes are available, persisting each
/// change to [UserPreferencesService] immediately. Used by the plate
/// calculator sheet and the profile screen.
class BarAndPlatesEditor extends StatefulWidget {
  final bool metric;
  final VoidCallback? onChanged;

  const BarAndPlatesEditor({super.key, required this.metric, this.onChanged});

  @override
  State<BarAndPlatesEditor> createState() => _BarAndPlatesEditorState();
}

class _BarAndPlatesEditorState extends State<BarAndPlatesEditor> {
  final UserPreferencesService _prefs = UserPreferencesService();
  late double _bar;
  late Set<double> _available;

  List<double> get _barOptions =>
      widget.metric ? const [20, 15, 10, 7] : const [45, 35, 25, 15];

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(BarAndPlatesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metric != widget.metric) _read();
  }

  void _read() {
    _bar = _prefs.getBarWeight(metric: widget.metric);
    _available = _prefs.getAvailablePlates(metric: widget.metric).toSet();
  }

  Future<void> _setBar(double value) async {
    setState(() => _bar = value);
    await _prefs.setBarWeight(value, metric: widget.metric);
    widget.onChanged?.call();
  }

  Future<void> _togglePlate(double plate, bool on) async {
    setState(() => on ? _available.add(plate) : _available.remove(plate));
    await _prefs.setAvailablePlates(_available.toList(), metric: widget.metric);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = widget.metric ? 'kg' : 'lb';
    final barOptions = {..._barOptions, _bar}.toList()
      ..sort((a, b) => b.compareTo(a));
    final plateOptions = {
      ...UserPreferencesService.standardPlates(metric: widget.metric),
      ..._available,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bar weight ($unit)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final b in barOptions)
              ChoiceChip(
                label: Text(formatPlateWeight(b)),
                selected: b == _bar,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => _setBar(b),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Plates available ($unit)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final p in plateOptions)
              FilterChip(
                label: Text(formatPlateWeight(p)),
                selected: _available.contains(p),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (on) => _togglePlate(p, on),
              ),
          ],
        ),
      ],
    );
  }
}
