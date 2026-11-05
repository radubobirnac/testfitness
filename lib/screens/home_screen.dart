import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/boxing_cardio_screen.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/screens/heart_rate_monitor_screen.dart';
import 'package:testfitness/screens/routines_screen.dart';
import 'package:testfitness/screens/vo2_max_training_screen.dart';
import 'package:testfitness/screens/weight_test_selection_screen.dart';
import 'package:testfitness/screens/workouts_screen.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/ai_workout_generator.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';
import 'package:testfitness/widgets/start_workout_flow.dart';
import 'package:testfitness/widgets/workout_card_skeleton.dart';
import 'package:testfitness/widgets/workout_split_picker.dart';

/// Bottom-navigation indices (see MainScreen).
const int _kWorkoutsTab = 1;
const int _kProgressTab = 3;

/// Max rows in the Upcoming and Recent sections.
const int _kHomeListLimit = 3;

/// "Today" dashboard: start a workout, today's suggestion, upcoming and
/// recent workouts, routines, this week's numbers and tools — one scroll.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.isAiAvailable,
    this.routineRepository,
    this.clock,
    this.suggestionLoader,
  });

  /// Overrides the AI availability check (tests). Defaults to
  /// `AIService().isAvailable`.
  final bool Function()? isAiAvailable;

  /// Routine storage (tests). Defaults to [RoutineRepository].
  final RoutineRepository? routineRepository;

  /// "Now" (tests). Defaults to [DateTime.now].
  final DateTime Function()? clock;

  /// Builds the suggestion text (tests). Defaults to the AI suggestion, or
  /// the offline coach's plan when AI is unavailable.
  final Future<String> Function(List<Workout> workouts)? suggestionLoader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _WorkoutFocusPreference {
  singleMuscleGroup,
  multipleMuscleGroups,
}

/// This week vs last week, for the summary row.
class _WeekSummary {
  const _WeekSummary(this.thisWeek, this.lastWeek);

  final WeeklyCheckIn thisWeek;
  final WeeklyCheckIn lastWeek;
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _importedFromCsvLabel = 'Imported from CSV';

  Future<String>? _aiSuggestionFuture;
  String? _aiSuggestionSignature;

  late final RoutineRepository _routineRepository =
      widget.routineRepository ?? RoutineRepository();

  // Memoised weekly summary (recomputed when the workout list or day changes).
  List<Workout>? _summaryWorkouts;
  DateTime? _summaryDay;
  _WeekSummary? _summary;

  DateTime get _now => (widget.clock ?? DateTime.now)();

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

  void _switchToTab(int index) {
    HapticFeedback.selectionClick();
    context.read<AppBloc>().add(AppTabChanged(index));
  }

