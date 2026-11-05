import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/screens/boxing_cardio_screen.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/screens/heart_rate_monitor_screen.dart';
import 'package:testfitness/screens/weight_test_selection_screen.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/ai_workout_generator.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_loading_card.dart';
import 'package:testfitness/widgets/animated_feedback.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _WorkoutFocusPreference {
  singleMuscleGroup,
  multipleMuscleGroups,
}

class _HomeScreenState extends State<HomeScreen> {
  Future<String>? _aiSuggestionFuture;
  String? _aiSuggestionSignature;

  @override
  void initState() {
    super.initState();
    // Load workouts using BLoC
    context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
  }

  void _refreshWorkouts() {
    AppLogger.info('HomeScreen: Refreshing workouts');
    context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutBloc, WorkoutState>(
      listener: (context, state) {
        // Handle side effects with beautiful animations
        if (state.errorMessage != null) {
          AnimatedFeedback.showError(context, state.errorMessage!);
        }

        if (state.successMessage != null) {
          AnimatedFeedback.showSuccess(context, state.successMessage!);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('StrengthWave'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshWorkouts,
              ),
            ],
          ),
          body: state.isLoading
              ? _buildLoadingState()
              : RefreshIndicator(
                  onRefresh: () async => _refreshWorkouts(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUpcomingWorkoutsSection(state.workouts),
                        const SizedBox(height: 24),
                        _buildRecentWorkoutsSection(state.workouts),
                        const SizedBox(height: 24),
                        _buildQuickActionsSection(),
                      ],
                    ),
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _createNewWorkout(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _createNewWorkout(BuildContext context) {
    AppLogger.info('HomeScreen: Opening editor for a new workout');

    // Open the editor for a new (unsaved) workout dated today. Nothing is
    // persisted until the first completed set is autosaved, so backing out
    // does not leave an empty workout behind.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseDetailScreen(),
      ),
    ).then((_) => _refreshWorkouts());
  }

  /// Create an AI-generated workout with exercises and appropriate weights
  Future<void> _createAIWorkout(
      BuildContext context, List<Workout> allWorkouts) async {
    AppLogger.info('HomeScreen: Creating AI workout');

    // No AI available: open the coach's workout directly (same one the card
    // describes), without AI-only questions or loading dialogs.
    if (_usingCoach) {
      final coachWorkout = await _buildCoachWorkout(allWorkouts);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.read<WorkoutBloc>().add(WorkoutCreateRequested(coachWorkout));
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ExerciseDetailScreen.editWorkout(workoutId: coachWorkout.id),
        ),
      ).then((_) => _refreshWorkouts());
      return;
    }

