import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/blocs/exercise/exercise_bloc.dart';
import 'package:testfitness/blocs/exercise/exercise_event.dart';
import 'package:testfitness/blocs/exercise/exercise_state.dart';
import 'package:testfitness/blocs/timer/timer_bloc.dart';
import 'package:testfitness/blocs/timer/timer_event.dart';
import 'package:testfitness/blocs/timer/timer_state.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/screens/exercise_selection_sheet.dart';
import 'package:testfitness/screens/workout_summary_screen.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/rest_preferences_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/audio_player_util.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';
import 'package:testfitness/widgets/plate_calculator_sheet.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise? exercise;
  final String? workoutId;

  // Constructor for creating a new workout with an initial exercise
  const ExerciseDetailScreen.newWorkout({super.key, required this.exercise})
      : workoutId = null;

  // Constructor for editing an existing workout
  const ExerciseDetailScreen.editWorkout({super.key, required this.workoutId})
      : exercise = null;

  const ExerciseDetailScreen({super.key, this.exercise, this.workoutId});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen>
    with TickerProviderStateMixin {
  static const String _importedFromCsvLabel = 'Imported from CSV';
  static const String _importedCategoryLabel = 'Imported';
  // Track exercises and their sets (local UI state)
  Map<String, List<WorkoutSet>> _exerciseSets = {};
  Map<String, Exercise> _exercises = {};

  // Maps to store TextEditingControllers for weight and reps fields (local UI state)
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _repsControllers = {};

  // Focus node and controller for editable title (local UI state)
  final FocusNode _titleFocusNode = FocusNode();
  final TextEditingController _nameController = TextEditingController(
    text: 'New Workout',
  );
  bool _isEditingTitle = false;

  // Current workout ID for tracking (local UI state)
  String? _currentWorkoutId;
  bool _hasUnsavedChanges = false;
  bool _suspendDirtyTracking = false;

  // Autosave state: the last workout snapshot this screen persisted. Once set,
  // local state is the source of truth and is no longer reloaded from the bloc.
  Workout? _persistedWorkout;
  Timer? _autosaveTimer;
  static const Duration _autosaveDebounce = Duration(milliseconds: 300);
  late final WorkoutBloc _workoutBloc;

  // Progression coach: targets for new sets and the "Last / Target" hint
  // under each exercise header. Hints are cached per exercise and recomputed
  // when the bloc's workout list (or this workout's id) changes.
  late final ProgressionCoach _coach = ProgressionCoach(
    useMetric: UserPreferencesService().getUseMetricUnits(),
  );
  final Map<String, _CoachHint> _coachHints = {};
  List<Workout>? _coachHintsSource;
  String? _coachHintsExcludeId;
  final Set<String> _expandedCoachHints = {};
  bool _isFinishing = false;

  /// When this workout session started: the time the editor was opened, or
  /// for an existing in-progress workout its earliest completed set if that
  /// is earlier. Null when editing an already-completed workout (duration
  /// then falls back to the first completed set). Not persisted.
  DateTime? _startedAt;

  // Timer related variables (now managed by TimerBloc)
  // Local timer state removed - using TimerBloc instead

  @override
  void initState() {
    super.initState();
    _workoutBloc = context.read<WorkoutBloc>();
    _startedAt = DateTime.now();

    // Per-exercise rest times (header chips + rest timer duration).
    final restPrefs = RestPreferencesService();
    if (!restPrefs.isInitialized) {
      restPrefs.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }

    // Keep the screen on while logging a workout so it doesn't lock between
    // sets.
    unawaited(_setWakelock(true));

    if (widget.workoutId != null) {
      // Load existing workout using BLoC
      _currentWorkoutId = widget.workoutId;
      context
          .read<WorkoutBloc>()
          .add(WorkoutLoadByIdRequested(widget.workoutId!));
    } else if (widget.exercise != null) {
      // Add initial exercise for new workout
      _addExercise(widget.exercise!);
    }

    // Set up focus listener for the title
    _titleFocusNode.addListener(_handleTitleFocusChange);
    _nameController.addListener(_handleNameChanged);
  }

  // Helper method to update local state when workout is loaded from BLoC
  void _updateLocalStateFromWorkout(
      Workout workout, List<Exercise> allExercises) {
    // Filter to only the exercises in this workout
    final exerciseIds = workout.exerciseIds;
    final workoutExercises = allExercises
        .where((exercise) => exerciseIds.contains(exercise.id))
        .toList();

    // Group sets by exercise
    final Map<String, List<WorkoutSet>> setsByExercise = {};
    for (final set in workout.sets) {
      if (!setsByExercise.containsKey(set.exerciseId)) {
        setsByExercise[set.exerciseId] = [];
      }
      setsByExercise[set.exerciseId]!.add(set);
    }

    if (workout.isCompleted) {
      _startedAt = null;
    } else if (_startedAt != null) {
      for (final set in workout.sets) {
        final at = set.completedAt;
        if (set.isCompleted && at != null && at.isBefore(_startedAt!)) {
          _startedAt = at;
        }
      }
    }

    _suspendDirtyTracking = true;
    setState(() {
      _nameController.text = workout.name;
      _exercises = {for (var e in workoutExercises) e.id: e};
      _exerciseSets = setsByExercise;
      _hasUnsavedChanges = false;

      // Initialize controllers for all sets
      for (final sets in _exerciseSets.values) {
        for (final set in sets) {
          _weightControllers[set.id] =
              TextEditingController(text: _formatWeight(set.weight));
          _repsControllers[set.id] =
              TextEditingController(text: set.reps.toString());
        }
      }
    });
    _suspendDirtyTracking = false;
  }

  @override
  void dispose() {
    // Persist any pending autosave before tearing down controllers.
    if (_autosaveTimer?.isActive ?? false) {
      _autosaveTimer!.cancel();
      _autosave(fromDispose: true);
    }
    _nameController.dispose();
    _nameController.removeListener(_handleNameChanged);
    _titleFocusNode.removeListener(_handleTitleFocusChange);
    _titleFocusNode.dispose();

    // Dispose all text controllers
    for (var controller in _weightControllers.values) {
      controller.dispose();
    }
    for (var controller in _repsControllers.values) {
      controller.dispose();
    }

    // Stop any playing sounds
    AudioPlayerUtil().stopSound();

    unawaited(_setWakelock(false));

    super.dispose();
  }

  /// Enable/disable the screen wakelock. Failures (e.g. unsupported platform,
  /// tests without the plugin) are non-fatal.
  Future<void> _setWakelock(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (e) {
      AppLogger.debug('Wakelock ${enabled ? 'enable' : 'disable'} failed: $e');
    }
  }

  /// Rest seconds for [exerciseId]: its per-exercise rest (override or type
  /// default), or the global rest-timer preference for an unknown exercise.
  int _restSecondsFor(String exerciseId) {
    final exercise = _exercises[exerciseId];
    if (exercise == null) {
      return UserPreferencesService().getRestTimerDuration();
    }
    return RestPreferencesService().restSecondsFor(exercise);
  }

  // Start or reset the rest timer using TimerBloc, with [exerciseId]'s rest.
  void _startRestTimer(String exerciseId) {
    final timerDuration = _restSecondsFor(exerciseId);

    // Initialize and start timer using TimerBloc
    context.read<TimerBloc>().add(TimerInitialized(
          durationSeconds: timerDuration,
          showMotivationalPhrases: true,
        ));
    context.read<TimerBloc>().add(const TimerStarted());
  }

  void _handleTitleFocusChange() {
    setState(() {
      _isEditingTitle = _titleFocusNode.hasFocus;
    });
  }

  void _handleNameChanged() {
    if (_suspendDirtyTracking) return;
    _markDirty();
  }

  void _markDirty() {
    if (_suspendDirtyTracking || _hasUnsavedChanges) return;
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  /// The persisted workout whose metadata (id, dates, notes...) should be
  /// preserved when saving, or null if nothing has been persisted yet.
  Workout? _baseWorkout() {
    if (_persistedWorkout != null) return _persistedWorkout;
    final current = _workoutBloc.state.currentWorkout;
    if (_currentWorkoutId != null && current?.id == _currentWorkoutId) {
      return current;
    }
    return null;
  }

  /// Schedule a silent, debounced save of the current workout so completed
  /// sets survive the app being closed mid-workout.
  void _scheduleAutosave() {
    if (_suspendDirtyTracking) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounce, () {
      if (mounted) _autosave();
    });
  }

  void _autosave({bool fromDispose = false}) {
    final allSets = _getAllSets();
    if (allSets.isEmpty) return;
    final base = _baseWorkout();
    Workout workout;
    if (base != null) {
      workout = base.copyWith(name: _nameController.text, sets: allSets);
      _workoutBloc.add(WorkoutUpdateRequested(workout, silent: true));
    } else {
      // Existing workout that has not loaded yet: nothing safe to write.
      if (_currentWorkoutId != null) return;
      // New workout: create it on the first completed set.
      if (!allSets.any((set) => set.isCompleted)) return;
      workout = Workout.create(
        name: _nameController.text,
        scheduledDate: DateTime.now(),
        sets: allSets,
      );
      _currentWorkoutId = workout.id;
      _workoutBloc.add(WorkoutCreateRequested(workout, silent: true));
    }
    _persistedWorkout = workout;
    if (!fromDispose && mounted) {
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }

  void _addExercise(Exercise exercise) {
    // Don't add if already present
    if (_exercises.containsKey(exercise.id)) {
      AnimatedFeedback.showSnackBar(
        context,
        '${exercise.name} is already in this workout',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      // Add to exercises
      _exercises[exercise.id] = exercise;

      // Initialize set list for this exercise
      _exerciseSets[exercise.id] = [];

      // Add one empty set
      _addSetForExercise(exercise.id);
    });
    _markDirty();
    _scheduleAutosave();
  }

  /// Weight & reps a new set for [exerciseId] should start with: a copy of the
  /// previous set in this workout, else the coach's progression target from
  /// past workouts, else the most recent completed set, else 0 x 8.
  ({double weight, int reps}) _defaultsForNewSet(String exerciseId) {
    final existing = _exerciseSets[exerciseId];
    final working = existing?.where((s) => !s.isWarmup);
    if (working != null && working.isNotEmpty) {
      final last = working.last;
      return (weight: last.weight, reps: last.reps);
    }
    final target = _coachHintFor(exerciseId).target;
    if (target != null) {
      return (weight: target.weight, reps: target.reps);
    }
    final previous = _lastCompletedSetFromHistory(exerciseId);
    if (previous != null) {
      return (weight: previous.weight, reps: previous.reps);
    }
    return (weight: 0, reps: 8);
  }

  /// The most recent completed set of [exerciseId] in any other workout
  /// currently loaded in [WorkoutBloc], or null if there is none.
  WorkoutSet? _lastCompletedSetFromHistory(String exerciseId) {
    WorkoutSet? best;
    DateTime? bestTime;
    for (final workout in _workoutBloc.state.workouts) {
      if (workout.id == _currentWorkoutId) continue;
      final workoutTime = workout.completedDate ?? workout.scheduledDate;
      for (final set in workout.sets) {
        if (set.exerciseId != exerciseId ||
            !set.isCompleted ||
            set.isWarmup) {
          continue;
        }
        final time = set.completedAt ?? workoutTime;
        if (best == null ||
            (time != null && (bestTime == null || !time.isBefore(bestTime)))) {
          best = set;
          bestTime = time;
        }
      }
    }
    return best;
  }

  /// Last session + progression target for [exerciseId], excluding this
  /// workout. Cached until the bloc's workout list changes.
  _CoachHint _coachHintFor(String exerciseId) {
    final workouts = _workoutBloc.state.workouts;
    if (!identical(workouts, _coachHintsSource) ||
        _coachHintsExcludeId != _currentWorkoutId) {
      _coachHints.clear();
      _coachHintsSource = workouts;
      _coachHintsExcludeId = _currentWorkoutId;
    }
    return _coachHints.putIfAbsent(exerciseId, () {
      try {
        return _CoachHint(
          last: _coach.lastSession(exerciseId, workouts,
              excludeWorkoutId: _currentWorkoutId),
          target: _coach.target(exerciseId, workouts,
              excludeWorkoutId: _currentWorkoutId),
        );
      } catch (e) {
        AppLogger.debug('Progression coach failed for $exerciseId: $e');
        return const _CoachHint();
      }
    });
  }

  void _addSetForExercise(String exerciseId) {
    final defaults = _defaultsForNewSet(exerciseId);
    final newSet = WorkoutSet.create(
      exerciseId: exerciseId,
      reps: defaults.reps,
      weight: defaults.weight,
      isCompleted: false,
    );

    setState(() {
      _exerciseSets[exerciseId]?.add(newSet);

      // Create controllers for the new set
      final setKey = newSet.id;
      _weightControllers[setKey] =
          TextEditingController(text: _formatWeight(newSet.weight));
      _repsControllers[setKey] =
          TextEditingController(text: newSet.reps.toString());
    });
    _markDirty();
    _scheduleAutosave();
  }

  /// Delete a set (e.g. after a swipe) and offer an Undo that restores it at
  /// the same position.
  void _deleteSet(String exerciseId, int index) {
    final sets = _exerciseSets[exerciseId];
    if (sets == null || index < 0 || index >= sets.length) return;

    final removed = sets[index];
    final weightController = _weightControllers.remove(removed.id);
    final repsController = _repsControllers.remove(removed.id);

    setState(() {
      sets.removeAt(index);
    });
    // Dispose after the row has left the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      weightController?.dispose();
      repsController?.dispose();
    });
    _markDirty();
    _scheduleAutosave();

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${_setLabel(sets, index, removed)} deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _restoreSet(exerciseId, index, removed),
        ),
      ),
    );
  }

  void _restoreSet(String exerciseId, int index, WorkoutSet set) {
    if (!mounted) return;
    final sets = _exerciseSets[exerciseId];
    // The exercise was removed in the meantime: nothing to restore into.
    if (sets == null || !_exercises.containsKey(exerciseId)) return;
    if (sets.any((s) => s.id == set.id)) return;

    setState(() {
      sets.insert(index.clamp(0, sets.length), set);
      _weightControllers[set.id] =
          TextEditingController(text: _formatWeight(set.weight));
      _repsControllers[set.id] =
          TextEditingController(text: set.reps.toString());
    });
    _markDirty();
    _scheduleAutosave();
  }

  void _removeExercise(String exerciseId) {
    setState(() {
      _exerciseSets.remove(exerciseId);
      _exercises.remove(exerciseId);
    });
    _markDirty();
    _scheduleAutosave();
  }

  /// Weight increment for the -/+ steppers in the user's unit.
  double get _weightStep =>
      UserPreferencesService().getUseMetricUnits() ? 2.5 : 5.0;

  void _stepWeight(String exerciseId, int index, double delta) {
    final set = _exerciseSets[exerciseId]?[index];
    if (set == null) return;
    final controller = _weightControllers[set.id];
    final current =
        double.tryParse(controller?.text.replaceAll(',', '.') ?? '') ??
            set.weight;
    final next = max(0.0, current + delta);
    controller?.text = _formatWeight(next);
    _updateSetWeightForExercise(exerciseId, index, next);
  }

  void _stepReps(String exerciseId, int index, int delta) {
    final set = _exerciseSets[exerciseId]?[index];
    if (set == null) return;
    final controller = _repsControllers[set.id];
    final current = int.tryParse(controller?.text ?? '') ?? set.reps;
    final next = max(0, current + delta);
    controller?.text = next.toString();
    _updateSetRepsForExercise(exerciseId, index, next);
  }

  /// Format a weight without a trailing ".0" (60 -> "60", 62.5 -> "62.5").
  static String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) return weight.toInt().toString();
    return weight
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// "Set 2" (working sets numbered 1, 2, 3… skipping warm-ups) or
  /// "Warm-up set".
  static String _setLabel(List<WorkoutSet> sets, int index, WorkoutSet set) {
    if (set.isWarmup) return 'Warm-up set';
    return 'Set ${_workingSetNumber(sets, index)}';
  }

  /// 1-based number of the working set at [index], not counting warm-ups.
  static int _workingSetNumber(List<WorkoutSet> sets, int index) =>
      sets.take(index).where((s) => !s.isWarmup).length + 1;

  /// The weight currently typed for [set] (falls back to its model value).
  double _liveWeight(WorkoutSet set) =>
      double.tryParse(
          _weightControllers[set.id]?.text.replaceAll(',', '.') ?? '') ??
      set.weight;

  /// Insert warm-up sets before the working sets of [exerciseId], ramping up
  /// to the first working set's weight (or the coach target).
  void _addWarmups(String exerciseId) {
    final sets = _exerciseSets[exerciseId];
    if (sets == null) return;
    if (sets.any((s) => s.isWarmup)) {
      AnimatedFeedback.showSnackBar(context, 'Warm-ups already added');
      return;
    }
    final firstWorking = sets.where((s) => !s.isWarmup).firstOrNull;
    var working = firstWorking != null ? _liveWeight(firstWorking) : 0.0;
    if (working <= 0) working = _coachHintFor(exerciseId).target?.weight ?? 0;

    double? bar;
    try {
      bar = UserPreferencesService().getBarWeight(metric: _coach.useMetric);
    } catch (e) {
      AppLogger.debug('Bar weight unavailable, using default: $e');
    }
    final specs = _coach.warmupSets(working, barWeight: bar);
    if (specs.isEmpty) {
      AnimatedFeedback.showSnackBar(
        context,
        working <= 0
            ? 'Enter a working weight first'
            : 'Working weight is too light for warm-ups',
      );
      return;
    }

    final warmups = [
      for (final spec in specs)
        WorkoutSet.create(
          exerciseId: exerciseId,
          reps: spec.reps,
          weight: spec.weight,
          isWarmup: true,
        ),
    ];
    setState(() {
      sets.insertAll(0, warmups);
      for (final set in warmups) {
        _weightControllers[set.id] =
            TextEditingController(text: _formatWeight(set.weight));
        _repsControllers[set.id] =
            TextEditingController(text: set.reps.toString());
      }
    });
    _markDirty();
    _scheduleAutosave();
  }

  /// Open the plate calculator for the current (first not-done) set of
  /// [exerciseId], or its last set when all are done.
  void _openPlateCalculator(String exerciseId) {
    final sets = _exerciseSets[exerciseId] ?? const <WorkoutSet>[];
    final current =
        sets.where((s) => !s.isCompleted).firstOrNull ?? sets.lastOrNull;
    final weight = current != null ? _liveWeight(current) : 0.0;
    showPlateCalculatorSheet(context, weight: weight);
  }

  /// Let the user pick the exercise's rest (0:30 to 5:00) or go back to its
  /// default.
  Future<void> _showRestPicker(Exercise exercise) async {
    final service = RestPreferencesService();
    final current = service.overrideFor(exercise.id);
    final defaultSeconds =
        RestPreferencesService.defaultRestSecondsFor(exercise);
    // -1 = "Default"; null = dismissed.
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        Widget check(bool selected) => selected
            ? Icon(Icons.check, color: colorScheme.primary)
            : const SizedBox(width: 24);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text('Rest for ${exercise.name}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                ListTile(
                  title: Text('Default '
                      '(${RestPreferencesService.format(defaultSeconds)})'),
                  trailing: check(current == null),
                  onTap: () => Navigator.pop(context, -1),
                ),
                for (final seconds in RestPreferencesService.choices)
                  ListTile(
                    title: Text(RestPreferencesService.format(seconds)),
                    trailing: check(current == seconds),
                    onTap: () => Navigator.pop(context, seconds),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await service.setRestSeconds(exercise.id, picked < 0 ? null : picked);
    if (mounted) setState(() {});
  }

  /// "Rest 2:30" and "Add warm-ups" chips under the exercise header.
  Widget _buildExerciseTools(BuildContext context, Exercise exercise) {
    final colorScheme = Theme.of(context).colorScheme;
    final sets = _exerciseSets[exercise.id] ?? const <WorkoutSet>[];
    final hasWarmups = sets.any((s) => s.isWarmup);
    final rest = RestPreferencesService().restSecondsFor(exercise);
    return Wrap(
      spacing: 8,
      children: [
        ActionChip(
          avatar: Icon(Icons.timer_outlined,
              size: 18, color: colorScheme.onSurfaceVariant),
          label: Text('Rest ${RestPreferencesService.format(rest)}'),
          tooltip: 'Change rest time for this exercise',
          onPressed: () => _showRestPicker(exercise),
        ),
        if (!hasWarmups && sets.any((s) => !s.isWarmup))
          ActionChip(
            avatar: Icon(Icons.whatshot_outlined,
                size: 18, color: colorScheme.onSurfaceVariant),
            label: const Text('Add warm-ups'),
            tooltip: 'Add warm-up sets before the working sets',
            onPressed: () => _addWarmups(exercise.id),
          ),
      ],
    );
  }

  void _toggleSetCompletionForExercise(String exerciseId, int index) {
    if (_exerciseSets.containsKey(exerciseId) &&
        index >= 0 &&
        index < (_exerciseSets[exerciseId]?.length ?? 0)) {
      final set = _exerciseSets[exerciseId]![index];
      final wasCompleted = set.isCompleted;

      setState(() {
        _exerciseSets[exerciseId]![index] = WorkoutSet(
          id: set.id,
          exerciseId: set.exerciseId,
          reps: set.reps,
          weight: set.weight,
          isCompleted: !wasCompleted,
          completedAt: !wasCompleted ? DateTime.now() : null,
          restTimeSeconds: set.restTimeSeconds,
          notes: set.notes,
          isWarmup: set.isWarmup,
        );
      });
      _markDirty();
      _scheduleAutosave();

      // Start or reset the timer when a working set is marked as complete
      // (warm-ups lead straight into the next set, so no rest timer).
      if (!wasCompleted && !set.isWarmup) {
        _startRestTimer(exerciseId);
      }
    }
  }

  void _updateSetRepsForExercise(String exerciseId, int index, int reps) {
    if (_exerciseSets.containsKey(exerciseId) &&
        index >= 0 &&
        index < (_exerciseSets[exerciseId]?.length ?? 0)) {
      final set = _exerciseSets[exerciseId]![index];
      final setId = set.id;

      setState(() {
        // Update the set in the data model
        _exerciseSets[exerciseId]![index] = WorkoutSet(
          id: setId,
          exerciseId: set.exerciseId,
          reps: reps,
          weight: set.weight,
          isCompleted: set.isCompleted,
          completedAt: set.completedAt,
          restTimeSeconds: set.restTimeSeconds,
          notes: set.notes,
          isWarmup: set.isWarmup,
        );

        // No need to update the controller text here since the change came from the controller
      });
      _markDirty();
      _scheduleAutosave();
    }
  }

  void _updateSetWeightForExercise(
      String exerciseId, int index, double weight) {
    if (_exerciseSets.containsKey(exerciseId) &&
        index >= 0 &&
        index < (_exerciseSets[exerciseId]?.length ?? 0)) {
      final set = _exerciseSets[exerciseId]![index];
      final setId = set.id;

      setState(() {
        // Update the set in the data model
        _exerciseSets[exerciseId]![index] = WorkoutSet(
          id: setId,
          exerciseId: set.exerciseId,
          reps: set.reps,
          weight: weight,
          isCompleted: set.isCompleted,
          completedAt: set.completedAt,
          restTimeSeconds: set.restTimeSeconds,
          notes: set.notes,
          isWarmup: set.isWarmup,
        );

        // No need to update the controller text here since the change came from the controller
      });
      _markDirty();
      _scheduleAutosave();
    }
  }

  bool _showExerciseDescription(String? description) {
    if (description == null) return false;
    final trimmed = description.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.toLowerCase() != _importedFromCsvLabel.toLowerCase();
  }

  String _formatExerciseTitle(Exercise exercise) {
    final category = exercise.category?.trim() ?? '';
    final isImported =
        category.toLowerCase() == _importedCategoryLabel.toLowerCase();
    if (category.isEmpty || isImported) {
      return exercise.name;
    }
    return '${exercise.name} ($category)';
  }

  void _showExerciseSelectionSheet() {
    final alreadyAdded = _exercises.keys.toSet();
    showModalBottomSheet<List<Exercise>>(
      context: context,
      isScrollControlled:
          true, // Allow the sheet to be larger than half the screen
      useRootNavigator: true, // Fix Hero tag conflicts on web
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ExerciseSelectionSheet(
          multiSelect: true,
          excludedExerciseIds: alreadyAdded,
        );
      },
    ).then((exercises) {
      if (exercises == null || !mounted) return;
      for (final exercise in exercises) {
        _addExercise(exercise);
      }
    });
  }

  void _showExerciseReplacementSheet(String currentExerciseId) {
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const ExerciseSelectionSheet();
      },
    ).then((newExercise) {
      if (newExercise != null &&
          newExercise.id != currentExerciseId &&
          mounted) {
        // Replace exercise locally first for immediate UI update
        _replaceExerciseLocally(currentExerciseId, newExercise);

        // Show success message
        AnimatedFeedback.showSnackBar(
          context,
          'Exercise replaced in draft.',
          backgroundColor: Colors.green,
        );
      }
    });
  }

  /// Replace exercise locally for immediate UI update
  void _replaceExerciseLocally(String oldExerciseId, Exercise newExercise) {
    final newExerciseId = newExercise.id;
    setState(() {
      // Move sets from old exercise to new exercise
      if (_exerciseSets.containsKey(oldExerciseId)) {
        final sets = _exerciseSets[oldExerciseId]!;
        // Update exercise ID in each set
        final updatedSets =
            sets.map((set) => set.copyWith(exerciseId: newExerciseId)).toList();
        _exerciseSets[newExerciseId] = updatedSets;
        _exerciseSets.remove(oldExerciseId);
      }

      // Replace exercise in map
      _exercises[newExerciseId] = newExercise;
      _exercises.remove(oldExerciseId);
    });
    _markDirty();
    _scheduleAutosave();
  }

  // Get all sets from all exercises
  List<WorkoutSet> _getAllSets() {
    final allSets = <WorkoutSet>[];
    for (final sets in _exerciseSets.values) {
      allSets.addAll(sets);
    }
    return allSets;
  }

  void _saveWorkout() {
    final allSets = _getAllSets();
    if (allSets.isEmpty) {
      AnimatedFeedback.showSnackBar(
        context,
        'Please add at least one set',
        backgroundColor: Colors.red,
      );
      return;
    }

    // An explicit save supersedes any pending autosave.
    _autosaveTimer?.cancel();

    final base = _baseWorkout();
    if (base != null) {
      // Update the existing (or already autosaved) workout, keeping its
      // id and metadata.
      final updatedWorkout =
          base.copyWith(name: _nameController.text, sets: allSets);
      _persistedWorkout = updatedWorkout;
      _workoutBloc.add(WorkoutUpdateRequested(updatedWorkout));
    } else if (_currentWorkoutId == null) {
      // Create a new workout
      final workout = Workout.create(
        name: _nameController.text,
        scheduledDate: DateTime.now(),
        sets: allSets,
      );
      _currentWorkoutId = workout.id;
      _persistedWorkout = workout;
      _workoutBloc.add(WorkoutCreateRequested(workout));
    }
  }

  int get _completedSetCount =>
      _getAllSets().where((set) => set.isCompleted).length;

  /// Finish the workout: persist all sets, mark the workout completed
  /// (completedDate = now), stop the rest timer and show the summary.
  ///
  /// Persisted with a *silent* bloc update/create so the bloc emits no
  /// success message (which this screen's listener answers by popping to the
  /// root) and the summary screen can replace this route instead.
  Future<void> _finishWorkout() async {
    if (_isFinishing) return;
    final allSets = _getAllSets();
    final doneCount = allSets.where((set) => set.isCompleted).length;
    if (doneCount == 0) {
      AnimatedFeedback.showSnackBar(
        context,
        'Complete at least one set to finish',
        backgroundColor: Colors.red,
      );
      return;
    }

    final notDone = allSets.length - doneCount;
    if (notDone > 0) {
      final finishAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$notDone ${notDone == 1 ? 'set' : 'sets'} not done '
              '— finish anyway?'),
          content: const Text(
              'Unfinished sets stay in the workout but are not counted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      if (finishAnyway != true || !mounted) return;
    }

    final base = _baseWorkout();
    if (base == null && _currentWorkoutId != null) {
      // Existing workout that has not loaded yet: nothing safe to write.
      AnimatedFeedback.showSnackBar(
        context,
        'Workout is still loading, try again',
        backgroundColor: Colors.red,
      );
      return;
    }

    _isFinishing = true;
    // Finishing supersedes any pending autosave (and the one in dispose()).
    _autosaveTimer?.cancel();
    _autosaveTimer = null;

    final now = DateTime.now();
    DateTime? firstDone;
    for (final set in allSets) {
      final at = set.completedAt;
      if (set.isCompleted &&
          at != null &&
          (firstDone == null || at.isBefore(firstDone))) {
        firstDone = at;
      }
    }
    var start = _startedAt ?? firstDone;
    if (start != null && firstDone != null && firstDone.isBefore(start)) {
      start = firstDone;
    }
    final durationMinutes = start != null && !now.isBefore(start)
        ? max(1, now.difference(start).inMinutes)
        : null;

    final Workout finished;
    if (base != null) {
      finished = base.copyWith(
        name: _nameController.text,
        sets: allSets,
        isCompleted: true,
        completedDate: now,
        durationMinutes: durationMinutes,
      );
      _workoutBloc.add(WorkoutUpdateRequested(finished, silent: true));
    } else {
      finished = Workout.create(
        name: _nameController.text,
        scheduledDate: now,
        sets: allSets,
      ).copyWith(
        isCompleted: true,
        completedDate: now,
        durationMinutes: durationMinutes,
      );
      _currentWorkoutId = finished.id;
      _workoutBloc.add(WorkoutCreateRequested(finished, silent: true));
    }
    _persistedWorkout = finished;

    context.read<TimerBloc>().add(const TimerStopped());
    setState(() {
      _hasUnsavedChanges = false;
    });

    final allWorkouts = [
      ..._workoutBloc.state.workouts.where((w) => w.id != finished.id),
      finished,
    ];
    final exerciseNames = {
      for (final entry in _exercises.entries) entry.key: entry.value.name,
    };
    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutSummaryScreen(
          workout: finished,
          allWorkouts: allWorkouts,
          exerciseNames: exerciseNames,
          useMetric: _coach.useMetric,
          startedAt: start,
        ),
      ),
    ));
  }

  Future<void> _confirmDiscardChanges() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (shouldDiscard != true || !mounted) return;

    // Drop any pending autosave of the discarded edits and leave the screen.
    // Whatever was already autosaved/saved stays persisted.
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    setState(() {
      _hasUnsavedChanges = false;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscardChanges();
      },
      child: MultiBlocListener(
        listeners: [
          // Listen to TimerBloc for timer operations
          BlocListener<TimerBloc, TimerState>(
            listener: (context, state) {
              if (state.hasError) {
                AnimatedFeedback.showSnackBar(
                  context,
                  state.errorMessage!,
                  backgroundColor: Colors.red,
                );
              }

              // Handle timer completion
              if (state.isCompleted) {
                // Play sound if enabled in preferences
                if (!state.completedWhileBackgrounded &&
                    UserPreferencesService().getPlaySoundOnTimerEnd()) {
                  AudioPlayerUtil().playTimerEndSound();
                }
              }
            },
          ),
          // Listen to WorkoutBloc for workout operations
          BlocListener<WorkoutBloc, WorkoutState>(
            listener: (context, state) {
              if (state.hasError) {
                AnimatedFeedback.showSnackBar(
                  context,
                  state.errorMessage!,
                  backgroundColor: Colors.red,
                );
              } else if (state.hasSuccess) {
                // Other success messages (like workout save) - navigate back
                AnimatedFeedback.showSnackBar(
                  context,
                  state.successMessage!,
                  backgroundColor: Colors.green,
                );

                // Navigate back on successful save
                if (state.successMessage!.contains('successfully')) {
                  if (mounted) {
                    setState(() {
                      _hasUnsavedChanges = false;
                    });
                  }
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  try {
                    Navigator.of(context)
                        .pushReplacementNamed('/', arguments: 1);
                  } catch (e) {
                    AppLogger.error('Error during navigation', e);
                    Navigator.of(context).pop(true);
                  }
                }
              }

              // Update local state when workout is loaded
              if (!_hasUnsavedChanges &&
                  _persistedWorkout == null &&
                  state.currentWorkout != null &&
                  _currentWorkoutId == state.currentWorkout!.id) {
                // We need to get exercises from ExerciseBloc to update local state
                final exerciseState = context.read<ExerciseBloc>().state;
                if (exerciseState.exercises.isNotEmpty) {
                  _updateLocalStateFromWorkout(
                      state.currentWorkout!, exerciseState.exercises);
                } else {
                  // Load exercises if not already loaded
                  context
                      .read<ExerciseBloc>()
                      .add(const ExerciseLoadRequested());
                }
              }
            },
          ),
          // Listen to ExerciseBloc for exercise operations
          BlocListener<ExerciseBloc, ExerciseState>(
            listener: (context, state) {
              if (state.hasError) {
                AnimatedFeedback.showSnackBar(
                  context,
                  state.errorMessage!,
                  backgroundColor: Colors.red,
                );
              }

              // Update local state when exercises are loaded and we have a current workout
              if (!_hasUnsavedChanges &&
                  _persistedWorkout == null &&
                  state.exercises.isNotEmpty &&
                  _currentWorkoutId != null) {
                final workoutState = context.read<WorkoutBloc>().state;
                if (workoutState.currentWorkout != null) {
                  _updateLocalStateFromWorkout(
                      workoutState.currentWorkout!, state.exercises);
                }
              }
            },
          ),
        ],
        child: BlocBuilder<WorkoutBloc, WorkoutState>(
          builder: (context, workoutState) {
            return BlocBuilder<ExerciseBloc, ExerciseState>(
              builder: (context, exerciseState) {
                return BlocBuilder<TimerBloc, TimerState>(
                  builder: (context, timerState) {
                    final isLoading =
                        workoutState.isAnyLoading || exerciseState.isAnyLoading;

                    return Scaffold(
                      appBar: AppBar(
                        title: Row(
                          children: [
                            // Title (takes most of the space)
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isEditingTitle = true;
                                  });
                                  _titleFocusNode.requestFocus();
                                },
                                child: _isEditingTitle
                                    ? TextField(
                                        controller: _nameController,
                                        focusNode: _titleFocusNode,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        cursorColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          filled: true,
                                          fillColor: Colors.black
                                              .withValues(alpha: 0.2),
                                        ),
                                      )
                                    : Text(_nameController.text),
                              ),
                            ),
                          ],
                        ),
                        // No actions (removing the Save button)
                        actions: [],
                      ),
                      body: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Exercise sections
                                  ..._exercises.entries.map((entry) {
                                    final exerciseId = entry.key;
                                    final exercise = entry.value;
                                    final sets =
                                        _exerciseSets[exerciseId] ?? [];

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Exercise header with replace button
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _formatExerciseTitle(exercise),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.calculate_outlined),
                                              tooltip: 'Plate calculator',
                                              onPressed: () =>
                                                  _openPlateCalculator(
                                                      exerciseId),
                                            ),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.swap_horiz),
                                                tooltip: 'Replace Exercise',
                                                onPressed: () =>
                                                    _showExerciseReplacementSheet(
                                                        exerciseId),
                                                style: IconButton.styleFrom(
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .secondary,
                                                  foregroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSecondary,
                                                ),
                                              ),
                                          ],
                                        ),

                                        _buildCoachHint(context, exerciseId),

                                        const SizedBox(height: 4),
                                        _buildExerciseTools(context, exercise),

                                        if (_showExerciseDescription(
                                            exercise.description)) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            exercise.description!.trim(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],

                                        const SizedBox(height: 16),

                                        // Sets table header
                                        _buildSetsHeader(context),

                                        const Divider(),

                                        // Sets list for this exercise.
                                        // Swipe a row left to delete it.
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: sets.length,
                                          itemBuilder: (context, index) =>
                                              _buildSetRow(context, exerciseId,
                                                  index, sets[index]),
                                        ),

                                        if (sets.isEmpty)
                                          Center(
                                            child: TextButton.icon(
                                              onPressed: () =>
                                                  _removeExercise(exerciseId),
                                              icon: const Icon(
                                                  Icons.remove_circle_outline),
                                              label:
                                                  const Text('Remove exercise'),
                                            ),
                                          ),

                                        // Add set button for this exercise
                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _addSetForExercise(exerciseId),
                                            child: const Text('Add Set'),
                                          ),
                                        ),

                                        const SizedBox(height: 32),
                                      ],
                                    );
                                  }),

                                  // AI Reasoning section (if available)
                                  if (workoutState.currentWorkout?.notes !=
                                          null &&
                                      (workoutState.currentWorkout!.notes!
                                              .contains(
                                                  '🤖 AI WORKOUT REASONING') ||
                                          workoutState.currentWorkout!.notes!
                                              .contains(
                                                  '🧠 NEXT WORKOUT REASONING')))
                                    _buildAIReasoningSection(
                                        workoutState.currentWorkout!.notes!),

                                  // Add exercises button
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: _showExerciseSelectionSheet,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(200, 40),
                                      ),
                                      child: const Text('Add Exercises'),
                                    ),
                                  ),

                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                      bottomNavigationBar: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showRestTimerBar(timerState))
                            _buildRestTimerBar(context, timerState),
                          BottomAppBar(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: _buildActionBar(context, isLoading),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// CANCEL / SAVE, plus a primary FINISH once at least one set is done
  /// (SAVE then becomes secondary: save and leave without finishing).
  Widget _buildActionBar(BuildContext context, bool isLoading) {
    final canSave =
        !isLoading && (_hasUnsavedChanges || _persistedWorkout != null);
    final canFinish = !isLoading && !_isFinishing && _completedSetCount > 0;
    final cancel = TextButton(
      onPressed: _hasUnsavedChanges
          ? _confirmDiscardChanges
          : () => Navigator.pop(context),
      child: const Text('CANCEL'),
    );
    if (!canFinish) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          cancel,
          FilledButton(
            onPressed: canSave ? _saveWorkout : null,
            child: const Text('SAVE'),
          ),
        ],
      );
    }
    return Row(
      children: [
        cancel,
        const Spacer(),
        OutlinedButton(
          onPressed: canSave ? _saveWorkout : null,
          child: const Text('SAVE'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _finishWorkout,
          icon: const Icon(Icons.flag),
          label: const Text('FINISH'),
        ),
      ],
    );
  }

  /// "Last (Oct 28): 185×8, 185×8, 185×7" and a target chip under the
  /// exercise header. Tap the chip to show the coach's reasoning. Nothing is
  /// shown when the exercise has no history.
  Widget _buildCoachHint(BuildContext context, String exerciseId) {
    final hint = _coachHintFor(exerciseId);
    final last = hint.last;
    final target = hint.target;
    if (last == null && target == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final expanded = _expandedCoachHints.contains(exerciseId);

    Widget? chip;
    if (target != null) {
      final isDeload = target.reason == TargetReason.deload;
      final isIncrease = target.reason == TargetReason.increaseWeight ||
          target.reason == TargetReason.increaseReps;
      // Deload uses the calmer secondary palette; progress the primary one.
      final background = isDeload
          ? colorScheme.secondaryContainer
          : isIncrease
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest;
      final foreground = isDeload
          ? colorScheme.onSecondaryContainer
          : isIncrease
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant;
      final icon = isDeload
          ? Icons.spa_outlined
          : isIncrease
              ? Icons.trending_up
              : Icons.repeat;

      chip = Tooltip(
        message: target.message,
        child: Material(
          color: background,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() {
              if (!_expandedCoachHints.remove(exerciseId)) {
                _expandedCoachHints.add(exerciseId);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Target ${_formatTargetSet(target)} · '
                      '${_formatTargetDelta(target)}',
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(color: foreground),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: foreground),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (last != null)
            Text(
              'Last (${DateFormat.MMMd().format(last.date)}): '
              '${last.formatSets()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          if (chip != null) ...[
            const SizedBox(height: 6),
            chip,
          ],
          if (target != null && expanded) ...[
            const SizedBox(height: 6),
            Text(
              target.message,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  String get _unitShort => _coach.useMetric ? 'kg' : 'lb';

  String _formatTargetSet(ProgressionTarget target) => target.weight > 0
      ? '${_formatWeight(target.weight)}×${target.reps}'
      : '×${target.reps}';

  String _formatTargetDelta(ProgressionTarget target) {
    switch (target.reason) {
      case TargetReason.increaseWeight:
      case TargetReason.deload:
        final delta = target.weightDelta;
        final isDeload = target.reason == TargetReason.deload;
        if (delta == 0) return isDeload ? 'deload' : 'repeat';
        final sign = delta > 0 ? '+' : '−';
        final text = '$sign${_formatWeight(delta.abs())} $_unitShort';
        return isDeload ? 'deload $text' : text;
      case TargetReason.increaseReps:
        final reps = max(1, target.repsDelta);
        return '+$reps ${reps == 1 ? 'rep' : 'reps'}';
      case TargetReason.repeat:
        return 'repeat';
    }
  }

  Widget _buildSetsHeader(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(fontWeight: FontWeight.bold);
    return Row(
      children: [
        SizedBox(
          width: _setNumberWidth,
          child: Text('Set', textAlign: TextAlign.center, style: style),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(UserPreferencesService().getWeightUnitLabel(),
              textAlign: TextAlign.center, style: style),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Reps', textAlign: TextAlign.center, style: style),
        ),
        const SizedBox(width: 48), // Complete check column
      ],
    );
  }

  static const double _setNumberWidth = 40;

  /// One set: number, weight & reps fields (with -/+ steppers while the set
  /// is not completed) and a full-size complete check. Swipe left to delete.
  Widget _buildSetRow(
      BuildContext context, String exerciseId, int index, WorkoutSet set) {
    final colorScheme = Theme.of(context).colorScheme;
    final showSteppers = !set.isCompleted;
    final sets = _exerciseSets[exerciseId] ?? const <WorkoutSet>[];
    final warmup = set.isWarmup;
    final label = _setLabel(sets, index, set);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Set number (long-press also deletes, as an alternative to swipe)
          SizedBox(
            width: _setNumberWidth,
            height: 48,
            child: Material(
              color: warmup
                  ? colorScheme.surfaceContainerLow
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onLongPress: () => _deleteSet(exerciseId, index),
                child: Center(
                  child: Text(
                    warmup ? 'W' : '${_workingSetNumber(sets, index)}',
                    semanticsLabel: label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: warmup
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Weight
          Expanded(
            child: _buildNumberField(
              context,
              controller: _weightControllers[set.id] ??
                  TextEditingController(text: _formatWeight(set.weight)),
              decimal: true,
              semanticLabel: '$label weight',
              muted: warmup,
              onChanged: (value) {
                final weight = double.tryParse(value) ?? 0;
                _updateSetWeightForExercise(exerciseId, index, weight);
              },
              onDecrement: showSteppers
                  ? () => _stepWeight(exerciseId, index, -_weightStep)
                  : null,
              onIncrement: showSteppers
                  ? () => _stepWeight(exerciseId, index, _weightStep)
                  : null,
            ),
          ),
          const SizedBox(width: 8),

          // Reps
          Expanded(
            child: _buildNumberField(
              context,
              controller: _repsControllers[set.id] ??
                  TextEditingController(text: set.reps.toString()),
              decimal: false,
              semanticLabel: '$label reps',
              muted: warmup,
              onChanged: (value) {
                final reps = int.tryParse(value) ?? 0;
                _updateSetRepsForExercise(exerciseId, index, reps);
              },
              onDecrement:
                  showSteppers ? () => _stepReps(exerciseId, index, -1) : null,
              onIncrement:
                  showSteppers ? () => _stepReps(exerciseId, index, 1) : null,
            ),
          ),

          // Complete check (full 48dp target)
          IconButton(
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: set.isCompleted ? 'Mark set not done' : 'Complete set',
            icon: Icon(
              set.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
              color: set.isCompleted
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _toggleSetCompletionForExercise(exerciseId, index),
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey('set-${set.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteSet(exerciseId, index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete',
                style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
          ],
        ),
      ),
      child: row,
    );
  }

  /// A numeric text field with optional -/+ stepper buttons beneath it.
  Widget _buildNumberField(
    BuildContext context, {
    required TextEditingController controller,
    required bool decimal,
    required String semanticLabel,
    required ValueChanged<String> onChanged,
    VoidCallback? onDecrement,
    VoidCallback? onIncrement,
    bool muted = false,
  }) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    final field = Semantics(
      label: semanticLabel,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: decimal
            ? const [DecimalWeightInputFormatter()]
            : [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          isDense: true,
        ),
        style: muted
            ? textStyle?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)
            : textStyle,
        onChanged: onChanged,
      ),
    );
    if (onDecrement == null && onIncrement == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Decrease',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              visualDensity: VisualDensity.standard,
              onPressed: onDecrement,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Increase',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              visualDensity: VisualDensity.standard,
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }

  bool _showRestTimerBar(TimerState timer) =>
      timer.isRunning ||
      timer.isPaused ||
      (timer.isCompleted && timer.currentMotivationalPhrase != null);

  /// Rest timer pinned above the CANCEL/SAVE bar: large countdown, progress,
  /// -15s / +15s / Skip, and the motivational phrase once rest is over.
  Widget _buildRestTimerBar(BuildContext context, TimerState timer) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onColor = colorScheme.onPrimaryContainer;
    final timerBloc = context.read<TimerBloc>();
    final finished = timer.isCompleted && !timer.isRunning;

    return Material(
      color: colorScheme.primaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: finished ? 0 : timer.progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: colorScheme.primaryContainer,
            color: colorScheme.primary,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Icon(finished ? Icons.notifications_active : Icons.timer,
                    color: onColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        finished ? 'Rest over' : timer.formattedTime,
                        semanticsLabel: finished
                            ? 'Rest over'
                            : 'Rest time remaining ${timer.formattedTime}',
                        style: textTheme.headlineSmall?.copyWith(
                          color: onColor,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (timer.currentMotivationalPhrase != null)
                        Text(
                          timer.currentMotivationalPhrase!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: onColor),
                        ),
                    ],
                  ),
                ),
                if (!finished) ...[
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: onColor,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () =>
                        timerBloc.add(const TimerTimeSubtracted(15)),
                    child: const Text('−15s'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: onColor,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => timerBloc.add(const TimerTimeAdded(15)),
                    child: const Text('+15s'),
                  ),
                ],
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: onColor,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => timerBloc.add(const TimerStopped()),
                  child: Text(finished ? 'Dismiss' : 'Skip'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build AI reasoning section widget
  Widget _buildAIReasoningSection(String aiReasoning) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.smart_toy, color: Colors.teal),
        title: const Text(
          'AI Workout Reasoning',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Tap to see why AI chose these exercises'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Text(
                aiReasoning,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Coach data for one exercise: its last session and next target (both null
/// when the exercise has no history).
class _CoachHint {
  final SessionSummary? last;
  final ProgressionTarget? target;

  const _CoachHint({this.last, this.target});
}

/// Allows a decimal weight: digits with at most one decimal separator and up
/// to two decimals. A ',' (as typed on many European keypads) is normalised to
/// '.'.
class DecimalWeightInputFormatter extends TextInputFormatter {
  const DecimalWeightInputFormatter();

  static final RegExp _pattern = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final normalised = newValue.text.replaceAll(',', '.');
    if (!_pattern.hasMatch(normalised)) return oldValue;
    // Same length, so the selection stays valid.
    return newValue.copyWith(text: normalised);
  }
}
