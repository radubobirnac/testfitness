import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';

/// One workout placed on a calendar day.
class CalendarEntry {
  final Workout workout;

  /// Midnight (local) of the day the workout belongs to.
  final DateTime day;

  /// True when the workout has at least one completed working set.
  final bool isDone;

  const CalendarEntry({
    required this.workout,
    required this.day,
    required this.isDone,
  });

  /// Completed working sets (warm-ups excluded).
  int get completedSets =>
      workout.sets.where(ProgressionCoach.isCountable).length;

  /// Sets shown in the day list: completed working sets for a done workout,
  /// planned sets for a scheduled one.
  int get displaySets => isDone ? completedSets : workout.sets.length;

  int get exerciseCount => workout.exerciseIds.length;

  double get volume => workout.sets
      .where(ProgressionCoach.isCountable)
      .fold(0.0, (sum, s) => sum + s.weight * s.reps);
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Places workouts on calendar days, keyed by local midnight.
///
/// A workout is "done" when it has >= 1 completed working set; its day is the
/// earliest such set's date as the progression coach sees it
/// (set.completedAt → workout.completedDate → workout.scheduledDate).
/// Workouts without completed sets appear on their scheduledDate as
/// "scheduled"; undated ones are left out.
Map<DateTime, List<CalendarEntry>> buildCalendarEntries(
    List<Workout> workouts) {
  final result = <DateTime, List<CalendarEntry>>{};
  for (final workout in workouts) {
    DateTime? earliest;
    for (final set in workout.sets) {
      if (!ProgressionCoach.isCountable(set)) continue;
      final date = ProgressionCoach.setDate(set, workout);
      if (date != null && (earliest == null || date.isBefore(earliest))) {
        earliest = date;
      }
    }
    final CalendarEntry entry;
    if (earliest != null) {
      entry = CalendarEntry(
          workout: workout, day: _dayOf(earliest), isDone: true);
    } else if (workout.scheduledDate != null) {
      entry = CalendarEntry(
          workout: workout,
          day: _dayOf(workout.scheduledDate!),
          isDone: false);
    } else {
      continue;
    }
    result.putIfAbsent(entry.day, () => []).add(entry);
  }
  for (final list in result.values) {
    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? -1 : 1;
      return a.workout.name.compareTo(b.workout.name);
    });
  }
  return result;
}

/// Month calendar of completed (filled dot) and scheduled (ring) workouts.
///
/// Reads workouts from [WorkoutBloc] unless [workouts] is given (tests).
class WorkoutCalendarScreen extends StatefulWidget {
  const WorkoutCalendarScreen({
    super.key,
    this.workouts,
    this.now,
    this.useMetric,
  });

  final List<Workout>? workouts;

  /// "Today" override for tests.
  final DateTime? now;

  /// Unit override for tests; defaults to the user's preference.
  final bool? useMetric;

