import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/audio_player_util.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';

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

  // Timer related variables (now managed by TimerBloc)
  // Local timer state removed - using TimerBloc instead

  @override
  void initState() {
    super.initState();
    _workoutBloc = context.read<WorkoutBloc>();

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
              TextEditingController(text: set.weight.toString());
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

    super.dispose();
  }

  // Start or reset the rest timer using TimerBloc
  void _startRestTimer() {
    // Get user's preferred duration from preferences
    final userPrefs = UserPreferencesService();
    final timerDuration = userPrefs.getRestTimerDuration();

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
      workout = Workout.create(name: _nameController.text, sets: allSets);
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

  void _addSetForExercise(String exerciseId) {
    final newSet = WorkoutSet.create(
      exerciseId: exerciseId,
      reps: 8,
      weight: 0,
      isCompleted: false,
    );

    setState(() {
      _exerciseSets[exerciseId]?.add(newSet);

      // Create controllers for the new set
      final setKey = newSet.id;
      _weightControllers[setKey] = TextEditingController(text: '0');
      _repsControllers[setKey] = TextEditingController(text: '8');
    });
    _markDirty();
    _scheduleAutosave();
  }

  void _removeSetForExercise(String exerciseId, int index) {
    if (_exerciseSets.containsKey(exerciseId) &&
        index >= 0 &&
        index < (_exerciseSets[exerciseId]?.length ?? 0)) {
      // Get the set ID before removing it
      final setId = _exerciseSets[exerciseId]![index].id;

      setState(() {
        // Remove the set
        _exerciseSets[exerciseId]?.removeAt(index);

        // Clean up controllers
        if (_weightControllers.containsKey(setId)) {
          _weightControllers[setId]!.dispose();
          _weightControllers.remove(setId);
        }

        if (_repsControllers.containsKey(setId)) {
          _repsControllers[setId]!.dispose();
          _repsControllers.remove(setId);
        }

        // If no sets left, consider removing the exercise entirely
        if (_exerciseSets[exerciseId]?.isEmpty ?? false) {
          // Ask user if they want to remove the exercise
          _confirmRemoveExercise(exerciseId);
        }
      });
      _markDirty();
      _scheduleAutosave();
    }
  }

  void _confirmRemoveExercise(String exerciseId) {
    final exercise = _exercises[exerciseId];
    if (exercise == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Exercise'),
        content: Text('Remove ${exercise.name} from this workout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add an empty set to keep the exercise
              _addSetForExercise(exerciseId);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _exerciseSets.remove(exerciseId);
                _exercises.remove(exerciseId);
              });
              _markDirty();
              _scheduleAutosave();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
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
        );
      });
      _markDirty();
      _scheduleAutosave();

      // Start or reset the timer when a set is marked as complete
      if (!wasCompleted) {
        _startRestTimer();
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
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled:
          true, // Allow the sheet to be larger than half the screen
      useRootNavigator: true, // Fix Hero tag conflicts on web
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const ExerciseSelectionSheet();
      },
    ).then((exercise) {
      if (exercise != null && mounted) {
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
        sets: allSets,
      );
      _currentWorkoutId = workout.id;
      _persistedWorkout = workout;
      _workoutBloc.add(WorkoutCreateRequested(workout));
    }
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
      onPopInvoked: (didPop) {
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
                  context.read<ExerciseBloc>().add(const ExerciseLoadRequested());
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      cursorColor: Colors.white,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        filled: true,
                                        fillColor:
                                            Colors.black.withValues(alpha: 0.2),
                                      ),
                                    )
                                  : Text(_nameController.text),
                            ),
                          ),

                          // Timer display on the right
                          if (timerState.currentMotivationalPhrase != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3.0, // Keep the thick white border
                                ),
                              ),
                              child: Text(
                                timerState.currentMotivationalPhrase!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            )
                          else if (timerState.isRunning)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3.0, // Keep the thick white border
                                ),
                              ),
                              child: Text(
                                timerState.formattedTime,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
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
                                  final sets = _exerciseSets[exerciseId] ?? [];

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
                                          if (widget.workoutId !=
                                              null) // Only show replace button when editing workout
                                            IconButton(
                                              icon:
                                                  const Icon(Icons.swap_horiz),
                                              tooltip: 'Replace Exercise',
                                              onPressed: () =>
                                                  _showExerciseReplacementSheet(
                                                      exerciseId),
                                              style: IconButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .secondary,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                        ],
                                      ),

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
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0),
                                        child: Row(
                                          children: [
                                            const SizedBox(
                                              width: 50,
                                              child: Text(
                                                'Set',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                UserPreferencesService()
                                                    .getWeightUnitLabel(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Reps',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(
                                                width:
                                                    90), // Space for action buttons
                                          ],
                                        ),
                                      ),

                                      const Divider(),

                                      // Sets list for this exercise
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: sets.length,
                                        itemBuilder: (context, index) {
                                          final set = sets[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4.0),
                                            child: Row(
                                              children: [
                                                // Set number
                                                SizedBox(
                                                  width: 50,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4.0),
                                                    ),
                                                    child: Text(
                                                      '${index + 1}',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // Weight input
                                                Expanded(
                                                  flex: 2,
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8.0,
                                                    ),
                                                    child: TextField(
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                      controller: _weightControllers[
                                                              set.id] ??
                                                          TextEditingController(
                                                              text: set.weight
                                                                  .toString()),
                                                      onChanged: (value) {
                                                        final weight =
                                                            double.tryParse(
                                                                    value) ??
                                                                0;
                                                        _updateSetWeightForExercise(
                                                            exerciseId,
                                                            index,
                                                            weight);
                                                      },
                                                    ),
                                                  ),
                                                ),

                                                // Reps input
                                                Expanded(
                                                  flex: 2,
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8.0,
                                                    ),
                                                    child: TextField(
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                      controller: _repsControllers[
                                                              set.id] ??
                                                          TextEditingController(
                                                              text: set.reps
                                                                  .toString()),
                                                      onChanged: (value) {
                                                        final reps =
                                                            int.tryParse(
                                                                    value) ??
                                                                0;
                                                        _updateSetRepsForExercise(
                                                            exerciseId,
                                                            index,
                                                            reps);
                                                      },
                                                    ),
                                                  ),
                                                ),

                                                // Action buttons
                                                Row(
                                                  children: [
                                                    // Complete button
                                                    IconButton(
                                                      icon: Icon(
                                                        set.isCompleted
                                                            ? Icons.check_circle
                                                            : Icons
                                                                .check_circle_outline,
                                                        color: set.isCompleted
                                                            ? Colors.green
                                                            : Colors.grey,
                                                      ),
                                                      onPressed: () =>
                                                          _toggleSetCompletionForExercise(
                                                              exerciseId,
                                                              index),
                                                    ),

                                                    // Delete button
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.white,
                                                          size: 18,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        onPressed: () =>
                                                            _removeSetForExercise(
                                                                exerciseId,
                                                                index),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
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
                    bottomNavigationBar: BottomAppBar(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: _hasUnsavedChanges
                                  ? _confirmDiscardChanges
                                  : () => Navigator.pop(context),
                              child: const Text('CANCEL'),
                            ),
                            ElevatedButton(
                              onPressed: (!isLoading &&
                                      (_hasUnsavedChanges ||
                                          _persistedWorkout != null))
                                  ? _saveWorkout
                                  : null,
                              child: const Text('SAVE'),
                            ),
                          ],
                        ),
                      ),
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
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
