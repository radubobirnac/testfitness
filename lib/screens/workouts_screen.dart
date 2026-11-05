import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/models/workout_set.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/screens/routines_screen.dart';
import 'package:testfitness/screens/workout_calendar_screen.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/ai_workout_generator.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';
import 'package:testfitness/widgets/workout_card_skeleton.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final List<String> _sortOptions = [
    'Newest',
    'Oldest',
  ];
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

  String? _selectedSort;
  bool _isGeneratingNext = false;
  bool _isGeneratingAi = false;

  @override
  void initState() {
    super.initState();

    // Load workouts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
    });
  }

  void _onSortChanged(String? sortKey) {
    AppLogger.debug('Changing workout sort to: ${sortKey ?? 'default'}');
    setState(() {
      _selectedSort = sortKey;
    });
  }

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

  DateTime _displayDateForWorkout(Workout workout) {
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

  List<Workout> _sortWorkouts(List<Workout> workouts, String? sortKey) {
    final sortOrder = sortKey ?? 'Newest';
    final sorted = List<Workout>.from(workouts);
    sorted.sort((a, b) {
      final dateA = _displayDateForWorkout(a).millisecondsSinceEpoch;
      final dateB = _displayDateForWorkout(b).millisecondsSinceEpoch;
      if (sortOrder == 'Oldest') {
        return dateA.compareTo(dateB);
      }
      return dateB.compareTo(dateA);
    });

    return sorted;
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
    return coach.suggestNextWorkout(workouts, allExercises);
  }

  Future<void> _createNextWorkout(WorkoutState state) async {
    if (_isGeneratingNext) return;
    setState(() {
      _isGeneratingNext = true;
    });

    Workout workout;
    try {
      final aiService = AIService();
      if (aiService.isAvailable) {
        final aiGenerator = AIWorkoutGenerator();
        workout = await aiGenerator.generateAIWorkout(
          workoutName: 'Next Workout',
          recentWorkouts: state.workouts,
          lookbackDays: 14,
        );
      } else {
        final reason = aiService.unavailableReason;
        workout = await _generateNextWorkoutFallback(state.workouts);
        if (mounted) {
          AnimatedFeedback.showSnackBar(
            context,
            '${reason ?? 'AI unavailable.'} Your coach built this workout from your history.',
            backgroundColor: Colors.orange,
          );
        }
      }
    } catch (error) {
      AppLogger.warning('AI generation failed, falling back', error);
      workout = await _generateNextWorkoutFallback(state.workouts);
      if (mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          'AI failed. Your coach built this workout from your history.',
          backgroundColor: Colors.orange,
        );
      }
    }

    if (!mounted) return;
    context.read<WorkoutBloc>().add(WorkoutCreateRequested(workout));

    setState(() {
      _isGeneratingNext = false;
    });

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

  Future<void> _createAiWorkout(WorkoutState state) async {
    if (_isGeneratingAi) return;
    final focus = await _showFocusPicker(context);
    if (!mounted || focus == null) return;

    setState(() {
      _isGeneratingAi = true;
    });

    _showAiBuildLoading();

    Workout workout;
    try {
      final aiService = AIService();
      if (!aiService.isAvailable) {
        throw Exception('AI unavailable');
      }

      final aiGenerator = AIWorkoutGenerator();
      final normalizedFocus = _formatFocusForPrompt(focus);
      workout = await aiGenerator.generateAiWorkout(
        workoutName: 'AI Build - $focus',
        focus: normalizedFocus,
        recentWorkouts: state.workouts,
        lookbackDays: 21,
        maxRecentWorkouts: 6,
      );
    } catch (error) {
      AppLogger.warning('AI build failed, using fallback', error);
      final reason = AIService().unavailableReason;
      workout = await _generateFocusWorkoutFallback(focus, state.workouts);
      if (mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          '${reason ?? 'AI unavailable.'} Created a rules-based workout.',
          backgroundColor: Colors.orange,
        );
      }
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    context.read<WorkoutBloc>().add(WorkoutCreateRequested(workout));

    setState(() {
      _isGeneratingAi = false;
    });

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

  void _showAiBuildLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('AI is building your workout...')),
          ],
        ),
      ),
    );
  }

  void _onRefreshPressed() {
    AppLogger.debug('Refreshing workouts');
    context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
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
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _onRefreshPressed,
                ),
              ],
            ),
            body: state.isLoading
                ? _buildLoadingState()
                : Column(
                    children: [
                      RoutinesSection(workouts: state.workouts),
                      // Sort chips
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _sortOptions.map((sortKey) {
                          return FilterChip(
                            label: Text(sortKey),
                            selected: _selectedSort == sortKey,
                            onSelected: (selected) {
                              _onSortChanged(selected ? sortKey : null);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 360;

                          final nextButton = ElevatedButton.icon(
                            onPressed: _isGeneratingNext
                                ? null
                                : () => _createNextWorkout(state),
                            icon: _isGeneratingNext
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: Text(_isGeneratingNext
                                ? 'Creating Next Workout...'
                                : 'Next Workout'),
                          );

                          final aiButton = ElevatedButton.icon(
                            onPressed:
                                _isGeneratingAi ? null : () => _createAiWorkout(state),
                            icon: _isGeneratingAi
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome_outlined),
                            label: Text(
                                _isGeneratingAi ? 'Building AI Workout...' : 'AI Build'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                nextButton,
                                const SizedBox(height: 12),
                                aiButton,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: nextButton),
                              const SizedBox(width: 12),
                              Expanded(child: aiButton),
                            ],
                          );
                        },
                      ),
                    ),

                    // Workouts list
                    Builder(builder: (context) {
                      final sortedWorkouts =
                          _sortWorkouts(state.workouts, _selectedSort);
                      return Expanded(
                        child: sortedWorkouts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.fitness_center,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No workouts yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap the + button to create your first workout',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: sortedWorkouts.length,
                                padding: const EdgeInsets.all(16.0),
                                itemBuilder: (context, index) {
                                  final workout = sortedWorkouts[index];
                                  // Get unique exercise IDs to count exercises
                                  final uniqueExercises =
                                      workout.exerciseIds.toList();

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    child: WorkoutListCard(
                                      workout: workout,
                                      exerciseCount: uniqueExercises.length,
                                      displayDate:
                                          _displayDateForWorkout(workout),
                                      showDescription:
                                          workout.description != null &&
                                              workout.description!
                                                  .trim()
                                                  .isNotEmpty &&
                                              workout.description !=
                                                  _importedFromCsvLabel,
                                      onTap: () {
                                        // Navigate to the workout editing screen instead of detail view
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (context, animation,
                                                    secondaryAnimation) =>
                                                ExerciseDetailScreen
                                                    .editWorkout(
                                              workoutId: workout.id,
                                            ),
                                            transitionsBuilder: (context,
                                                animation,
                                                secondaryAnimation,
                                                child) {
                                              const begin = Offset(1.0, 0.0);
                                              const end = Offset.zero;
                                              const curve = Curves.easeInOut;

                                              var tween = Tween(
                                                      begin: begin, end: end)
                                                  .chain(
                                                CurveTween(curve: curve),
                                              );

                                              return SlideTransition(
                                                position:
                                                    animation.drive(tween),
                                                child: child,
                                              );
                                            },
                                          ),
                                        ).then((_) {
                                          // Reload workouts after returning
                                          if (context.mounted) {
                                            context.read<WorkoutBloc>().add(
                                                const WorkoutLoadRequested());
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
                                            scheduledDate:
                                                workout.scheduledDate,
                                            completedDate: null,
                                            isCompleted: false,
                                            sets: workout.sets,
                                            durationMinutes:
                                                workout.durationMinutes,
                                            notes: workout.notes,
                                          );
                                          context.read<WorkoutBloc>().add(
                                                WorkoutUpdateRequested(
                                                    updatedWorkout),
                                              );
                                        } else {
                                          // Complete workout using BLoC
                                          context.read<WorkoutBloc>().add(
                                                WorkoutCompleteRequested(
                                                    workout.id),
                                              );
                                        }
                                      },
                                      onRepeat: () {
                                        // Duplicate the workout using BLoC
                                        context.read<WorkoutBloc>().add(
                                              WorkoutDuplicateRequested(
                                                  workout.id),
                                            );
                                      },
                                      onSaveAsRoutine: () =>
                                          saveWorkoutAsRoutine(
                                              context, workout),
                                      onDelete: () {
                                        // Delete workout using BLoC
                                        context.read<WorkoutBloc>().add(
                                              WorkoutDeleteRequested(
                                                  workout.id),
                                            );
                                      },
                                    ),
                                  );
                                },
                              ),
                      );
                    }),
                    ],
                  ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
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
                  if (context.mounted) {
                    context
                        .read<WorkoutBloc>()
                        .add(const WorkoutLoadRequested());
                  }
                });
              },
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }

  /// Build enhanced loading state with skeleton cards
  Widget _buildLoadingState() {
    return Column(
      children: [
        // Filter chips skeleton
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AnimatedLoadingCard(
                  height: 32,
                  width: 60 + (index * 10).toDouble(),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),

        // Workout cards skeleton
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: 5, // Show 5 skeleton cards
            itemBuilder: (context, index) {
              return const WorkoutCardSkeleton();
            },
          ),
        ),
      ],
    );
  }
}

