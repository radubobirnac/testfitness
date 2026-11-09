import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/screens/routines_screen.dart';
import 'package:testfitness/screens/workout_calendar_screen.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';
import 'package:testfitness/widgets/start_workout_flow.dart';
import 'package:testfitness/widgets/workout_card_skeleton.dart';

// The start sheet moved to start_workout_flow.dart; re-exported so existing
// imports of this file keep working.
export 'package:testfitness/widgets/start_workout_flow.dart'
    show StartWorkoutOption, StartWorkoutSelection, StartWorkoutSheet;

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
  static const String _importedFromCsvLabel = 'Imported from CSV';

  late final RoutineRepository _routineRepository =
      widget.routineRepository ?? RoutineRepository();

  bool _newestFirst = true;
  WorkoutFilter _filter = WorkoutFilter.all;
  bool _fabExtended = true;

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

  void _openStartSheet() => showStartWorkoutFlow(
        context,
        isAiAvailable: widget.isAiAvailable,
        routineRepository: _routineRepository,
      );

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
      // Only new messages: success/error stay in state across later emits.
      listenWhen: (previous, current) =>
          (current.successMessage != null &&
              current.successMessage != previous.successMessage) ||
          (current.errorMessage != null &&
              current.errorMessage != previous.errorMessage),
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
    final overdue = [
      for (final section in sections)
        for (final w in section.workouts)
          if (isWorkoutOverdue(w, now)) w,
    ];

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
                    if (entry is String) {
                      if (entry == 'Planned' && overdue.isNotEmpty) {
                        return SectionHeader(
                          entry,
                          trailing: TextButton(
                            key: const Key('mark_overdue_done'),
                            onPressed: () =>
                                _confirmMarkOverdueDone(context, overdue),
                            child: Text(overdue.length == 1
                                ? 'Mark overdue done'
                                : 'Mark ${overdue.length} overdue done'),
                          ),
                        );
                      }
                      return SectionHeader(entry);
                    }
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

  /// Overdue workout ticked off: ask whether it was done on its planned day
  /// (backdated, sets included) or today.
  Future<void> _askWhenDone(BuildContext context, Workout workout) async {
    final plannedDay = formatWorkoutDate(workout.plannedCompletionTime);
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('When did you do it?'),
        children: [
          SimpleDialogOption(
            key: const Key('done_on_planned_day'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Text('On its planned day ($plannedDay)'),
            ),
          ),
          SimpleDialogOption(
            key: const Key('done_today'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: Gap.sm),
              child: Text('Today'),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    context.read<WorkoutBloc>().add(choice
        ? WorkoutsCompleteOnPlannedDayRequested([workout.id])
        : WorkoutCompleteRequested(workout.id));
  }

  /// Clear a backlog of overdue workouts that were actually done back then.
  Future<void> _confirmMarkOverdueDone(
      BuildContext context, List<Workout> overdue) async {
    final n = overdue.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(n == 1
            ? 'Mark 1 overdue workout as done?'
            : 'Mark $n overdue workouts as done?'),
        content: const Text(
          'Each one is marked done on its planned day, including its sets, '
          'so your history, calendar and coach count it on the right date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_mark_overdue_done'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark as done'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    HapticFeedback.mediumImpact();
    context.read<WorkoutBloc>().add(WorkoutsCompleteOnPlannedDayRequested(
        [for (final w in overdue) w.id]));
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
        } else if (isWorkoutOverdue(workout, now)) {
          // Done in the past? Let the user backdate it to its planned day.
          _askWhenDone(context, workout);
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
      // 6px between cards (3 + 3) keeps 6+ cards on a 812px-tall phone.
      margin: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 3),
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
          // the horizontal padding is small; 10 vertical keeps 6+ cards on a
          // phone screen even when a section header has an action.
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: 10),
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