  @override
  State<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends State<WorkoutCalendarScreen> {
  late DateTime _month; // first day of the shown month
  DateTime? _selectedDay;

  DateTime get _today => _dayOf(widget.now ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
    _selectedDay = _today;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final today = _today;
      _selectedDay =
          (today.year == _month.year && today.month == _month.month)
              ? today
              : null;
    });
  }

  void _goToToday() {
    setState(() {
      _month = DateTime(_today.year, _today.month);
      _selectedDay = _today;
    });
  }

  String _locale(BuildContext context) =>
      Localizations.maybeLocaleOf(context)?.toString() ?? Intl.getCurrentLocale();

  /// DateFormat in the app locale, falling back to the default locale when
  /// that locale's date symbols are not loaded.
  DateFormat _format(
      BuildContext context, DateFormat Function(String? locale) build) {
    try {
      return build(_locale(context));
    } catch (_) {
      return build(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workouts != null) {
      return _buildScaffold(context, widget.workouts!);
    }
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) => _buildScaffold(context, state.workouts),
    );
  }

  Widget _buildScaffold(BuildContext context, List<Workout> workouts) {
    final entries = buildCalendarEntries(workouts);
    final useMetric =
        widget.useMetric ?? UserPreferencesService().getUseMetricUnits();
    final coach = ProgressionCoach(useMetric: useMetric);

    final monthDone = entries.entries
        .where((e) =>
            e.key.year == _month.year && e.key.month == _month.month)
        .expand((e) => e.value)
        .where((e) => e.isDone)
        .length;
    final streak =
        coach.weeklyCheckIn(workouts, const {}, now: widget.now).streakWeeks;
    final summary = [
      '$monthDone ${monthDone == 1 ? 'workout' : 'workouts'}',
      if (streak > 0) '$streak-week streak',
    ].join(' · ');

    final selected = _selectedDay;
    final dayEntries =
        selected == null ? const <CalendarEntry>[] : entries[selected] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: _goToToday,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -200) _changeMonth(1);
          if (v > 200) _changeMonth(-1);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _buildMonthHeader(context),
            _buildWeekdayRow(context),
            _buildGrid(context, entries),
            const SizedBox(height: 8),
            Text(
              summary,
              key: const ValueKey('calendar-summary'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Divider(height: 24),
            if (selected != null) ..._buildDayList(context, selected, dayEntries, coach),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final title = _format(context, (l) => DateFormat.yMMMM(l)).format(_month);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: () => _changeMonth(-1),
        ),
        Expanded(
          child: Text(
            title,
            key: const ValueKey('calendar-month-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow(BuildContext context) {
    final fmt = _format(context, (l) => DateFormat.E(l));
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    // 1 Jan 2024 was a Monday.
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                fmt.format(DateTime(2024, 1, 1 + i)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: style,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(
      BuildContext context, Map<DateTime, List<CalendarEntry>> entries) {
    final leading = _month.weekday - 1; // Mon-first
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final rows = <Widget>[];
    for (var r = 0; r < cellCount ~/ 7; r++) {
      rows.add(Row(
        children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: _buildDayCell(
                  context, r * 7 + c - leading + 1, daysInMonth, entries),
            ),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _buildDayCell(BuildContext context, int dayNumber, int daysInMonth,
      Map<DateTime, List<CalendarEntry>> entries) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 48);
    }
    final scheme = Theme.of(context).colorScheme;
    final day = DateTime(_month.year, _month.month, dayNumber);
    final dayEntries = entries[day] ?? const <CalendarEntry>[];
    final doneCount = dayEntries.where((e) => e.isDone).length;
    final scheduledCount = dayEntries.length - doneCount;
    final isToday = day == _today;
    final isSelected = day == _selectedDay;
    final keyId = DateFormat('yyyy-MM-dd').format(day);

    Color textColor = scheme.onSurface;
    BoxDecoration? marker;
    Key? markerKey;
    if (doneCount > 0) {
      marker = BoxDecoration(color: scheme.primary, shape: BoxShape.circle);
      textColor = scheme.onPrimary;
      markerKey = ValueKey('calendar-done-$keyId');
    } else if (scheduledCount > 0) {
      marker = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.primary, width: 2),
      );
      markerKey = ValueKey('calendar-scheduled-$keyId');
    }
    if (isToday && doneCount == 0) textColor = scheme.primary;

    final parts = <String>[
      _format(context, (l) => DateFormat.MMMMd(l)).format(day),
      if (isToday) 'today',
      if (doneCount > 0) '$doneCount completed',
      if (scheduledCount > 0) '$scheduledCount scheduled',
    ];

    return Semantics(
      button: true,
      selected: isSelected,
      label: parts.join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('calendar-day-$keyId'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedDay = day),
        child: Container(
          height: 48,
          decoration: isSelected
              ? BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          alignment: Alignment.center,
          child: Container(
            key: markerKey,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: marker,
            child: Text(
              '$dayNumber',
              style: TextStyle(
                color: textColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                decoration: isToday ? TextDecoration.underline : null,
                decorationColor: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDayList(BuildContext context, DateTime day,
      List<CalendarEntry> dayEntries, ProgressionCoach coach) {
    final theme = Theme.of(context);
    final heading =
        _format(context, (l) => DateFormat.MMMMEEEEd(l)).format(day);
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(heading,
            key: const ValueKey('calendar-day-heading'),
            style: theme.textTheme.titleMedium),
      ),
      if (dayEntries.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No workouts on this day',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      for (final entry in dayEntries)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            minVerticalPadding: 12,
            leading: Icon(
              entry.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: theme.colorScheme.primary,
            ),
            title: Text(entry.workout.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_subtitle(entry, coach)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseDetailScreen.editWorkout(
                    workoutId: entry.workout.id),
              ),
            ),
          ),
        ),
    ];
  }

  String _subtitle(CalendarEntry entry, ProgressionCoach coach) {
    final ex = entry.exerciseCount;
    final sets = entry.displaySets;
    return [
      if (!entry.isDone) 'Planned',
      '$ex ${ex == 1 ? 'exercise' : 'exercises'}',
      '$sets ${sets == 1 ? 'set' : 'sets'}',
      if (entry.isDone) coach.formatWeight(entry.volume),
    ].join(' · ');
  }
}
