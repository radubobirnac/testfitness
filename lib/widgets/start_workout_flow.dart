import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/screens/routines_screen.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/ai_workout_generator.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';
import 'package:testfitness/widgets/workout_split_picker.dart';

/// The shared "Start workout" flow used by the Home and Workouts tabs:
/// [showStartWorkoutFlow] opens [StartWorkoutSheet] and runs whatever the
/// user picks (empty workout, muscle-group split, coach's next workout,
/// AI build, or a saved routine).

// Only one generation runs at a time, app-wide (the sheet shows a spinner
// on the busy option and disables it).
bool _isGeneratingNext = false;
bool _isGeneratingAi = false;

const List<String> _aiFocusOptions = [
  'Full Body',
  'Upper',
  'Lower',
  'Push',
  'Pull',
  'Legs',
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Core',
];

/// Opens the start sheet and runs the chosen option.
///
/// [workouts] is the history used by the coach / AI / routine builders;
/// defaults to the current [WorkoutBloc] state when the sheet closes.
/// [isAiAvailable] overrides `AIService().isAvailable` (tests).
Future<void> showStartWorkoutFlow(
  BuildContext context, {
  List<Workout>? workouts,
  bool Function()? isAiAvailable,
  RoutineRepository? routineRepository,
}) async {
  HapticFeedback.selectionClick();
  final repository = routineRepository ?? RoutineRepository();
  List<Routine> routines = const [];
  try {
    routines = await repository.getRoutines();
  } catch (e) {
    AppLogger.warning('Could not load routines for start sheet', e);
  }
  if (!context.mounted) return;
  final showAi = (isAiAvailable ?? () => AIService().isAvailable)();

  final selection = await showModalBottomSheet<StartWorkoutSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StartWorkoutSheet(
      showAi: showAi,
      routines: routines,
      isGeneratingNext: _isGeneratingNext,
      isGeneratingAi: _isGeneratingAi,
    ),
  );
  if (!context.mounted || selection == null) return;

  final history = workouts ?? context.read<WorkoutBloc>().state.workouts;
  switch (selection.option) {
    case StartWorkoutOption.empty:
      startEmptyWorkout(context);
    case StartWorkoutOption.muscleGroup:
      openWorkoutSplitPicker(context, history);
    case StartWorkoutOption.coachNext:
      _createNextWorkout(context, history);
    case StartWorkoutOption.aiBuild:
      _createAiWorkout(context, history);
    case StartWorkoutOption.routine:
      final routine = selection.routine;
      if (routine != null) {
        startRoutine(context, routine, history, repository: repository);
      }
  }
}

/// Opens the editor for a new (unsaved) workout dated today. It is
/// persisted by autosave on the first completed set, so backing out does
/// not leave an empty workout behind.
Future<void> startEmptyWorkout(BuildContext context) async {
  final bloc = context.read<WorkoutBloc>();
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ExerciseDetailScreen()),
  );
  if (!bloc.isClosed) bloc.add(const WorkoutLoadRequested());
}

/// Creates [workout] and opens it in the editor; reloads on return.
Future<void> _createAndOpen(BuildContext context, Workout workout) async {
  final bloc = context.read<WorkoutBloc>();
  bloc.add(WorkoutCreateRequested(workout));
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          ExerciseDetailScreen.editWorkout(workoutId: workout.id),
    ),
  );
  if (!bloc.isClosed) bloc.add(const WorkoutLoadRequested());
}

/// Shows a blocking progress dialog; returns the navigator to pop it with.
NavigatorState _showProgressDialog(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: Gap.lg),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  return navigator;
}

void _hideProgressDialog(NavigatorState navigator) {
  if (navigator.mounted && navigator.canPop()) navigator.pop();
}

Future<Workout> _buildNextWorkout(
    BuildContext context, List<Workout> workouts) async {
  try {
    final aiService = AIService();
    if (aiService.isAvailable) {
      return await AIWorkoutGenerator().generateAIWorkout(
        workoutName: 'Next Workout',
        recentWorkouts: workouts,
        lookbackDays: 14,
      );
    }
    final reason = aiService.unavailableReason;
    final workout = await _coachNextWorkout(workouts);
    if (context.mounted) {
      AnimatedFeedback.showSnackBar(
        context,
        '${reason ?? 'AI unavailable.'} Your coach built this workout from your history.',
      );
    }
    return workout;
  } catch (error) {
    AppLogger.warning('AI generation failed, falling back', error);
    final workout = await _coachNextWorkout(workouts);
    if (context.mounted) {
      AnimatedFeedback.showSnackBar(
        context,
        'AI failed. Your coach built this workout from your history.',
      );
    }
    return workout;
  }
}