/// Secondary actions offered from a workout card's overflow menu.
enum _WorkoutCardAction { repeat, saveAsRoutine, delete }

/// A single workout entry in the Workouts list.
///
/// The primary "complete" toggle is a 48dp control laid out next to the
/// title; secondary actions (repeat, delete) live in a trailing overflow
/// menu so nothing overlaps the workout name. Delete asks for confirmation
/// before [onDelete] is invoked.
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

  bool get _canSaveAsRoutine =>
      onSaveAsRoutine != null && workout.sets.any((s) => !s.isWarmup);

  void _confirmDelete(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text(
          'Are you sure you want to delete "${workout.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: Colors.teal[600], // Use teal instead of white
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onDelete();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red, // Use red for delete button
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row: name + complete toggle + overflow menu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workout.name,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    iconSize: 32,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: Icon(
                      workout.isCompleted
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: workout.isCompleted
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: workout.isCompleted
                        ? 'Mark as incomplete'
                        : 'Mark as complete',
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onToggleComplete();
                    },
                  ),
                  PopupMenuButton<_WorkoutCardAction>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'More actions',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
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

              // Description if available
              if (showDescription) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    workout.description!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Stats row (wraps on narrow screens instead of overflowing)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Exercise count
                    Chip(
                      avatar: const Icon(Icons.fitness_center, size: 16),
                      label: Text(
                        '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                      ),
                    ),

                    // Set count
                    Chip(
                      avatar: const Icon(Icons.repeat, size: 16),
                      label: Text(
                        '${workout.sets.length} ${workout.sets.length == 1 ? 'set' : 'sets'}',
                      ),
                    ),

                    // Date info - use the same date as sorting
                    Chip(
                      avatar: Icon(
                        workout.isCompleted
                            ? Icons.calendar_today
                            : Icons.event,
                        size: 16,
                      ),
                      label: Text(DateFormat('MMM d').format(displayDate)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