    final preference = await _showWorkoutPreferenceDialog(context);
    if (!mounted || preference == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('AI is creating your workout...'),
          ],
        ),
      ),
    );

    // Get recent completed workouts for analysis
    final recentWorkouts = allWorkouts
        .where((w) => w.isCompleted && w.completedDate != null)
        .where((w) => w.completedDate!.isAfter(
              DateTime.now().subtract(const Duration(days: 14)),
            ))
        .toList();

    // Generate AI workout asynchronously
    final preferSingleMuscleGroup =
        preference == _WorkoutFocusPreference.singleMuscleGroup;
    _generateAIWorkoutAsync(
      context,
      recentWorkouts,
      preferSingleMuscleGroup: preferSingleMuscleGroup,
    );
  }

  /// Helper method to handle async AI workout generation
  Future<void> _generateAIWorkoutAsync(
    BuildContext context,
    List<Workout> recentWorkouts, {
    bool? preferSingleMuscleGroup,
  }) async {
    try {
      // Generate AI workout
      final aiWorkoutGenerator = AIWorkoutGenerator();
      final aiWorkout = await aiWorkoutGenerator.generateAIWorkout(
        workoutName: 'AI Suggested Workout',
        recentWorkouts: recentWorkouts,
        lookbackDays: 14,
        preferSingleMuscleGroup: preferSingleMuscleGroup,
      );

      // Check if widget is still mounted before using context
      if (!mounted) return;

      // ignore: use_build_context_synchronously
      // Close loading dialog
      Navigator.of(context).pop();

      // ignore: use_build_context_synchronously
      // Create workout using BLoC
      context.read<WorkoutBloc>().add(WorkoutCreateRequested(aiWorkout));

      // ignore: use_build_context_synchronously
      // Navigate to workout editing screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ExerciseDetailScreen.editWorkout(workoutId: aiWorkout.id),
        ),
      ).then((_) => _refreshWorkouts());

      // ignore: use_build_context_synchronously
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'AI workout created with ${aiWorkout.exerciseIds.length} exercises!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      // Check if widget is still mounted before using context
      if (!mounted) return;

      // ignore: use_build_context_synchronously
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      AppLogger.warning('AI workout unavailable, using coach', error);

      // Fallback: offline coach builds the workout from the user's history.
      final coachWorkout = await _buildCoachWorkout(recentWorkouts);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      context.read<WorkoutBloc>().add(WorkoutCreateRequested(coachWorkout));
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ExerciseDetailScreen.editWorkout(workoutId: coachWorkout.id),
        ),
      ).then((_) => _refreshWorkouts());
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'AI unavailable — your coach built this workout from your history.'),
        ),
      );
    }
  }

  Future<_WorkoutFocusPreference?> _showWorkoutPreferenceDialog(
      BuildContext context) {
    return showDialog<_WorkoutFocusPreference>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout Focus'),
        content: const Text(
          'How do you want your AI workout focused?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(_WorkoutFocusPreference.singleMuscleGroup),
            child: const Text('Single Body Part'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context)
                .pop(_WorkoutFocusPreference.multipleMuscleGroups),
            child: const Text('Multiple Body Parts'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingWorkoutsSection(List<Workout> workouts) {
    final now = DateTime.now();
    _ensureAISuggestionFuture(workouts);

    // Filter for upcoming workouts (scheduled and not completed)
    final upcomingWorkouts = workouts
        .where(
          (w) =>
              !w.isCompleted &&
              w.scheduledDate != null &&
              w.scheduledDate!.isAfter(now),
        )
        .toList();

    // Sort upcoming workouts by scheduled date
    upcomingWorkouts.sort(
      (a, b) => a.scheduledDate!.compareTo(b.scheduledDate!),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Workouts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        upcomingWorkouts.isEmpty
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        _usingCoach ? Icons.insights : Icons.smart_toy,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _usingCoach
                            ? 'Coach Suggestion'
                            : 'AI Workout Suggestion',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: _aiSuggestionFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(_usingCoach
                                    ? 'Coach is planning your next session...'
                                    : 'AI analyzing your patterns...'),
                              ],
                            );
                          }

                          if (snapshot.hasError) {
                            return Column(
                              children: [
                                const Text(
                                  'Unable to get AI suggestion (offline)',
                                  style: TextStyle(color: Colors.orange),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => _createNewWorkout(context),
                                  child: const Text('Create New Workout'),
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Text(
                                snapshot.data ?? 'No suggestion available',
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _createAIWorkout(context, workouts);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                    child: Text(_usingCoach
                                        ? 'Start This Workout'
                                        : 'Create AI Workout'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {
                                      _refreshAISuggestion(workouts);
                                    },
                                    child: const Text('New Suggestion'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcomingWorkouts.length,
                itemBuilder: (context, index) {
                  final workout = upcomingWorkouts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(workout.name),
                      subtitle: Text(
                        workout.scheduledDate != null
                            ? DateFormat(
                                'EEEE, MMMM d',
                              ).format(workout.scheduledDate!)
                            : 'No date scheduled',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Navigate to workout edit screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ExerciseDetailScreen.editWorkout(
                              workoutId: workout.id,
                            ),
                          ),
                        ).then((_) => _refreshWorkouts());
                      },
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildRecentWorkoutsSection(List<Workout> workouts) {
    // Get completed workouts
    final completedWorkouts = workouts.where((w) => w.isCompleted).toList();

    // Sort by completion date (most recent first)
    completedWorkouts.sort(
      (a, b) => (b.completedDate ?? DateTime.now()).compareTo(
        a.completedDate ?? DateTime.now(),
      ),
    );

    // Take the most recent workouts
    final recentWorkouts = completedWorkouts.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Workouts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        recentWorkouts.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No completed workouts yet. Complete a workout to see it here!',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentWorkouts.length,
                itemBuilder: (context, index) {
                  final workout = recentWorkouts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(workout.name),
                      subtitle: Text(
                        workout.completedDate != null
                            ? 'Completed on ${DateFormat('MMM d').format(workout.completedDate!)}'
                            : 'Completed',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Navigate to workout edit screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ExerciseDetailScreen.editWorkout(
                              workoutId: workout.id,
                            ),
                          ),
                        ).then((_) => _refreshWorkouts());
                      },
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildActionCard(
                icon: Icons.scale,
                title: 'Find Your Weight',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WeightTestSelectionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.sports_mma, // Better boxing icon
                title: 'Boxing Cardio',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BoxingCardioScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.monitor_heart,
                title: 'Heart Rate',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HeartRateMonitorScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.flash_on,
                title: 'Start Empty Workout',
                onTap: () => _createNewWorkout(context),
              ),
              const SizedBox(width: 12),
              _buildActionCard(
                icon: Icons.trending_up,
                title: 'Track Progress',
                onTap: () {
                  // Navigate to Progress tab (index 3)
                  context.read<AppBloc>().add(const AppTabChanged(3));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card skeleton
          const AnimatedLoadingCard(height: 120),
          const SizedBox(height: 24),

          // Upcoming workouts skeleton
          const AnimatedLoadingCard(height: 24, width: 180),
          const SizedBox(height: 8),
          ...List.generate(
              2,
              (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: WorkoutCardSkeleton(),
                  )),
          const SizedBox(height: 24),

          // Recent workouts skeleton
          const AnimatedLoadingCard(height: 24, width: 160),
          const SizedBox(height: 8),
          ...List.generate(
              3,
              (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: WorkoutCardSkeleton(),
                  )),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      // Fixed width for horizontal scrolling; wide enough that two-word
      // labels ("Find Your Weight") wrap onto two lines instead of truncating.
      width: 116,
      child: Card(
        elevation: 2,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(begin: 0.8, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Icon(icon, size: 30),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _ensureAISuggestionFuture(List<Workout> workouts) {
    final signature = _buildSuggestionSignature(workouts);
    if (_aiSuggestionFuture == null || _aiSuggestionSignature != signature) {
      _aiSuggestionSignature = signature;
      _aiSuggestionFuture = _getAIWorkoutSuggestion(workouts);
    }
  }

  void _refreshAISuggestion(List<Workout> workouts) {
    setState(() {
      _aiSuggestionSignature = _buildSuggestionSignature(workouts);
      _aiSuggestionFuture = _getAIWorkoutSuggestion(workouts);
    });
  }

  String _buildSuggestionSignature(List<Workout> workouts) {
    final completedWorkouts =
        workouts.where((w) => w.isCompleted && w.completedDate != null);
    final latestCompletion = completedWorkouts
        .map((w) => w.completedDate!.millisecondsSinceEpoch)
        .fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
    return '${workouts.length}|$latestCompletion';
  }

  /// Get AI workout suggestion based on recent workout patterns
  /// True when suggestions come from the offline coach (no AI key / offline).
  bool get _usingCoach => !AIService().isAvailable;

  /// Offline, rules-based workout built by the progression coach.
  Future<Workout> _buildCoachWorkout(List<Workout> allWorkouts) async {
    final exercises = await ExerciseRepository().getExercises();
    final coach =
        ProgressionCoach(useMetric: UserPreferencesService().getUseMetricUnits());
    return coach.suggestNextWorkout(allWorkouts, exercises);
  }

  /// Short text describing the coach's suggested next workout.
  Future<String> _coachSuggestionText(List<Workout> allWorkouts) async {
    final workout = await _buildCoachWorkout(allWorkouts);
    final exercises = await ExerciseRepository().getExercises();
    final names = {for (final e in exercises) e.id: e.name};
    final coach =
        ProgressionCoach(useMetric: UserPreferencesService().getUseMetricUnits());
    final lines = <String>[];
    for (final id in workout.exerciseIds) {
      final first = workout.sets.firstWhere((s) => s.exerciseId == id);
      final name = names[id] ?? 'Exercise';
      lines.add(first.weight > 0
          ? '$name ${coach.formatWeight(first.weight)} × ${first.reps}'
          : '$name × ${first.reps}');
    }
    if (lines.isEmpty) return 'Log a workout and your coach will plan the next one.';
    return 'Coach suggests: ${lines.join(', ')}';
  }

  Future<String> _getAIWorkoutSuggestion(List<Workout> allWorkouts) async {
    final aiService = AIService();
    if (!aiService.isAvailable) {
      return _coachSuggestionText(allWorkouts);
    }
    try {
      // Get recent completed workouts for analysis
      final recentWorkouts = allWorkouts
          .where((w) => w.isCompleted && w.completedDate != null)
          .where((w) => w.completedDate!.isAfter(
                DateTime.now().subtract(const Duration(days: 14)),
              ))
          .toList();

      return await aiService.suggestNextWorkout(
        recentWorkouts: recentWorkouts,
        lookbackDays: 14,
      );
    } catch (e) {
      AppLogger.warning('Failed to get AI workout suggestion: $e');
      return _coachSuggestionText(allWorkouts);
    }
  }
}
