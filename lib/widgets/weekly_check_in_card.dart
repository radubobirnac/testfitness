import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/progress_period.dart';
import 'package:testfitness/ui/progress_widgets.dart';

/// Coach-driven weekly summary shown under "This week" on the Progress tab:
/// three stat tiles, a streak chip, then records, muscle groups, neglected
/// groups and plateaus as short sub-sections.
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
    final c = checkIn;
    return ProgressCard(
      child: !hasData(c)
          ? const ProgressEmptyHint(
              key: ValueKey('weekly_check_in_empty'),
              icon: Icons.insights_outlined,
              message: 'Log a workout and your weekly check-in appears here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildContent(context, c!),
            ),
    );
  }

  List<Widget> _buildContent(BuildContext context, WeeklyCheckIn c) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final widgets = <Widget>[];

    widgets.add(Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Gap.sm,
      runSpacing: Gap.xs,
      children: [
        Text(
          'Week of ${DateFormat('MMM d').format(c.weekStart)}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (c.streakWeeks > 0) _StreakChip(weeks: c.streakWeeks),
      ],
    ));
    widgets.add(const SizedBox(height: Gap.sm));

    final change =
        ProgressMath.changePercent(c.volumeThisWeek, c.volumeLastWeek);
    widgets.add(ProgressStatRow(tiles: [
      ProgressStatTile(label: 'Workouts', value: '${c.workoutsThisWeek}'),
      ProgressStatTile(label: 'Sets', value: '${c.setsThisWeek}'),
      ProgressStatTile(
        label: 'Volume',
        value: '${ProgressMath.formatVolume(c.volumeThisWeek)} $_unit',
        change: change == null
            ? null
            : '${ProgressMath.formatChange(change)} vs last week',
        changeUp: change == null ? null : change >= 0,
      ),
    ]));

    if (c.workoutsThisWeek == 0) {
      widgets.add(const SizedBox(height: Gap.sm));
      widgets.add(Text(
        'No workouts yet this week — a short session keeps the streak alive.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ));
    }

    if (c.recordsThisWeek.isNotEmpty) {
      widgets.add(_SubSection(
        icon: Icons.emoji_events_outlined,
        title: 'New records',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _recordLines(theme, c.recordsThisWeek),
        ),
      ));
    }

    if (c.setsPerMuscleGroup.isNotEmpty) {
      final entries = c.setsPerMuscleGroup.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      widgets.add(_SubSection(
        icon: Icons.accessibility_new,
        title: 'Sets per muscle group',
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in entries)
              _Pill(label: '${_titleCase(e.key)} · ${e.value}'),
          ],
        ),
      ));
    }

    if (c.neglectedMuscleGroups.isNotEmpty) {
      widgets.add(_SubSection(
        icon: Icons.schedule,
        title: 'Not trained in 7+ days',
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final g in c.neglectedMuscleGroups)
              _Pill(label: _titleCase(g), outlined: true),
          ],
        ),
      ));
    }

    if (c.plateaus.isNotEmpty) {
      widgets.add(_SubSection(
        icon: Icons.trending_flat,
        title: 'Plateaus',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final trend in c.plateaus)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  '${exercisesById[trend.exerciseId]?.name ?? 'An exercise'} '
                  'has stalled for 3 sessions — try a lighter week',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ));
    }

    return widgets;
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
        padding: const EdgeInsets.only(top: Gap.xs),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$name  ', style: theme.textTheme.titleSmall),
            TextSpan(
              text: parts,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ]),
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
        return 'volume ${ProgressMath.formatVolume(r.value)} $_unit';
    }
  }

  static String _formatWeight(double v) {
    final rounded = (v * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  static String _titleCase(String s) {
    return s
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _StreakChip extends StatelessWidget {
  final int weeks;
  const _StreakChip({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Gap.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: Gap.xs),
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

/// Small titled block inside the card.
class _SubSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SubSection(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool outlined;
  const _Pill({required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: outlined ? null : scheme.surfaceContainerHighest,
        border: outlined ? Border.all(color: scheme.outline) : null,
        borderRadius: BorderRadius.circular(Gap.lg),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      ),
    );
  }
}
