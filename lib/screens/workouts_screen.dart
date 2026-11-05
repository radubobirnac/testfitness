import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/screens/routines_screen.dart';
import 'package:testfitness/screens/workout_calendar_screen.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/ai_workout_generator.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';
import 'package:testfitness/widgets/workout_card_skeleton.dart';
import 'package:testfitness/widgets/workout_split_picker.dart';

// ---------------------------------------------------------------------------
// Pure helpers (grouping, sorting, formatting). Kept top-level so they can be
// unit-tested without pumping the screen.
// ---------------------------------------------------------------------------

/// List filter on the Workouts tab. Planned = not completed, Done = completed.
enum WorkoutFilter { all, planned, done }

int _extractTimestampFromId(String id) {
  try {
    if (id.startsWith('workout_')) {
      final timestampStr = id.substring(8);
      return int.tryParse(timestampStr) ?? 0;
    }
    return id.hashCode;
  } catch (e) {
    return 0;
  }
}

/// The date shown on (and used to sort) a workout: completion date for
/// finished workouts, otherwise the scheduled date, falling back to the
/// timestamp encoded in legacy `workout_<millis>` ids.
DateTime workoutDisplayDate(Workout workout) {
  if (workout.isCompleted && workout.completedDate != null) {
    return workout.completedDate!;
  }
  if (workout.scheduledDate != null) {
    return workout.scheduledDate!;
  }
  if (workout.completedDate != null) {
    return workout.completedDate!;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    _extractTimestampFromId(workout.id),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Not completed and scheduled before today.
bool isWorkoutOverdue(Workout workout, DateTime now) {
  final scheduled = workout.scheduledDate;
  if (workout.isCompleted || scheduled == null) return false;
  return _dateOnly(scheduled).isBefore(_dateOnly(now));
}

/// Sorted copy by [workoutDisplayDate].
List<Workout> sortWorkouts(List<Workout> workouts, {bool newestFirst = true}) {
  final sorted = List<Workout>.from(workouts);
  sorted.sort((a, b) {
    final dateA = workoutDisplayDate(a).millisecondsSinceEpoch;
    final dateB = workoutDisplayDate(b).millisecondsSinceEpoch;
    return newestFirst ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
  });
  return sorted;
}

/// Group label for a finished workout: "This week" / "Last week" (weeks start
/// on Monday) or the month, e.g. "October 2026".
String completedGroupLabel(DateTime date, DateTime now) {
  final today = _dateOnly(now);
  final thisWeek = DateTime(today.year, today.month, today.day - (today.weekday - 1));
  final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);
  if (!date.isBefore(thisWeek)) return 'This week';
  if (!date.isBefore(lastWeek)) return 'Last week';
  return DateFormat('MMMM y').format(date);
}

/// A titled run of workouts in the list.
class WorkoutSection {
  const WorkoutSection(this.title, this.workouts);

  final String title;
  final List<Workout> workouts;

  @override
  String toString() => 'WorkoutSection($title, ${workouts.length})';
}

const String kPlannedSectionTitle = 'Planned';

/// Splits [workouts] into sections: "Planned" (not completed, incl. overdue)
/// first, then finished workouts by "This week", "Last week" and month.
/// Order within and between the finished groups follows [newestFirst].
List<WorkoutSection> groupWorkoutsIntoSections(
  List<Workout> workouts, {
  required DateTime now,
  WorkoutFilter filter = WorkoutFilter.all,
  bool newestFirst = true,
}) {
  final sorted = sortWorkouts(workouts, newestFirst: newestFirst);
  final sections = <WorkoutSection>[];

  if (filter != WorkoutFilter.done) {
    final planned = sorted.where((w) => !w.isCompleted).toList();
    if (planned.isNotEmpty) {
      sections.add(WorkoutSection(kPlannedSectionTitle, planned));
    }
  }

  if (filter != WorkoutFilter.planned) {
    // Insertion-ordered, so group order follows the sort order.
    final groups = <String, List<Workout>>{};
    for (final workout in sorted.where((w) => w.isCompleted)) {
      final label = completedGroupLabel(workoutDisplayDate(workout), now);
      groups.putIfAbsent(label, () => []).add(workout);
    }
    groups.forEach((label, items) => sections.add(WorkoutSection(label, items)));
  }

  return sections;
}

/// Working volume (weight x reps) of completed, non-warm-up sets.
double workoutVolume(Workout workout) {
  var total = 0.0;
  for (final set in workout.sets) {
    if (set.isWarmup || !set.isCompleted) continue;
    total += set.weight * set.reps;
  }
  return total;
}

/// "5 exercises · 15 sets · Thu, Nov 5" plus " · 12,400 kg" when [volume]
/// is given and positive.
/// Short card date, e.g. "Thu, Nov 5".
String formatWorkoutDate(DateTime date) => DateFormat('EEE, MMM d').format(date);

String formatWorkoutMeta({
  required int exerciseCount,
  required int setCount,
  required DateTime date,
  double? volume,
  String unitLabel = 'kg',
  bool includeDate = true,
}) {
  final parts = <String>[
    '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
    '$setCount ${setCount == 1 ? 'set' : 'sets'}',
    if (includeDate) formatWorkoutDate(date),
  ];
  if (volume != null && volume > 0) {
    parts.add('${NumberFormat.decimalPattern().format(volume.round())} '
        '$unitLabel');
  }
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({
    super.key,
    this.isAiAvailable,
    this.routineRepository,
    this.clock,
  });

  /// Overrides the AI availability check (tests). Defaults to
  /// `AIService().isAvailable`.
  final bool Function()? isAiAvailable;

  /// Routine storage (tests). Defaults to [RoutineRepository].
  final RoutineRepository? routineRepository;

  /// "Now" used for grouping (tests). Defaults to [DateTime.now].
  final DateTime Function()? clock;

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  static const List<String> _aiFocusOptions = [
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
  static const String _importedFromCsvLabel = 'Imported from CSV';

  late final RoutineRepository _routineRepository =
      widget.routineRepository ?? RoutineRepository();

  bool _newestFirst = true;
  WorkoutFilter _filter = WorkoutFilter.all;
  bool _fabExtended = true;
  bool _isGeneratingNext = false;
  bool _isGeneratingAi = false;

  /// Navigator showing the blocking progress dialog, if any.
  NavigatorState? _progressNavigator;

  @override
  void initState() {
    super.initState();

    // Load workouts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
    });
  }

  void _onSortChanged(bool newestFirst) {
    AppLogger.debug(
        'Changing workout sort to: ${newestFirst ? 'Newest' : 'Oldest'}');
    setState(() {
      _newestFirst = newestFirst;
    });
  }

  void _showProgressDialog(String message) {
    _progressNavigator = Navigator.of(context, rootNavigator: true);
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
  }

  void _hideProgressDialog() {
    final navigator = _progressNavigator;
    _progressNavigator = null;
    if (navigator != null && navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }

  void _openEditorFor(Workout workout) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseDetailScreen.editWorkout(
          workoutId: workout.id,
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
      }
    });
  }

  Future<Workout> _buildNextWorkout(WorkoutState state) async {
    try {
      final aiService = AIService();
      if (aiService.isAvailable) {
        final aiGenerator = AIWorkoutGenerator();
        return await aiGenerator.generateAIWorkout(
          workoutName: 'Next Workout',
          recentWorkouts: state.workouts,
          lookbackDays: 14,
        );
      }
      final reason = aiService.unavailableReason;
      final workout = await _generateNextWorkoutFallback(state.workouts);
      if (mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          '${reason ?? 'AI unavailable.'} Your coach built this workout from your history.',
          backgroundColor: Colors.orange,
        );
      }
      return workout;
    } catch (error) {
      AppLogger.warning('AI generation failed, falling back', error);
      final workout = await _generateNextWorkoutFallback(state.workouts);
      if (mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          'AI failed. Your coach built this workout from your history.',
          backgroundColor: Colors.orange,
        );
      }
      return workout;
    }
  }

  Future<void> _createNextWorkout(WorkoutState state) async {
    if (_isGeneratingNext) return;
    setState(() {
      _isGeneratingNext = true;
    });
    _showProgressDialog('Your coach is building your next workout...');

    Workout? workout;
    try {
      workout = await _buildNextWorkout(state);
    } catch (error) {
      AppLogger.error('Could not create next workout', error);
      if (mounted) {
        AnimatedFeedback.showError(
            context, 'Could not create a workout. Please try again.');
      }
    } finally {
      _hideProgressDialog();
      if (mounted) {
        setState(() {
          _isGeneratingNext = false;
        });
      }
    }

    if (!mounted || workout == null) return;
    context.read<WorkoutBloc>().add(WorkoutCreateRequested(workout));
    _openEditorFor(workout);
  }

  Future<Workout> _buildAiWorkout(String focus, WorkoutState state) async {
    try {
      final aiService = AIService();
      if (!aiService.isAvailable) {
        throw Exception('AI unavailable');
      }

      final aiGenerator = AIWorkoutGenerator();
      final normalizedFocus = _formatFocusForPrompt(focus);
      return await aiGenerator.generateAiWorkout(
        workoutName: 'AI Build - $focus',
        focus: normalizedFocus,
        recentWorkouts: state.workouts,
        lookbackDays: 21,
        maxRecentWorkouts: 6,
      );
    } catch (error) {
      AppLogger.warning('AI build failed, using fallback', error);
      final reason = AIService().unavailableReason;
      final workout = await _generateFocusWorkoutFallback(focus, state.workouts);
      if (mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          '${reason ?? 'AI unavailable.'} Created a rules-based workout.',
          backgroundColor: Colors.orange,
        );
      }
      return workout;
    }
  }

  Future<void> _createAiWorkout(WorkoutState state) async {
    if (_isGeneratingAi) return;
    final focus = await _showFocusPicker(context);
    if (!mounted || focus == null) return;

    setState(() {
      _isGeneratingAi = true;
    });
    _showProgressDialog('AI is building your workout...');

    Workout? workout;
    try {
      workout = await _buildAiWorkout(focus, state);
    } catch (error) {
      AppLogger.error('Could not create AI workout', error);
      if (mounted) {
        AnimatedFeedback.showError(
            context, 'Could not create a workout. Please try again.');
      }
    } finally {
      _hideProgressDialog();
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
      }
    }

    if (!mounted || workout == null) return;
    context.read<WorkoutBloc>().add(WorkoutCreateRequested(workout));
    _openEditorFor(workout);
  }

  List<String> _normalizeMuscleGroups(String? muscleGroup) {
    if (muscleGroup == null || muscleGroup.trim().isEmpty) return [];
    return muscleGroup
        .split(',')
        .map((group) => group.trim().toLowerCase())
        .where((group) => group.isNotEmpty)
        .toList();
  }

  Future<Workout> _generateNextWorkoutFallback(List<Workout> workouts) async {
    final exerciseRepository = ExerciseRepository();
    final allExercises = await exerciseRepository.getExercises();
    final coach = ProgressionCoach(
      useMetric: UserPreferencesService().getUseMetricUnits(),
    );
    return coach.suggestNextWorkout(workouts, allExercises,
        preferences: WorkoutPreferences.fromMap(
            UserPreferencesService().getWorkoutPreferences()));
  }

  Future<Workout> _generateFocusWorkoutFallback(
    String focus,
    List<Workout> workouts,
  ) async {
    final exerciseRepository = ExerciseRepository();
    final allExercises = await exerciseRepository.getExercises();
    final focusTargets = _focusTargetsForFallback(focus);

    List<String> exerciseTags(Exercise exercise) {
      final tags = <String>[];
      tags.addAll(_normalizeMuscleGroups(exercise.muscleGroup));
      tags.addAll(_normalizeMuscleGroups(exercise.category));
      tags.add(exercise.name.toLowerCase());
      return tags;
    }

    var candidates = allExercises;
    if (focusTargets.isNotEmpty) {
      candidates = allExercises.where((exercise) {
        final tags = exerciseTags(exercise);
        return tags.any((tag) =>
            focusTargets.any((focusTarget) => tag.contains(focusTarget)));
      }).toList();
    }

    if (candidates.isEmpty) {
      candidates = allExercises;
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
    if (normalized.contains('full')) {
      return [];
    }
    if (normalized.contains('upper')) {
      return ['chest', 'back', 'shoulder', 'arm'];
    }
    if (normalized.contains('lower')) {
      return ['leg', 'quad', 'hamstring', 'glute'];
    }
    if (normalized.contains('push')) {
      return ['chest', 'shoulder', 'tricep'];
    }
    if (normalized.contains('pull')) {
      return ['back', 'bicep'];
    }
    if (normalized.contains('legs')) {
      return ['leg', 'quad', 'hamstring', 'glute'];
    }
    if (normalized.contains('chest')) {
      return ['chest', 'pec'];
    }
    if (normalized.contains('back')) {
      return ['back', 'lat'];
    }
    if (normalized.contains('shoulders')) {
      return ['shoulder', 'deltoid'];
    }
    if (normalized.contains('arms')) {
      return ['arm', 'bicep', 'tricep'];
    }
    if (normalized.contains('core')) {
      return ['core', 'abs'];
    }
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
            spacing: 8.0,
            runSpacing: 8.0,
            children: _aiFocusOptions.map((option) {
              return ChoiceChip(
                label: Text(option),
                selected: selected == option,
                onSelected: (isSelected) {
                  if (!isSelected) return;
                  setModalState(() {
                    selected = option;
                  });
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

  /// Pull-to-refresh: reloads and waits (bounded) for the load to finish.
  Future<void> _onRefreshPressed() async {
    AppLogger.debug('Refreshing workouts');
    final bloc = context.read<WorkoutBloc>();
    bloc.add(const WorkoutLoadRequested());
    try {
      await bloc.stream
          .firstWhere((s) => !s.isLoading)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Timed out or the bloc closed; the spinner just stops.
    }
  }

  void _startEmptyWorkout() {
    // Open the editor for a new (unsaved) workout dated today.
    // It is persisted by autosave on the first completed set, so
    // backing out does not leave an empty workout behind.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseDetailScreen(),
      ),
    ).then((_) {
      // Reload workouts after returning
      if (mounted) {
        context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
      }
    });
  }

  Future<void> _openStartSheet() async {
    HapticFeedback.selectionClick();
    List<Routine> routines = const [];
    try {
      routines = await _routineRepository.getRoutines();
    } catch (e) {
      AppLogger.warning('Could not load routines for start sheet', e);
    }
    if (!mounted) return;
    final showAi = (widget.isAiAvailable ?? () => AIService().isAvailable)();

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
    if (!mounted || selection == null) return;

    final workouts = context.read<WorkoutBloc>().state;
    switch (selection.option) {
      case StartWorkoutOption.empty:
        _startEmptyWorkout();
      case StartWorkoutOption.muscleGroup:
        openWorkoutSplitPicker(context, workouts.workouts);
      case StartWorkoutOption.coachNext:
        _createNextWorkout(workouts);
      case StartWorkoutOption.aiBuild:
        _createAiWorkout(workouts);
      case StartWorkoutOption.routine:
        final routine = selection.routine;
        if (routine != null) {
          startRoutine(context, routine, workouts.workouts,
              repository: _routineRepository);
        }
    }
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final extended = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _fabExtended,
    };
    if (extended != _fabExtended) {
      setState(() => _fabExtended = extended);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WorkoutBloc, WorkoutState>(
      listener: (context, state) {
        // Show success messages with enhanced feedback
        if (state.hasSuccess) {
          HapticFeedback.lightImpact();
          AnimatedFeedback.showSuccess(context, state.successMessage!);
        }

        // Show error messages with enhanced feedback
        if (state.hasError) {
          HapticFeedback.heavyImpact();
          AnimatedFeedback.showError(context, state.errorMessage!);
        }
      },
      child: BlocBuilder<WorkoutBloc, WorkoutState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Workouts'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Calendar',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkoutCalendarScreen(),
                    ),
                  ),
                ),
                PopupMenuButton<bool>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort',
                  onSelected: _onSortChanged,
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: true,
                      checked: _newestFirst,
                      child: const Text('Newest first'),
                    ),
                    CheckedPopupMenuItem(
                      value: false,
                      checked: !_newestFirst,
                      child: const Text('Oldest first'),
                    ),
                  ],
                ),
              ],
            ),
            // Skeleton only on the first load; later reloads (pull to
            // refresh, returning from the editor) keep the list on screen.
            body: state.isLoading && state.workouts.isEmpty
                ? _buildLoadingState()
                : _buildList(context, state),
            floatingActionButton: FloatingActionButton.extended(
              key: const Key('workouts_start_fab'),
              tooltip: 'Start workout',
              isExtended: _fabExtended,
              onPressed: _openStartSheet,
              icon: const Icon(Icons.add),
              label: const Text('Start workout'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, WorkoutState state) {
    final now = (widget.clock ?? DateTime.now)();
    final sections = groupWorkoutsIntoSections(
      state.workouts,
      now: now,
      filter: _filter,
      newestFirst: _newestFirst,
    );
    // Flattened: a String is a section header, a Workout is a card.
    final entries = <Object>[
      for (final section in sections) ...[section.title, ...section.workouts],
    ];
    final unitLabel =
        UserPreferencesService().getWeightUnitLabel().toLowerCase();

    return NotificationListener<UserScrollNotification>(
      onNotification: _onUserScroll,
      child: RefreshIndicator(
        onRefresh: _onRefreshPressed,
        child: CustomScrollView(
          key: const PageStorageKey('workouts_scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildFilterRow()),
            SliverToBoxAdapter(
              child: RoutinesStrip(
                workouts: state.workouts,
                repository: _routineRepository,
              ),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    if (entry is String) return SectionHeader(entry);
                    return _buildCard(
                        context, entry as Workout, now, unitLabel);
                  },
                  childCount: entries.length,
                ),
              ),
            // Keep the last card clear of the FAB.
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SegmentedButton<WorkoutFilter>(
          key: const Key('workouts_filter'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: WorkoutFilter.all, label: Text('All')),
            ButtonSegment(
                value: WorkoutFilter.planned, label: Text('Planned')),
            ButtonSegment(value: WorkoutFilter.done, label: Text('Done')),
          ],
          selected: {_filter},
          onSelectionChanged: (selection) =>
              setState(() => _filter = selection.first),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (IconData icon, String title, String hint) = switch (_filter) {
      WorkoutFilter.all => (
          Icons.fitness_center,
          'No workouts yet',
          'Tap Start workout to log your first one',
        ),
      WorkoutFilter.planned => (
          Icons.event_available,
          'No planned workouts',
          'Tap Start workout to plan one',
        ),
      WorkoutFilter.done => (
          Icons.check_circle_outline,
          'No finished workouts yet',
          'Completed workouts show up here',
        ),
    };
    return Padding(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: Gap.lg),
          Text(title,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Workout workout,
    DateTime now,
    String unitLabel,
  ) {
    return WorkoutListCard(
      key: ValueKey('workout_card_${workout.id}'),
      workout: workout,
      exerciseCount: workout.exerciseIds.length,
      displayDate: workoutDisplayDate(workout),
      isOverdue: isWorkoutOverdue(workout, now),
      weightUnitLabel: unitLabel,
      showDescription: workout.description != null &&
          workout.description!.trim().isNotEmpty &&
          workout.description != _importedFromCsvLabel,
      onTap: () {
        // Navigate to the workout editing screen instead of detail view
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ExerciseDetailScreen.editWorkout(
              workoutId: workout.id,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
        ).then((_) {
          // Reload workouts after returning
          if (context.mounted) {
            context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
          }
        });
      },
      onToggleComplete: () {
        if (workout.isCompleted) {
          // Uncomplete workout by updating it
          final updatedWorkout = Workout(
            id: workout.id,
            name: workout.name,
            description: workout.description,
            scheduledDate: workout.scheduledDate,
            completedDate: null,
            isCompleted: false,
            sets: workout.sets,
            durationMinutes: workout.durationMinutes,
            notes: workout.notes,
          );
          context.read<WorkoutBloc>().add(
                WorkoutUpdateRequested(updatedWorkout),
              );
        } else {
          // Complete workout using BLoC
          context.read<WorkoutBloc>().add(
                WorkoutCompleteRequested(workout.id),
              );
        }
      },
      onRepeat: () {
        // Duplicate the workout using BLoC
        context.read<WorkoutBloc>().add(
              WorkoutDuplicateRequested(workout.id),
            );
      },
      onSaveAsRoutine: () => saveWorkoutAsRoutine(context, workout,
          repository: _routineRepository),
      onDelete: () {
        // Delete workout using BLoC
        context.read<WorkoutBloc>().add(
              WorkoutDeleteRequested(workout.id),
            );
      },
    );
  }

  /// Build enhanced loading state with skeleton cards
  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: 5, // Show 5 skeleton cards
      itemBuilder: (context, index) {
        return const WorkoutCardSkeleton();
      },
    );
  }
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

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

/// Secondary actions offered from a workout card's overflow menu.
enum _WorkoutCardAction { repeat, saveAsRoutine, delete }

/// A single compact workout entry (~72dp) in the Workouts list.
///
/// Leading: 48dp status circle that toggles completion (check when done,
/// calendar when planned, error-coloured when overdue). Middle: 1-line
/// title and one meta line. Trailing: overflow menu (repeat, save as
/// routine, delete). Delete asks for confirmation before [onDelete].
class WorkoutListCard extends StatelessWidget {
  const WorkoutListCard({
    super.key,
    required this.workout,
    required this.exerciseCount,
    required this.displayDate,
    required this.showDescription,
    required this.onTap,
    required this.onToggleComplete,
    required this.onRepeat,
    required this.onDelete,
    this.onSaveAsRoutine,
    this.isOverdue = false,
    this.weightUnitLabel = 'kg',
  });

  final Workout workout;
  final int exerciseCount;
  final DateTime displayDate;
  final bool showDescription;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final VoidCallback onRepeat;

  /// Called only after the user confirms deletion.
  final VoidCallback onDelete;

  /// "Save as routine"; the menu item is disabled when null or when the
  /// workout has no (working) sets.
  final VoidCallback? onSaveAsRoutine;

  /// Planned for a past day and not completed.
  final bool isOverdue;

  /// Unit appended to the volume of completed workouts ("kg" / "lbs").
  final String weightUnitLabel;

  bool get _canSaveAsRoutine =>
      onSaveAsRoutine != null && workout.sets.any((s) => !s.isWarmup);

  /// The meta line text (without the "Overdue" prefix). The date is shown
  /// next to the title, so the meta line has room for the volume.
  String get metaText => formatWorkoutMeta(
        exerciseCount: exerciseCount,
        setCount: workout.sets.length,
        date: displayDate,
        volume: workout.isCompleted ? workoutVolume(workout) : null,
        unitLabel: weightUnitLabel,
        includeDate: false,
      );

  void _confirmDelete(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Delete Workout'),
          content: Text(
            'Are you sure you want to delete "${workout.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                onDelete();
              },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metaStyle = theme.textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant);

    final (IconData statusIcon, Color statusColor) = workout.isCompleted
        ? (Icons.check_circle, colorScheme.primary)
        : isOverdue
            ? (Icons.event_busy_outlined, colorScheme.error)
            : (Icons.event_outlined, colorScheme.onSurfaceVariant);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
      clipBehavior: Clip.antiAlias,
      // Flat list card: subtle outline instead of a heavy shadow/border.
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // The 48dp buttons carry their own 12dp inset around the icon, so
          // the horizontal padding is small; the vertical padding is 12.
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.xs, vertical: Gap.md),
          child: Row(
            children: [
              IconButton(
                constraints: const BoxConstraints(
                    minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
                icon: Icon(statusIcon, color: statusColor),
                tooltip: workout.isCompleted
                    ? 'Mark as incomplete'
                    : 'Mark as complete',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onToggleComplete();
                },
              ),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            workout.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Text(
                          formatWorkoutDate(displayDate),
                          key: const Key('workout_card_date'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isOverdue && !workout.isCompleted
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text.rich(
                      TextSpan(children: [
                        if (isOverdue && !workout.isCompleted)
                          TextSpan(
                            text: 'Overdue · ',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        TextSpan(text: metaText),
                      ]),
                      key: const Key('workout_card_meta'),
                      style: metaStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showDescription)
                      Text(
                        workout.description!,
                        style: metaStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_WorkoutCardAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'More actions',
                style: IconButton.styleFrom(
                  minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                ),
                onSelected: (action) {
                  switch (action) {
                    case _WorkoutCardAction.repeat:
                      HapticFeedback.lightImpact();
                      onRepeat();
                    case _WorkoutCardAction.saveAsRoutine:
                      onSaveAsRoutine?.call();
                    case _WorkoutCardAction.delete:
                      _confirmDelete(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _WorkoutCardAction.repeat,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.repeat),
                      title: Text('Repeat'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _WorkoutCardAction.saveAsRoutine,
                    enabled: _canSaveAsRoutine,
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bookmark_add_outlined),
                      title: Text('Save as routine'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _WorkoutCardAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