Future<void> _createNextWorkout(
    BuildContext context, List<Workout> workouts) async {
  if (_isGeneratingNext) return;
  _isGeneratingNext = true;
  final progress = _showProgressDialog(
      context, 'Your coach is building your next workout...');

  Workout? workout;
  try {
    workout = await _buildNextWorkout(context, workouts);
  } catch (error) {
    AppLogger.error('Could not create next workout', error);
    if (context.mounted) {
      AnimatedFeedback.showError(
          context, 'Could not create a workout. Please try again.');
    }
  } finally {
    _hideProgressDialog(progress);
    _isGeneratingNext = false;
  }

  if (!context.mounted || workout == null) return;
  await _createAndOpen(context, workout);
}

Future<Workout> _buildAiWorkout(
    BuildContext context, String focus, List<Workout> workouts) async {
  try {
    final aiService = AIService();
    if (!aiService.isAvailable) {
      throw Exception('AI unavailable');
    }
    return await AIWorkoutGenerator().generateAiWorkout(
      workoutName: 'AI Build - $focus',
      focus: _formatFocusForPrompt(focus),
      recentWorkouts: workouts,
      lookbackDays: 21,
      maxRecentWorkouts: 6,
    );
  } catch (error) {
    AppLogger.warning('AI build failed, using fallback', error);
    final reason = AIService().unavailableReason;
    final workout = await _focusWorkoutFallback(focus);
    if (context.mounted) {
      AnimatedFeedback.showSnackBar(
        context,
        '${reason ?? 'AI unavailable.'} Created a rules-based workout.',
      );
    }
    return workout;
  }
}

Future<void> _createAiWorkout(
    BuildContext context, List<Workout> workouts) async {
  if (_isGeneratingAi) return;
  final focus = await _showFocusPicker(context);
  if (!context.mounted || focus == null) return;

  _isGeneratingAi = true;
  final progress =
      _showProgressDialog(context, 'AI is building your workout...');

  Workout? workout;
  try {
    workout = await _buildAiWorkout(context, focus, workouts);
  } catch (error) {
    AppLogger.error('Could not create AI workout', error);
    if (context.mounted) {
      AnimatedFeedback.showError(
          context, 'Could not create a workout. Please try again.');
    }
  } finally {
    _hideProgressDialog(progress);
    _isGeneratingAi = false;
  }

  if (!context.mounted || workout == null) return;
  await _createAndOpen(context, workout);
}

Future<Workout> _coachNextWorkout(List<Workout> workouts) async {
  final allExercises = await ExerciseRepository().getExercises();
  final coach = ProgressionCoach(
    useMetric: UserPreferencesService().getUseMetricUnits(),
  );
  return coach.suggestNextWorkout(workouts, allExercises,
      preferences: WorkoutPreferences.fromMap(
          UserPreferencesService().getWorkoutPreferences()));
}

List<String> _normalizeMuscleGroups(String? muscleGroup) {
  if (muscleGroup == null || muscleGroup.trim().isEmpty) return [];
  return muscleGroup
      .split(',')
      .map((group) => group.trim().toLowerCase())
      .where((group) => group.isNotEmpty)
      .toList();
}

Future<Workout> _focusWorkoutFallback(String focus) async {
  final allExercises = await ExerciseRepository().getExercises();
  final focusTargets = _focusTargetsForFallback(focus);

  List<String> exerciseTags(Exercise exercise) => [
        ..._normalizeMuscleGroups(exercise.muscleGroup),
        ..._normalizeMuscleGroups(exercise.category),
        exercise.name.toLowerCase(),
      ];

  var candidates = List.of(allExercises);
  if (focusTargets.isNotEmpty) {
    candidates = allExercises.where((exercise) {
      final tags = exerciseTags(exercise);
      return tags.any(
          (tag) => focusTargets.any((focusTarget) => tag.contains(focusTarget)));
    }).toList();
  }
  if (candidates.isEmpty) {
    candidates = List.of(allExercises);
  }

  candidates.shuffle(Random());
  final selected = candidates.take(5).toList();

  final sets = selected
      .map((exercise) => WorkoutSet.create(
            exerciseId: exercise.id,
            reps: 8,
            weight: 0,
            isCompleted: false,
          ))
      .toList();

  final notes = StringBuffer()
    ..writeln('AI build fallback used.')
    ..writeln('Focus: $focus')
    ..writeln('Selected ${selected.length} exercises from focus groups.');

  return Workout(
    id: 'workout_${DateTime.now().millisecondsSinceEpoch}',
    name: 'AI Build - $focus',
    sets: sets,
    scheduledDate: DateTime.now(),
    isCompleted: false,
    notes: notes.toString(),
  );
}

