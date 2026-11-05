import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/services/progression_coach.dart';

/// Coach-driven weekly summary shown at the top of the Progress screen.
///
/// Purely presentational: callers compute the [WeeklyCheckIn] with
/// `ProgressionCoach.weeklyCheckIn` and pass the user's weight unit label.
class WeeklyCheckInCard extends StatelessWidget {
  final WeeklyCheckIn? checkIn;
  final Map<String, Exercise> exercisesById;

  /// Unit label as returned by `UserPreferencesService.getWeightUnitLabel`
  /// ("Kg" / "Lbs"). Displayed in lower case.
  final String weightUnitLabel;

  const WeeklyCheckInCard({
    super.key,
    required this.checkIn,
    required this.exercisesById,
    required this.weightUnitLabel,
  });

  String get _unit => weightUnitLabel.toLowerCase();

  static bool hasData(WeeklyCheckIn? c) {
    if (c == null) return false;
    return c.workoutsThisWeek > 0 ||
        c.volumeLastWeek != null ||
        c.streakWeeks > 0 ||
        c.neglectedMuscleGroups.isNotEmpty ||
        c.plateaus.isNotEmpty ||
        c.recordsThisWeek.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = checkIn;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Weekly check-in',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (c != null && c.streakWeeks > 0)
                  _StreakBadge(weeks: c.streakWeeks),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData(c))
              _buildEmptyState(theme)
            else
              ..._buildContent(context, c!),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Text(
      'Log your first workout and your coach will check in here every week '
      'with your volume, records and what to train next.',
      key: const ValueKey('weekly_check_in_empty'),
      style: theme.textTheme.bodyMedium
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  List<Widget> _buildContent(BuildContext context, WeeklyCheckIn c) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    if (c.workoutsThisWeek == 0) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'No workouts yet this week — a short session keeps the streak alive.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ));
    }

    widgets.add(Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Metric(label: 'Workouts', value: '${c.workoutsThisWeek}'),
        ),
        Expanded(
          child: _Metric(label: 'Sets', value: '${c.setsThisWeek}'),
        ),
        Expanded(
          flex: 2,
          child: _Metric(
            label: 'Volume',
            value: '${_formatVolume(c.volumeThisWeek)} $_unit',
            trailing: _volumeChange(theme, c),
          ),
        ),
      ],
    ));

    if (c.recordsThisWeek.isNotEmpty) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(const _SectionTitle(
          icon: Icons.emoji_events_outlined, text: 'New records this week'));
      widgets.addAll(_recordLines(theme, c.recordsThisWeek));
    }

    if (c.setsPerMuscleGroup.isNotEmpty) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(const _SectionTitle(
          icon: Icons.accessibility_new, text: 'Sets per muscle group'));
      final entries = c.setsPerMuscleGroup.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      widgets.add(Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in entries)
            _CountChip(label: _titleCase(e.key), count: e.value),
        ],
      ));
    }

    if (c.neglectedMuscleGroups.isNotEmpty) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(_Notice(
        icon: Icons.schedule,
        color: theme.colorScheme.tertiary,
        text: 'Not trained in 7+ days: '
            '${c.neglectedMuscleGroups.map(_titleCase).join(', ')}',
      ));
    }

    for (final trend in c.plateaus) {
      widgets.add(const SizedBox(height: 8));
      final name = exercisesById[trend.exerciseId]?.name ?? 'An exercise';
      widgets.add(_Notice(
        icon: Icons.trending_flat,
        color: theme.colorScheme.error,
        text: '$name has stalled for 3 sessions — try a lighter week',
      ));
    }

    return widgets;
  }

  Widget? _volumeChange(ThemeData theme, WeeklyCheckIn c) {
    final last = c.volumeLastWeek;
    if (last == null || last <= 0) return null;
    final pct = (c.volumeThisWeek - last) / last * 100;
    final up = pct >= 0;
    final color = up ? theme.colorScheme.primary : theme.colorScheme.error;
    return Text(
      '${up ? '↑' : '↓'} ${pct.abs().toStringAsFixed(0)}% vs last week',
      style: theme.textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }

  List<Widget> _recordLines(ThemeData theme, List<PersonalRecord> records) {
    // Group by exercise so each exercise is one line.
    final byExercise = <String, List<PersonalRecord>>{};
    for (final r in records) {
      byExercise.putIfAbsent(r.exerciseId, () => []).add(r);
    }
    return byExercise.entries.take(5).map((entry) {
      final name = exercisesById[entry.key]?.name ?? 'Exercise';
      final parts = entry.value.map(_formatRecord).join(' · ');
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '$name  ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: parts),
          ]),
          style: theme.textTheme.bodyMedium,
        ),
      );
    }).toList();
  }

  String _formatRecord(PersonalRecord r) {
    switch (r.type) {
      case RecordType.bestE1rm:
        return 'e1RM ${_formatWeight(r.value)} $_unit';
      case RecordType.heaviestWeight:
        return 'heaviest ${_formatWeight(r.value)} $_unit';
      case RecordType.mostVolume:
        return 'volume ${_formatVolume(r.value)} $_unit';
    }
  }

  static String _formatWeight(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  static String _formatVolume(double v) {
    if (v >= 100000) return NumberFormat.compact().format(v);
    return NumberFormat.decimalPattern().format(v.round());
  }

  static String _titleCase(String s) {
    return s
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _StreakBadge extends StatelessWidget {
  final int weeks;
  const _StreakBadge({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            '$weeks-week streak',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  const _Metric({required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  const _CountChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label · $count',
        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Notice({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
