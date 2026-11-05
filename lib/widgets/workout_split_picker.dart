import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/ai_workout_generator.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/split_workout_builder.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/muscle_map.dart';

/// Builds a workout for [split] with AI, matching only exercises in [pool].
typedef SplitAiBuilder = Future<Workout> Function(
    WorkoutSplit split, List<Workout> history, List<Exercise> pool);

/// What the picker hands back when the user taps "Start workout".
class SplitPickerResult {
  final Workout workout;

  /// Shown as a SnackBar after the workout opens (e.g. AI fallback notice).
  final String? message;

  const SplitPickerResult(this.workout, {this.message});
}

/// Loads the exercise library, then opens [showWorkoutSplitPicker].
Future<void> openWorkoutSplitPicker(
    BuildContext context, List<Workout> history) async {
  List<Exercise> exercises;
  try {
    exercises = await ExerciseRepository().getExercises();
  } catch (e) {
    AppLogger.warning('Could not load exercises for split picker', e);
    exercises = const [];
  }
  if (!context.mounted) return;
  await showWorkoutSplitPicker(context,
      history: history, exercises: exercises);
}

/// "Choose your workout" bottom sheet. Starting a split creates the workout
/// via [WorkoutBloc] and opens the editor (same flow as "Next workout").
Future<void> showWorkoutSplitPicker(
  BuildContext context, {
  required List<Workout> history,
  required List<Exercise> exercises,
  bool? useMetric,
  WorkoutPreferences? preferences,
  bool? aiAvailable,
  RoutineRepository? routineRepository,
  SplitAiBuilder? aiBuilder,
  DateTime? now,
}) async {
  final bloc = context.read<WorkoutBloc>();
  final prefsService = UserPreferencesService();
  final result = await showModalBottomSheet<SplitPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.92,
      child: WorkoutSplitPicker(
        history: history,
        exercises: exercises,
        useMetric: useMetric ?? prefsService.getUseMetricUnits(),
        preferences: preferences ??
            WorkoutPreferences.fromMap(prefsService.getWorkoutPreferences()),
        aiAvailable: aiAvailable ?? AIService().isAvailable,
        routineRepository: routineRepository,
        aiBuilder: aiBuilder,
        now: now,
      ),
    ),
  );
  if (result == null || !context.mounted) return;

  bloc.add(WorkoutCreateRequested(result.workout));
  if (result.message != null) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(result.message!)));
  }
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ExerciseDetailScreen.editWorkout(workoutId: result.workout.id),
    ),
  );
  if (!bloc.isClosed) bloc.add(const WorkoutLoadRequested());
}

/// Default AI build: tells the AI the split and limits matching to [pool].
Future<Workout> _defaultAiBuild(
    WorkoutSplit split, List<Workout> history, List<Exercise> pool) {
  return AIWorkoutGenerator().generateAiWorkout(
    workoutName: split.name,
    focus: split.name.toLowerCase(),
    recentWorkouts: history,
    split: AiSplitRequest(
      name: split.name,
      main: [for (final m in split.main) m.label],
      secondary: [for (final m in split.secondary) m.label],
    ),
    candidatePool: pool,
  );
}

/// "Chest", "Chest & triceps", "Quads, hamstrings & glutes".
String describeMuscles(List<Muscle> muscles) {
  final labels = <String>[
    for (var i = 0; i < muscles.length; i++)
      i == 0 ? muscles[i].label : muscles[i].label.toLowerCase(),
  ];
  if (labels.isEmpty) return '';
  if (labels.length == 1) return labels.first;
  return '${labels.sublist(0, labels.length - 1).join(', ')} & ${labels.last}';
}