  void _openStartFlow() => showStartWorkoutFlow(
        context,
        isAiAvailable: widget.isAiAvailable,
        routineRepository: _routineRepository,
      );

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
            title: const Text('Today'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _refreshWorkouts,
              ),
            ],
          ),
          // Skeleton only on the first load; later reloads keep the page.
          body: state.isLoading && state.workouts.isEmpty
              ? _buildLoadingState()
              : _buildDashboard(context, state.workouts),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, List<Workout> workouts) {
    final now = _now;
    _ensureAISuggestionFuture(workouts);
    final unitLabel =
        UserPreferencesService().getWeightUnitLabel().toLowerCase();
    final upcoming = _upcomingWorkouts(workouts, now);
    final recent = _recentWorkouts(workouts);

    return RefreshIndicator(
      onRefresh: () async => _refreshWorkouts(),
      child: CustomScrollView(
        key: const PageStorageKey('home_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildStartSection(context, now)),
          const SliverToBoxAdapter(child: SectionHeader("Today's suggestion")),
          SliverToBoxAdapter(child: _buildSuggestionCard(context, workouts)),
          if (upcoming.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                'Upcoming',
                trailing: _trailingButton(
                  key: const Key('home_upcoming_see_all'),
                  label: 'See all',
                  onPressed: () => _switchToTab(_kWorkoutsTab),
                ),
              ),
            ),
            SliverList.list(children: [
              for (final workout in upcoming)
                _buildWorkoutCard(context, workout, now, unitLabel),
            ]),
          ],
          SliverToBoxAdapter(
            child: RoutineQuickStart(
              workouts: workouts,
              repository: _routineRepository,
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              'This week',
              trailing: _trailingButton(
                key: const Key('home_see_progress'),
                label: 'See progress',
                onPressed: () => _switchToTab(_kProgressTab),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildWeekSummary(context, workouts, now, unitLabel),
          ),
          const SliverToBoxAdapter(child: SectionHeader('Recent workouts')),
          if (recent.isEmpty)
            SliverToBoxAdapter(child: _buildRecentEmpty(context))
          else
            SliverList.list(children: [
              for (final workout in recent)
                _buildWorkoutCard(context, workout, now, unitLabel),
            ]),
          const SliverToBoxAdapter(child: SectionHeader('Tools')),
          SliverToBoxAdapter(child: _buildTools(context)),
          const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
        ],
      ),
    );
  }

  Widget _trailingButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      key: key,
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  // -------------------------------------------------------------------------
  // Start
  // -------------------------------------------------------------------------

  Widget _buildStartSection(BuildContext context, DateTime now) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat('EEEE, MMM d').format(now),
            key: const Key('home_date'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            key: const Key('home_start_workout'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget + 8),
            ),
            onPressed: _openStartFlow,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start workout'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Today's suggestion (coach / AI plan + muscle-split picker)
  // -------------------------------------------------------------------------

  Widget _buildSuggestionCard(BuildContext context, List<Workout> workouts) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final usingCoach = _usingCoach;

    return _FlatCard(
      key: const Key('home_suggestion_card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.xs, Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(usingCoach ? Icons.insights : Icons.smart_toy,
                    color: colorScheme.primary),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    usingCoach ? 'Coach suggestion' : 'AI workout suggestion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('home_suggestion_refresh'),
                  tooltip: 'New suggestion',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refreshAISuggestion(workouts),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: Gap.md),
              child: FutureBuilder<String>(
                future: _aiSuggestionFuture,
                builder: (context, snapshot) {
                  final bodyStyle = theme.textTheme.bodyMedium;
                  final metaStyle = bodyStyle?.copyWith(
                      color: colorScheme.onSurfaceVariant);
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            usingCoach
                                ? 'Coach is planning your next session...'
                                : 'AI analyzing your patterns...',
                            style: metaStyle,
                          ),
                        ),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Unable to get a suggestion right now.',
                      style: metaStyle,
                    );
                  }
                  return Text(
                    snapshot.data ?? 'No suggestion available',
                    key: const Key('home_suggestion_text'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle,
                  );
                },
              ),
            ),
            const SizedBox(height: Gap.md),
            Padding(
              padding: const EdgeInsets.only(right: Gap.md),
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  FilledButton.tonal(
                    key: const Key('home_suggestion_start'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                    ),
                    onPressed: () => _createAIWorkout(context, workouts),
                    child: Text(usingCoach ? 'Start this' : 'Create AI workout'),
                  ),
                  OutlinedButton(
                    key: const Key('home_choose_workout'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      openWorkoutSplitPicker(context, workouts);
                    },
                    child: const Text('Choose another'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create an AI-generated workout with exercises and appropriate weights
  Future<void> _createAIWorkout(
      BuildContext context, List<Workout> allWorkouts) async {
    AppLogger.info('HomeScreen: Creating AI workout');

    // No AI available: open the coach's workout directly (same one the card
    // describes), without AI-only questions or loading dialogs.
    if (_usingCoach) {
      final coachWorkout = await _buildCoachWorkout(allWorkouts);
      if (!context.mounted) return;
      _openCreated(context, coachWorkout);
      return;
    }

    final preference = await _showWorkoutPreferenceDialog(context);
    if (!context.mounted || preference == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: Gap.lg),
            Expanded(child: Text('AI is creating your workout...')),
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

    _generateAIWorkoutAsync(
      context,
      recentWorkouts,
      preferSingleMuscleGroup:
          preference == _WorkoutFocusPreference.singleMuscleGroup,
    );
  }

  /// Creates [workout] and opens it in the editor; reloads on return.
  void _openCreated(BuildContext context, Workout workout) {
    context.read<WorkoutBloc>().add(WorkoutCreateRequested(workout));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExerciseDetailScreen.editWorkout(workoutId: workout.id),
      ),
    ).then((_) {
      if (mounted) _refreshWorkouts();
    });
  }

  /// Helper method to handle async AI workout generation
  Future<void> _generateAIWorkoutAsync(
    BuildContext context,
    List<Workout> recentWorkouts, {
    bool? preferSingleMuscleGroup,
  }) async {
    try {
      final aiWorkout = await AIWorkoutGenerator().generateAIWorkout(
        workoutName: 'AI Suggested Workout',
        recentWorkouts: recentWorkouts,
        lookbackDays: 14,
        preferSingleMuscleGroup: preferSingleMuscleGroup,
      );
      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();
      _openCreated(context, aiWorkout);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'AI workout created with ${aiWorkout.exerciseIds.length} exercises!'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      AppLogger.warning('AI workout unavailable, using coach', error);

      // Fallback: offline coach builds the workout from the user's history.
      final coachWorkout = await _buildCoachWorkout(recentWorkouts);
      if (!context.mounted) return;
      _openCreated(context, coachWorkout);
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

  // -------------------------------------------------------------------------
  // Upcoming / recent workouts
  // -------------------------------------------------------------------------

  /// Not completed, scheduled today or later, soonest first.
  List<Workout> _upcomingWorkouts(List<Workout> workouts, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = workouts
        .where((w) =>
            !w.isCompleted &&
            w.scheduledDate != null &&
            !w.scheduledDate!.isBefore(today))
        .toList()
      ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
    return upcoming.take(_kHomeListLimit).toList();
  }

  /// Last completed workouts, most recent first.
  List<Workout> _recentWorkouts(List<Workout> workouts) {
    final completed = workouts.where((w) => w.isCompleted).toList()
      ..sort((a, b) => workoutDisplayDate(b).compareTo(workoutDisplayDate(a)));
    return completed.take(_kHomeListLimit).toList();
  }

  /// Same card and actions as the Workouts tab.
  Widget _buildWorkoutCard(
    BuildContext context,
    Workout workout,
    DateTime now,
    String unitLabel,
  ) {
    final bloc = context.read<WorkoutBloc>();
    return WorkoutListCard(
      key: ValueKey('home_workout_card_${workout.id}'),
      workout: workout,
      exerciseCount: workout.exerciseIds.length,
      displayDate: workoutDisplayDate(workout),
      isOverdue: isWorkoutOverdue(workout, now),
      weightUnitLabel: unitLabel,
      showDescription: workout.description != null &&
          workout.description!.trim().isNotEmpty &&
          workout.description != _importedFromCsvLabel,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ExerciseDetailScreen.editWorkout(workoutId: workout.id),
          ),
        ).then((_) {
          if (mounted) _refreshWorkouts();
        });
      },
      onToggleComplete: () {
        if (workout.isCompleted) {
          bloc.add(WorkoutUpdateRequested(Workout(
            id: workout.id,
            name: workout.name,
            description: workout.description,
            scheduledDate: workout.scheduledDate,
            completedDate: null,
            isCompleted: false,
            sets: workout.sets,
            durationMinutes: workout.durationMinutes,
            notes: workout.notes,
          )));
        } else {
          bloc.add(WorkoutCompleteRequested(workout.id));
        }
      },
      onRepeat: () => bloc.add(WorkoutDuplicateRequested(workout.id)),
      onSaveAsRoutine: () => saveWorkoutAsRoutine(context, workout,
          repository: _routineRepository),
      onDelete: () => bloc.add(WorkoutDeleteRequested(workout.id)),
    );
  }

  Widget _buildRecentEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('home_recent_empty'),
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: Text(
        'No completed workouts yet. Finish a workout to see it here.',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // This week
  // -------------------------------------------------------------------------

  _WeekSummary _weekSummary(List<Workout> workouts, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    final cached = _summary;
    if (cached != null &&
        identical(_summaryWorkouts, workouts) &&
        _summaryDay == day) {
      return cached;
    }
    final coach = ProgressionCoach(
        useMetric: UserPreferencesService().getUseMetricUnits());
    // Muscle-group breakdowns aren't shown here, so no exercise lookup.
    final summary = _WeekSummary(
      coach.weeklyCheckIn(workouts, const {}, now: now),
      coach.weeklyCheckIn(workouts, const {},
          now: DateTime(now.year, now.month, now.day - 7, now.hour,
              now.minute)),
    );
    _summaryWorkouts = workouts;
    _summaryDay = day;
    _summary = summary;
    return summary;
  }

  Widget _buildWeekSummary(BuildContext context, List<Workout> workouts,
      DateTime now, String unitLabel) {
    final summary = _weekSummary(workouts, now);
    final thisWeek = summary.thisWeek;
    final lastWeek = summary.lastWeek;
    final compact = NumberFormat.compact();
    String volume(double v) => '${compact.format(v.round())} $unitLabel';

    return Padding(
      key: const Key('home_week_summary'),
      padding: AppInsets.page,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatTile(
                label: 'Workouts',
                value: '${thisWeek.workoutsThisWeek}',
                comparison: 'Last wk ${lastWeek.workoutsThisWeek}',
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: _StatTile(
                label: 'Sets',
                value: '${thisWeek.setsThisWeek}',
                comparison: 'Last wk ${lastWeek.setsThisWeek}',
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: _StatTile(
                label: 'Volume',
                value: volume(thisWeek.volumeThisWeek),
                comparison:
                    'Last wk ${volume(thisWeek.volumeLastWeek ?? 0)}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tools
  // -------------------------------------------------------------------------

  Widget _buildTools(BuildContext context) {
    void open(Widget screen) {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => screen));
    }

    final tools = <_ToolTile>[
      _ToolTile(
        icon: Icons.scale,
        label: 'Find Your Weight',
        onTap: () => open(const WeightTestSelectionScreen()),
      ),
      _ToolTile(
        icon: Icons.sports_mma,
        label: 'Boxing Cardio',
        onTap: () => open(const BoxingCardioScreen()),
      ),
      _ToolTile(
        icon: Icons.monitor_heart,
        label: 'Heart Rate',
        onTap: () => open(const HeartRateMonitorScreen()),
      ),
      _ToolTile(
        icon: Icons.directions_run,
        label: 'VO2 Max Training',
        onTap: () => open(const VO2MaxTrainingScreen()),
      ),
    ];

    return Padding(
      key: const Key('home_tools'),
      padding: AppInsets.page,
      child: Column(
        children: [
          for (var i = 0; i < tools.length; i += 2) ...[
            if (i > 0) const SizedBox(height: Gap.sm),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tools[i]),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: i + 1 < tools.length
                        ? tools[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: 5,
      itemBuilder: (context, index) => const WorkoutCardSkeleton(),
    );
  }

  // -------------------------------------------------------------------------
  // Suggestion loading
  // -------------------------------------------------------------------------

  void _ensureAISuggestionFuture(List<Workout> workouts) {
    final signature = _buildSuggestionSignature(workouts);
    if (_aiSuggestionFuture == null || _aiSuggestionSignature != signature) {
      _aiSuggestionSignature = signature;
      _aiSuggestionFuture = _loadSuggestion(workouts);
    }
  }

  void _refreshAISuggestion(List<Workout> workouts) {
    setState(() {
      _aiSuggestionSignature = _buildSuggestionSignature(workouts);
      _aiSuggestionFuture = _loadSuggestion(workouts);
    });
  }

  Future<String> _loadSuggestion(List<Workout> workouts) =>
      (widget.suggestionLoader ?? _getAIWorkoutSuggestion)(workouts);

  String _buildSuggestionSignature(List<Workout> workouts) {
    final completedWorkouts =
        workouts.where((w) => w.isCompleted && w.completedDate != null);
    final latestCompletion = completedWorkouts
        .map((w) => w.completedDate!.millisecondsSinceEpoch)
        .fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
    // Include the workout-suggestion settings so changing them refreshes.
    final prefs = UserPreferencesService().getWorkoutPreferences();
    return '${workouts.length}|$latestCompletion|$prefs';
  }

  /// True when suggestions come from the offline coach (no AI key / offline).
  bool get _usingCoach =>
      !(widget.isAiAvailable ?? () => AIService().isAvailable)();

  /// Offline, rules-based workout built by the progression coach.
  Future<Workout> _buildCoachWorkout(List<Workout> allWorkouts) async {
    final exercises = await ExerciseRepository().getExercises();
    final coach =
        ProgressionCoach(useMetric: UserPreferencesService().getUseMetricUnits());
    return coach.suggestNextWorkout(allWorkouts, exercises,
        preferences: WorkoutPreferences.fromMap(
            UserPreferencesService().getWorkoutPreferences()));
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

  /// AI workout suggestion based on recent workout patterns; the coach's
  /// plan when AI is unavailable or fails.
  Future<String> _getAIWorkoutSuggestion(List<Workout> allWorkouts) async {
    if (_usingCoach) {
      return _coachSuggestionText(allWorkouts);
    }
    try {
      final recentWorkouts = allWorkouts
          .where((w) => w.isCompleted && w.completedDate != null)
          .where((w) => w.completedDate!.isAfter(
                DateTime.now().subtract(const Duration(days: 14)),
              ))
          .toList();

      return await AIService().suggestNextWorkout(
        recentWorkouts: recentWorkouts,
        lookbackDays: 14,
        preferences: WorkoutPreferences.fromMap(
            UserPreferencesService().getWorkoutPreferences()),
      );
    } catch (e) {
      AppLogger.warning('Failed to get AI workout suggestion: $e');
      return _coachSuggestionText(allWorkouts);
    }
  }
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

/// Flat card matching [WorkoutListCard]: surfaceContainerLow, 12px radius,
/// outlineVariant border, page gutter margin.
class _FlatCard extends StatelessWidget {
  const _FlatCard({super.key, required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: margin ??
          const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// One number in the "This week" row: value, label and last week's value.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.comparison,
  });

  final String label;
  final String value;
  final String comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaColor = theme.colorScheme.onSurfaceVariant;
    Widget fit(Widget child) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: child,
        );
    return _FlatCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            fit(Text(label,
                style: theme.textTheme.bodySmall?.copyWith(color: metaColor))),
            fit(Text(value, style: theme.textTheme.titleMedium)),
            fit(Text(comparison,
                style: theme.textTheme.labelSmall?.copyWith(color: metaColor))),
          ],
        ),
      ),
    );
  }
}

/// Icon + label tile in the Tools grid (label wraps to two lines, never
/// truncated at normal sizes).
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _FlatCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: Gap.sm),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
