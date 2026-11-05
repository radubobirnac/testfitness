import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';

/// Shown after the user finishes a workout: headline stats, the best set per
/// exercise and any new personal records set in this session.
///
/// All inputs are passed in (no bloc / preference lookups) so the screen can
/// be rendered in widget tests with fake data.
class WorkoutSummaryScreen extends StatefulWidget {
  /// The finished workout (isCompleted / completedDate already set).
  final Workout workout;

  /// Every workout known to the app, used to detect new records. The finished
  /// workout itself may or may not be included; the coach excludes it.
  final List<Workout> allWorkouts;

  /// Display names by exercise id.
  final Map<String, String> exerciseNames;

  final bool useMetric;

  /// When the workout was started, if tracked. Otherwise the first completed
  /// set's time is used as the start.
  final DateTime? startedAt;

  const WorkoutSummaryScreen({
    super.key,
    required this.workout,
    required this.allWorkouts,
    required this.exerciseNames,
    required this.useMetric,
    this.startedAt,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _ExerciseBest {
  final String exerciseId;
  final WorkoutSet set;
  final int setCount;

  /// Average RPE of the rated working sets, null when none was rated.
  final double? averageRpe;

  const _ExerciseBest(this.exerciseId, this.set, this.setCount,
      [this.averageRpe]);
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  late final List<WorkoutSet> _doneSets;
  late final List<_ExerciseBest> _bests;
  late final List<PersonalRecord> _records;
  late final Duration? _duration;

  String get _unit => widget.useMetric ? 'kg' : 'lb';

  @override
  void initState() {
    super.initState();
    final workout = widget.workout;
    // Completed working sets: warm-ups don't count towards totals, best
    // sets or records.
    _doneSets = workout.sets.where(ProgressionCoach.isCountable).toList();

    // Best set per exercise (highest estimated 1RM, then heaviest), in the
    // order exercises appear in the workout.
    final order = <String>[];
    final best = <String, WorkoutSet>{};
    final counts = <String, int>{};
    for (final set in _doneSets) {
      if (!best.containsKey(set.exerciseId)) order.add(set.exerciseId);
      counts[set.exerciseId] = (counts[set.exerciseId] ?? 0) + 1;
      final current = best[set.exerciseId];
      if (current == null || _isBetter(set, current)) {
        best[set.exerciseId] = set;
      }
    }
    _bests = [
      for (final id in order)
        _ExerciseBest(
          id,
          best[id]!,
          counts[id]!,
          ProgressionCoach.averageRpe(
              _doneSets.where((s) => s.exerciseId == id)),
        ),
    ];

    List<PersonalRecord> records;
    try {
      // Only celebrate beating a previous best: first-time "records" (no
      // earlier session for the exercise) are not shown.
      records = ProgressionCoach(useMetric: widget.useMetric)
          .recordsIn(workout, widget.allWorkouts)
          .where((record) => record.previous != null)
          .toList();
    } catch (_) {
      records = const [];
    }
    _records = records;

    final end = workout.completedDate ?? DateTime.now();
    DateTime? start = widget.startedAt;
    if (start == null) {
      // Warm-ups still mark when the session started.
      for (final set in workout.sets.where((s) => s.isCompleted)) {
        final at = set.completedAt;
        if (at != null && (start == null || at.isBefore(start))) start = at;
      }
    }
    _duration =
        (start != null && !end.isBefore(start)) ? end.difference(start) : null;

    if (_records.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.mediumImpact();
      });
    }
  }

  static bool _isBetter(WorkoutSet a, WorkoutSet b) {
    final ea = ProgressionCoach.estimate1RM(a.weight, a.reps);
    final eb = ProgressionCoach.estimate1RM(b.weight, b.reps);
    if (ea != eb) return ea > eb;
    if (a.weight != b.weight) return a.weight > b.weight;
    return a.reps > b.reps;
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return NumberFormat.decimalPattern().format(value.round());
    }
    return NumberFormat('#,##0.#').format(value);
  }

  String _formatSet(WorkoutSet set) {
    if (set.weight <= 0) return '×${set.reps}';
    return '${_formatNumber(set.weight)} $_unit × ${set.reps}';
  }

  /// " · avg RPE 8.5" (one decimal at most), or '' when not rated.
  static String _formatAverageRpe(double? rpe) {
    if (rpe == null) return '';
    final rounded = (rpe * 10).round() / 10;
    return ' · avg RPE ${ProgressionCoach.formatNumber(rounded)}';
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '<1 min';
  }

  String _exerciseName(String id) => widget.exerciseNames[id] ?? 'Exercise';

  String _recordLabel(PersonalRecord record) {
    switch (record.type) {
      case RecordType.bestE1rm:
        return 'Best est. 1RM';
      case RecordType.heaviestWeight:
        return 'Heaviest weight';
      case RecordType.mostVolume:
        return 'Most volume';
    }
  }

  void _done() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final workout = widget.workout;
    final date = workout.completedDate ?? workout.scheduledDate;

    final totalReps = _doneSets.fold<int>(0, (sum, s) => sum + s.reps);
    final volume =
        _doneSets.fold<double>(0, (sum, s) => sum + s.weight * s.reps);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Workout complete'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Name, date, duration
            Text(
              workout.name,
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (date != null)
                  _MetaItem(
                    icon: Icons.event,
                    text: DateFormat.yMMMEd().format(date),
                  ),
                _MetaItem(
                  icon: Icons.timer_outlined,
                  text: _duration != null ? _formatDuration(_duration) : '—',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Totals
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Sets',
                    value: '${_doneSets.length}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(label: 'Reps', value: '$totalReps'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Volume ($_unit)',
                    value: _formatNumber(volume),
                  ),
                ),
              ],
            ),

            // New records
            if (_records.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                key: const ValueKey('summary-records'),
                elevation: 0,
                color: colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.emoji_events,
                              color: colorScheme.onTertiaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _records.length == 1
                                  ? 'New record!'
                                  : '${_records.length} new records!',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final record in _records)
                        _RecordRow(
                          title: _exerciseName(record.exerciseId),
                          label: _recordLabel(record),
                          value: '${_formatNumber(record.value)} $_unit',
                          previous: 'was ${_formatNumber(record.previous!)}',
                          color: colorScheme.onTertiaryContainer,
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // Best set per exercise
            const SizedBox(height: 24),
            Text('Best sets', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_bests.isEmpty)
              Text(
                'No completed sets.',
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              )
            else
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                child: Column(
                  children: [
                    for (var i = 0; i < _bests.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: colorScheme.outlineVariant),
                      ListTile(
                        title: Text(
                          _exerciseName(_bests[i].exerciseId),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_bests[i].setCount} '
                          '${_bests[i].setCount == 1 ? 'set' : 'sets'}'
                          '${_formatAverageRpe(_bests[i].averageRpe)}',
                        ),
                        trailing: Text(
                          _formatSet(_bests[i].set),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _done,
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: textTheme.labelMedium
                  ?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final String title;
  final String label;
  final String value;
  final String previous;
  final Color color;

  const _RecordRow({
    required this.title,
    required this.label,
    required this.value,
    required this.previous,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(label, style: textTheme.bodySmall?.copyWith(color: color)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(previous,
                  style: textTheme.bodySmall?.copyWith(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