List<String> _focusTargetsForFallback(String focus) {
  final normalized = focus.toLowerCase();
  if (normalized.contains('full')) return [];
  if (normalized.contains('upper')) {
    return ['chest', 'back', 'shoulder', 'arm'];
  }
  if (normalized.contains('lower')) {
    return ['leg', 'quad', 'hamstring', 'glute'];
  }
  if (normalized.contains('push')) return ['chest', 'shoulder', 'tricep'];
  if (normalized.contains('pull')) return ['back', 'bicep'];
  if (normalized.contains('legs')) {
    return ['leg', 'quad', 'hamstring', 'glute'];
  }
  if (normalized.contains('chest')) return ['chest', 'pec'];
  if (normalized.contains('back')) return ['back', 'lat'];
  if (normalized.contains('shoulders')) return ['shoulder', 'deltoid'];
  if (normalized.contains('arms')) return ['arm', 'bicep', 'tricep'];
  if (normalized.contains('core')) return ['core', 'abs'];
  return [];
}

String _formatFocusForPrompt(String focus) {
  switch (focus) {
    case 'Full Body':
      return 'full body';
    case 'Upper':
      return 'upper body';
    case 'Lower':
      return 'lower body';
    default:
      return focus.toLowerCase();
  }
}

Future<String?> _showFocusPicker(BuildContext context) {
  var selected = _aiFocusOptions.first;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('AI Workout Focus'),
      content: StatefulBuilder(
        builder: (context, setModalState) => Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: _aiFocusOptions.map((option) {
            return ChoiceChip(
              label: Text(option),
              selected: selected == option,
              onSelected: (isSelected) {
                if (!isSelected) return;
                setModalState(() => selected = option);
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selected),
          child: const Text('Build'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Start a workout sheet
// ---------------------------------------------------------------------------

enum StartWorkoutOption { empty, muscleGroup, coachNext, aiBuild, routine }

/// What the user picked in [StartWorkoutSheet].
class StartWorkoutSelection {
  const StartWorkoutSelection(this.option, {this.routine});

  final StartWorkoutOption option;

  /// Set when [option] is [StartWorkoutOption.routine].
  final Routine? routine;
}

/// The single "Start workout" entry point: empty workout, muscle-group
/// split, coach's next workout, AI build (only when [showAi]) and saved
/// routines. Pops a [StartWorkoutSelection].
class StartWorkoutSheet extends StatelessWidget {
  const StartWorkoutSheet({
    super.key,
    required this.showAi,
    required this.routines,
    this.isGeneratingNext = false,
    this.isGeneratingAi = false,
  });

  final bool showAi;
  final List<Routine> routines;
  final bool isGeneratingNext;
  final bool isGeneratingAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    void pick(StartWorkoutOption option, {Routine? routine}) =>
        Navigator.of(context)
            .pop(StartWorkoutSelection(option, routine: routine));

    Widget busyOr(IconData icon, bool busy) => busy
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
            child: Text('Start a workout', style: theme.textTheme.titleLarge),
          ),
          ListTile(
            key: const Key('start_sheet_empty'),
            leading: const Icon(Icons.edit_note),
            title: const Text('Empty workout'),
            subtitle: const Text('Log as you go'),
            onTap: () => pick(StartWorkoutOption.empty),
          ),
          ListTile(
            key: const Key('workouts_choose_split'),
            leading: const Icon(Icons.accessibility_new),
            title: const Text('Choose by muscle group'),
            subtitle: const Text('Back & biceps, legs, …'),
            onTap: () => pick(StartWorkoutOption.muscleGroup),
          ),
          ListTile(
            key: const Key('start_sheet_next'),
            enabled: !isGeneratingNext,
            leading: busyOr(Icons.auto_awesome, isGeneratingNext),
            title: const Text("Coach's next workout"),
            subtitle: Text(isGeneratingNext
                ? 'Creating your next workout…'
                : 'Based on your recent training'),
            onTap: () => pick(StartWorkoutOption.coachNext),
          ),
          if (showAi)
            ListTile(
              key: const Key('start_sheet_ai'),
              enabled: !isGeneratingAi,
              leading: busyOr(Icons.auto_awesome_outlined, isGeneratingAi),
              title: const Text('AI build'),
              subtitle: Text(isGeneratingAi
                  ? 'Building your AI workout…'
                  : 'Pick a focus, AI builds the session'),
              onTap: () => pick(StartWorkoutOption.aiBuild),
            ),
          const Divider(indent: Gap.lg, endIndent: Gap.lg),
          const SectionHeader('From a routine'),
          if (routines.isEmpty)
            ListTile(
              key: const Key('start_sheet_no_routines'),
              leading: Icon(Icons.bookmark_border,
                  color: colorScheme.onSurfaceVariant),
              title: const Text('No routines yet'),
              subtitle:
                  const Text('Save a workout as a routine from its ⋮ menu'),
            )
          else
            for (final routine in routines)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(routine.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(describeRoutine(routine),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () =>
                    pick(StartWorkoutOption.routine, routine: routine),
              ),
        ],
      ),
    );
  }
}
