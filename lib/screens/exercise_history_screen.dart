import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/exercise_metadata.dart';
import 'package:testfitness/widgets/exercise_history_chart.dart';

/// Read-only history for one exercise: headline stats, the coach's next
/// target, a progress chart, personal records and recent sessions.
class ExerciseHistoryScreen extends StatelessWidget {
  const ExerciseHistoryScreen(
      {super.key, required this.exercise, this.workouts});

  final Exercise exercise;

  /// Workouts to read history from. When null they come from
  /// `context.read<WorkoutBloc>().state.workouts`.
  final List<Workout>? workouts;

  @override
  Widget build(BuildContext context) {
    final all = workouts ?? context.read<WorkoutBloc>().state.workouts;
    final coach = ProgressionCoach(
        useMetric: UserPreferencesService().getUseMetricUnits());
    final sessions = coach.history(exercise.id, all);

    final category = ExerciseMetadata.resolveCategory(exercise);
    final bodyParts = ExerciseMetadata.resolveBodyParts(exercise);
    final subtitle = [
      if (category.isNotEmpty) category,
      if (bodyParts.isNotEmpty) bodyParts.join(', '),
    ].join(' · ');

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(exercise.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
      body: sessions.isEmpty
          ? _EmptyHistory(exerciseName: exercise.name)
          : _HistoryBody(
              exercise: exercise,
              sessions: sessions,
              workouts: all,
              coach: coach,
            ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.exerciseName});

  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No history yet', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Complete a set of $exerciseName to see your progress, records '
              'and recent sessions here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const _TargetCard(target: null),
          ],
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.exercise,
    required this.sessions,
    required this.workouts,
    required this.coach,
  });

  final Exercise exercise;

  /// Newest first.
  final List<SessionSummary> sessions;
  final List<Workout> workouts;
  final ProgressionCoach coach;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Best e1RM session.
    var bestE1rmSession = sessions.first;
    // Heaviest set (ties: more reps) and its session date.
    var heaviestSet = sessions.first.topSet;
    var heaviestDate = sessions.first.date;
    // Most volume session.
    var volumeSession = sessions.first;
    for (final s in sessions) {
      if (s.bestE1rm > bestE1rmSession.bestE1rm) bestE1rmSession = s;
      if (s.volume > volumeSession.volume) volumeSession = s;
      for (final set in s.sets) {
        if (set.weight > heaviestSet.weight ||
            (set.weight == heaviestSet.weight && set.reps > heaviestSet.reps)) {
          heaviestSet = set;
          heaviestDate = s.date;
        }
      }
    }
    final bestSet = bestE1rmSession.topSet;

    final trend = coach.trend(exercise.id, workouts);
    final change = trend.changePercent;
    final target = coach.target(exercise.id, workouts);

    String weightOrBodyweight(double w) =>
        w > 0 ? coach.formatWeight(roundTo1(w)) : 'Bodyweight';

    final stats = <_Stat>[
      _Stat(
        'Best est. 1RM',
        bestE1rmSession.bestE1rm > 0
            ? coach.formatWeight(roundTo1(bestE1rmSession.bestE1rm))
            : '—',
      ),
      _Stat('Heaviest weight', weightOrBodyweight(heaviestSet.weight)),
      _Stat('Best set', _formatSet(bestSet, coach)),
      _Stat('Sessions', '${sessions.length}'),
      _Stat(
        '8-week change',
        change == null
            ? '—'
            : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _StatGrid(stats: stats),
        const SizedBox(height: 12),
        _TargetCard(target: target, coach: coach),
        const SizedBox(height: 24),
        Text('Progress', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        ExerciseHistoryChart(
          sessions: sessions,
          coach: coach,
          plateau: trend.plateau,
        ),
        const SizedBox(height: 24),
        Text('Records', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        _RecordTile(
          icon: Icons.emoji_events_outlined,
          label: 'Best estimated 1RM',
          value: bestE1rmSession.bestE1rm > 0
              ? coach.formatWeight(roundTo1(bestE1rmSession.bestE1rm))
              : '—',
          detail: _formatSet(bestSet, coach),
          date: bestE1rmSession.date,
        ),
        _RecordTile(
          icon: Icons.fitness_center,
          label: 'Heaviest weight',
          value: weightOrBodyweight(heaviestSet.weight),
          detail: _formatSet(heaviestSet, coach),
          date: heaviestDate,
        ),
        _RecordTile(
          icon: Icons.stacked_bar_chart,
          label: 'Most volume in a session',
          value: volumeSession.volume > 0
              ? coach.formatWeight(roundTo1(volumeSession.volume))
              : '—',
          detail: '${volumeSession.sets.length} '
              '${volumeSession.sets.length == 1 ? 'set' : 'sets'}',
          date: volumeSession.date,
        ),
        const SizedBox(height: 24),
        Text('Recent sessions', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        _RecentSessions(sessions: sessions, coach: coach),
      ],
    );
  }
}

String _formatSet(WorkoutSet set, ProgressionCoach coach) {
  if (set.weight <= 0) return '${set.reps} reps';
  return '${coach.formatWeight(set.weight)} × ${set.reps}';
}

String _formatDate(DateTime date) => DateFormat.yMMMd().format(date);

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 8.0;
      final width = (constraints.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final stat in stats)
            SizedBox(
              width: width,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target, this.coach});

  final ProgressionTarget? target;
  final ProgressionCoach? coach;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = target;
    final label = t == null
        ? 'Log a session to get a target'
        : t.weight > 0
            ? 'Next: ${coach!.formatWeight(t.weight)} × ${t.reps}'
            : 'Next: ${t.reps} reps';
    return Container(
      key: const Key('history-target'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined,
                  size: 18, color: scheme.onSecondaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (t != null) ...[
            const SizedBox(height: 4),
            Text(
              t.message,
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.date,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.primary),
      title: Text(label),
      subtitle: Text('$detail · ${_formatDate(date)}'),
      trailing: Text(
        value,
        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RecentSessions extends StatefulWidget {
  const _RecentSessions({required this.sessions, required this.coach});

  /// Newest first.
  final List<SessionSummary> sessions;
  final ProgressionCoach coach;

  @override
  State<_RecentSessions> createState() => _RecentSessionsState();
}

class _RecentSessionsState extends State<_RecentSessions> {
  static const _pageSize = 20;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final visible = widget.sessions.take(_shown).toList();
    final remaining = widget.sessions.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in visible)
          _buildSession(session, scheme, textTheme),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () => setState(() => _shown += _pageSize),
              child: Text('Show more ($remaining)'),
            ),
          ),
      ],
    );
  }

  Widget _buildSession(
      SessionSummary session, ColorScheme scheme, TextTheme textTheme) {
    final rpes = session.sets
        .map((s) => s.rpe)
        .whereType<double>()
        .toList(growable: false);
    final rpeAvg =
        rpes.isEmpty ? null : rpes.reduce((a, b) => a + b) / rpes.length;
    final details = <String>[
      if (session.volume > 0)
        'Volume ${widget.coach.formatWeight(roundTo1(session.volume))}',
      if (rpeAvg != null) 'RPE avg ${rpeAvg.toStringAsFixed(1)}',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(session.date),
            style: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            session.topSet.weight > 0
                ? '${session.formatSets()} ${widget.coach.unit}'
                : session.formatSets(),
            style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              details.join(' · '),
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}