/// "trained today", "trained 1 day ago", "not trained yet".
String describeTrained(DateTime? last, DateTime now) {
  if (last == null) return 'not trained yet';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(last.year, last.month, last.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'trained today';
  if (days == 1) return 'trained 1 day ago';
  return 'trained $days days ago';
}

/// Target line for the preview: "190 × 8 · 3 sets" (or "8 reps · 3 sets").
String describeTarget(Workout workout, String exerciseId) {
  final sets =
      workout.sets.where((s) => s.exerciseId == exerciseId && !s.isWarmup);
  final count = sets.length;
  final setsText = '$count ${count == 1 ? 'set' : 'sets'}';
  if (sets.isEmpty) return setsText;
  final first = sets.first;
  if (first.weight > 0) {
    return '${ProgressionCoach.formatNumber(first.weight)} × ${first.reps} · $setsText';
  }
  return '${first.reps} reps · $setsText';
}

enum _Stage { list, customMain, customSecond, preview }

/// The picker's content. Takes all data via the constructor so it can be
/// tested without a bloc; [onStart] defaults to popping the sheet.
class WorkoutSplitPicker extends StatefulWidget {
  final List<Workout> history;
  final List<Exercise> exercises;
  final bool useMetric;
  final WorkoutPreferences? preferences;
  final bool aiAvailable;
  final RoutineRepository? routineRepository;
  final SplitAiBuilder? aiBuilder;
  final DateTime? now;
  final ValueChanged<SplitPickerResult>? onStart;

  const WorkoutSplitPicker({
    super.key,
    required this.history,
    required this.exercises,
    required this.useMetric,
    this.preferences,
    this.aiAvailable = false,
    this.routineRepository,
    this.aiBuilder,
    this.now,
    this.onStart,
  });

  @override
  State<WorkoutSplitPicker> createState() => _WorkoutSplitPickerState();
}

class _WorkoutSplitPickerState extends State<WorkoutSplitPicker> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final SplitWorkoutBuilder _builder =
      SplitWorkoutBuilder(useMetric: widget.useMetric);
  late final Map<String, Exercise> _byId = {
    for (final e in widget.exercises) e.id: e,
  };
  late final WorkoutSplit _suggested =
      _builder.suggest(widget.history, widget.exercises, now: _now);
  late final Map<Muscle, DateTime> _lastTrained = _computeLastTrained();

  _Stage _stage = _Stage.list;
  Muscle? _customMain;
  WorkoutSplit? _split;
  SplitPlan? _plan;
  bool _useAi = false;
  bool _busy = false;
  bool _saved = false;

  DateTime get _now => widget.now ?? DateTime.now();

  Map<Muscle, DateTime> _computeLastTrained() {
    final result = <Muscle, DateTime>{};
    for (final w in widget.history) {
      for (final set in w.sets) {
        if (!ProgressionCoach.isCountable(set)) continue;
        final exercise = _byId[set.exerciseId];
        if (exercise == null) continue;
        final date = ProgressionCoach.setDate(set, w);
        if (date == null || date.isAfter(_now)) continue;
        for (final m in MuscleMap.of(exercise).primary) {
          final prev = result[m];
          if (prev == null || date.isAfter(prev)) result[m] = date;
        }
      }
    }
    return result;
  }

  List<Muscle> _musclesOf(WorkoutSplit split) => split.muscles;

  Future<void> _choose(WorkoutSplit split) async {
    HapticFeedback.selectionClick();
    final plan = _builder.build(
      split,
      widget.history,
      widget.exercises,
      preferences: widget.preferences,
      now: widget.now,
    );
    if (plan.recentlyTrained.isNotEmpty) {
      final many = plan.recentlyTrained.length > 1;
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Recently trained'),
          content: Text('${describeMuscles(plan.recentlyTrained)} '
              '${many ? 'were' : 'was'} trained in the last 48 h. '
              'Start anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Pick another'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start anyway'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    setState(() {
      _split = split;
      _plan = plan;
      _stage = _Stage.preview;
      _useAi = false;
      _saved = false;
    });
  }

  void _back() {
    setState(() {
      _stage = _stage == _Stage.customSecond ? _Stage.customMain : _Stage.list;
    });
  }

  Future<void> _saveAsRoutine() async {
    final split = _split;
    final plan = _plan;
    if (split == null || plan == null) return;
    final routine = Routine.fromWorkout(plan.workout, name: split.name);
    if (routine.exercises.isEmpty) return;
    try {
      await (widget.routineRepository ?? RoutineRepository())
          .saveRoutine(routine);
    } catch (e) {
      AppLogger.warning('Could not save split as routine', e);
      _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Could not save the routine')));
      return;
    }
    if (!mounted) return;
    setState(() => _saved = true);
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Saved "${split.name}" as a routine')),
    );
  }

  Future<void> _start() async {
    final split = _split;
    final plan = _plan;
    if (split == null || plan == null || _busy) return;
    var workout = plan.workout;
    String? message;
    if (_useAi && widget.aiAvailable) {
      setState(() => _busy = true);
      final muscles = _musclesOf(split);
      final pool = widget.exercises
          .where((e) => muscles.any(MuscleMap.of(e).primarily))
          .toList();
      try {
        final built = await (widget.aiBuilder ?? _defaultAiBuild)(
                split, widget.history, pool)
            .timeout(const Duration(seconds: 30));
        if (built.sets.isEmpty) throw StateError('AI returned no exercises');
        workout = built;
      } catch (e) {
        AppLogger.warning('AI split build failed, using coach plan', e);
        message = 'AI unavailable — started your coach plan instead.';
      }
      if (!mounted) return;
      setState(() => _busy = false);
    }
    final result = SplitPickerResult(workout, message: message);
    if (widget.onStart != null) {
      widget.onStart!(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = switch (_stage) {
      _Stage.list => 'Choose your workout',
      _Stage.customMain => 'Pick your main muscle',
      _Stage.customSecond => 'Pick a second muscle',
      _Stage.preview => _split?.name ?? 'Your workout',
    };
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLow,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  _stage == _Stage.list ? 16 : 4, 4, 16, 4),
              child: Row(
                children: [
                  if (_stage != _Stage.list)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: _busy ? null : _back,
                    ),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: switch (_stage) {
                  _Stage.list => _buildList(cs, textTheme),
                  _Stage.customMain => _buildMuscleChooser(second: false),
                  _Stage.customSecond => _buildMuscleChooser(second: true),
                  _Stage.preview => _buildPreview(cs, textTheme),
                },
              ),
            ),
          ],
        ),
        // In the bottom bar so SnackBars appear above the buttons.
        bottomNavigationBar: _stage == _Stage.preview &&
                (_plan?.workout.sets.isNotEmpty ?? false)
            ? _buildPreviewActions()
            : null,
      ),
    );
  }

  Widget _buildList(ColorScheme cs, TextTheme textTheme) {
    final why = '${describeMuscles(_musclesOf(_suggested))} '
        '${_musclesOf(_suggested).length > 1 ? 'are' : 'is'} the most rested';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('split_suggested'),
          color: cs.primaryContainer,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _choose(_suggested),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suggested for today: ${_suggested.name}',
                            style: textTheme.titleMedium?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            why,
                            style: textTheme.bodyMedium
                                ?.copyWith(color: cs.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final split in WorkoutSplit.presets) ...[
          _buildSplitTile(split, cs, textTheme),
          const SizedBox(height: 8),
        ],
        Card(
          key: const Key('split_custom'),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Custom'),
            subtitle: const Text('Pick a main and a second muscle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() {
              _customMain = null;
              _stage = _Stage.customMain;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitTile(
      WorkoutSplit split, ColorScheme cs, TextTheme textTheme) {
    final muscles = _musclesOf(split);
    return Card(
      key: Key('split_${split.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _choose(split),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(split.name,
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        muscles.map((m) => m.label).join(' · '),
                        style: textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          for (final m in muscles)
                            Text(
                              '${m.label}: ${describeTrained(_lastTrained[m], _now)}',
                              style: textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMuscleChooser({required bool second}) {
    final muscles = Muscle.values.where((m) => m != Muscle.cardio).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (second && _customMain != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Main: ${_customMain!.label}'),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in muscles)
              OutlinedButton(
                key: Key('muscle_${m.name}'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(96, 48)),
                onPressed: second && m == _customMain
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        if (!second) {
                          setState(() {
                            _customMain = m;
                            _stage = _Stage.customSecond;
                          });
                        } else {
                          _choose(WorkoutSplit.custom(_customMain!, m));
                        }
                      },
                child: Text(m.label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme cs, TextTheme textTheme) {
    final plan = _plan;
    final split = _split;
    if (plan == null || split == null) return const SizedBox.shrink();
    if (plan.workout.sets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.fitness_center, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No exercises for ${describeMuscles(_musclesOf(split)).toLowerCase()} '
            'in your library yet.',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add some in the Exercises tab, or pick another workout.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _back,
              child: const Text('Pick another'),
            ),
          ),
        ],
      );
    }
    final ids = plan.workout.exerciseIds.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(plan.summary,
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (var i = 0; i < ids.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
              child: Text('${i + 1}'),
            ),
            title: Text(_byId[ids[i]]?.name ?? 'Exercise'),
            subtitle: Text(describeTarget(plan.workout, ids[i])),
          ),
        if (widget.aiAvailable)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use AI to build it'),
            subtitle: const Text('Falls back to this plan if AI fails'),
            value: _useAi,
            onChanged: _busy ? null : (v) => setState(() => _useAi = v),
          ),
      ],
    );
  }

  Widget _buildPreviewActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _busy || _saved ? null : _saveAsRoutine,
                child: Text(_saved ? 'Saved' : 'Save as routine'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _busy ? null : _start,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
