import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/models/routine.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/routine_repository.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Shared routine UI: the Workouts-tab strip, the manage page, the Home quick-start row and
/// the save / start / rename / delete flows.

/// "3 exercises · last used yesterday"
String describeRoutine(Routine routine, {DateTime? now}) {
  final count = routine.exercises.length;
  final exercises = '$count ${count == 1 ? 'exercise' : 'exercises'}';
  return '$exercises · ${describeLastUsed(routine.lastUsedAt, now: now)}';
}

String describeLastUsed(DateTime? lastUsed, {DateTime? now}) {
  if (lastUsed == null) return 'not used yet';
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final day = DateTime(lastUsed.year, lastUsed.month, lastUsed.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'last used today';
  if (days == 1) return 'last used yesterday';
  if (days < 7) return 'last used $days days ago';
  return 'last used ${DateFormat('MMM d').format(lastUsed)}';
}

/// Asks for a name (prefilled with the workout name), saves the routine and
/// confirms with a SnackBar.
Future<void> saveWorkoutAsRoutine(
  BuildContext context,
  Workout workout, {
  RoutineRepository? repository,
}) async {
  final name = await showRoutineNameDialog(
    context,
    title: 'Save as routine',
    initialName: workout.name,
    confirmLabel: 'Save',
  );
  if (name == null || !context.mounted) return;
  final routine = Routine.fromWorkout(workout, name: name);
  if (routine.exercises.isEmpty) return;
  await (repository ?? RoutineRepository()).saveRoutine(routine);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Saved "$name" as a routine')),
  );
}

/// Builds today's workout from [routine], creates it via [WorkoutBloc] and
/// opens the editor (same flow as "Next workout").
Future<void> startRoutine(
  BuildContext context,
  Routine routine,
  List<Workout> allWorkouts, {
  RoutineRepository? repository,
}) async {
  HapticFeedback.selectionClick();
  final workout = routine.toWorkout(
    allWorkouts,
    useMetric: UserPreferencesService().getUseMetricUnits(),
  );
  final bloc = context.read<WorkoutBloc>();
  bloc.add(WorkoutCreateRequested(workout));
  try {
    await (repository ?? RoutineRepository()).markUsed(routine.id);
  } catch (e) {
    AppLogger.warning('Could not mark routine as used', e);
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          ExerciseDetailScreen.editWorkout(workoutId: workout.id),
    ),
  );
  if (!bloc.isClosed) bloc.add(const WorkoutLoadRequested());
}

Future<String?> showRoutineNameDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _RoutineNameDialog(
      title: title,
      initialName: initialName,
      confirmLabel: confirmLabel,
    ),
  );
}

class _RoutineNameDialog extends StatefulWidget {
  const _RoutineNameDialog({
    required this.title,
    required this.initialName,
    required this.confirmLabel,
  });

  final String title;
  final String initialName;
  final String confirmLabel;

  @override
  State<_RoutineNameDialog> createState() => _RoutineNameDialogState();
}

class _RoutineNameDialogState extends State<_RoutineNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Routine name'),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Loads routines and reloads whenever [RoutineRepository.changes] fires.
mixin _RoutineLoader<T extends StatefulWidget> on State<T> {
  RoutineRepository get repository;
  List<Routine>? routines;

  @override
  void initState() {
    super.initState();
    RoutineRepository.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    RoutineRepository.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final loaded = await repository.getRoutines();
    if (mounted) setState(() => routines = loaded);
  }
}

enum _RoutineAction { rename, delete }

/// Asks for a new name and saves it.
Future<void> renameRoutine(
  BuildContext context,
  Routine routine,
  RoutineRepository repository,
) async {
  final name = await showRoutineNameDialog(
    context,
    title: 'Rename routine',
    initialName: routine.name,
    confirmLabel: 'Rename',
  );
  if (name == null || name == routine.name) return;
  await repository.saveRoutine(routine.copyWith(name: name));
}

/// Confirms, then deletes [routine]. Past workouts are kept.
Future<void> confirmDeleteRoutine(
  BuildContext context,
  Routine routine,
  RoutineRepository repository,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('Delete routine'),
        content: Text('Delete "${routine.name}"? Past workouts are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) await repository.deleteRoutine(routine.id);
}

Future<void> _runRoutineAction(
  BuildContext context,
  _RoutineAction action,
  Routine routine,
  RoutineRepository repository,
) async {
  switch (action) {
    case _RoutineAction.rename:
      await renameRoutine(context, routine, repository);
    case _RoutineAction.delete:
      await confirmDeleteRoutine(context, routine, repository);
  }
}

/// Long-press sheet: Rename / Delete.
Future<void> showRoutineActionSheet(
  BuildContext context,
  Routine routine,
  RoutineRepository repository,
) async {
  HapticFeedback.mediumImpact();
  final action = await showModalBottomSheet<_RoutineAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, _RoutineAction.rename),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title:
                  Text('Delete', style: TextStyle(color: colorScheme.error)),
              onTap: () => Navigator.pop(context, _RoutineAction.delete),
            ),
          ],
        ),
      );
    },
  );
  if (action != null && context.mounted) {
    await _runRoutineAction(context, action, routine, repository);
  }
}

/// Compact routine label for the strip: "3 ex".
String shortRoutineCount(Routine routine) => '${routine.exercises.length} ex';

/// Compact "Routines" strip on the Workouts tab: a [SectionHeader] with a
/// "Manage" action and 56dp chips (name + "N ex"). Tap = start,
/// long-press = rename / delete. Renders nothing when there are no routines
/// (the empty hint lives in the Start workout sheet).
class RoutinesStrip extends StatefulWidget {
  const RoutinesStrip({
    super.key,
    required this.workouts,
    this.repository,
  });

  final List<Workout> workouts;
  final RoutineRepository? repository;

  @override
  State<RoutinesStrip> createState() => _RoutinesStripState();
}

class _RoutinesStripState extends State<RoutinesStrip>
    with _RoutineLoader<RoutinesStrip> {
  @override
  late final RoutineRepository repository =
      widget.repository ?? RoutineRepository();

  void _openManage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutinesScreen(
          workouts: widget.workouts,
          repository: repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded = routines;
    if (loaded == null || loaded.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          'Routines',
          trailing: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
            ),
            onPressed: _openManage,
            child: const Text('Manage'),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            padding: AppInsets.page,
            scrollDirection: Axis.horizontal,
            itemCount: loaded.length,
            separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
            itemBuilder: (context, index) => _RoutineChip(
              routine: loaded[index],
              onTap: () => startRoutine(
                  context, loaded[index], widget.workouts,
                  repository: repository),
              onLongPress: () =>
                  showRoutineActionSheet(context, loaded[index], repository),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineChip extends StatelessWidget {
  const _RoutineChip({
    required this.routine,
    required this.onTap,
    required this.onLongPress,
  });

  final Routine routine;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 168),
      child: Material(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: Gap.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  routine.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  shortRoutineCount(routine),
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
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

/// Full-page routine management: tap = start, ⋮ / long-press = rename or
/// delete.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({
    super.key,
    required this.workouts,
    this.repository,
  });

  final List<Workout> workouts;
  final RoutineRepository? repository;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen>
    with _RoutineLoader<RoutinesScreen> {
  @override
  late final RoutineRepository repository =
      widget.repository ?? RoutineRepository();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loaded = routines;
    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: loaded == null
          ? const Center(child: CircularProgressIndicator())
          : loaded.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border,
                            size: 48, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: Gap.md),
                        Text(
                          'Save a workout as a routine from its ⋮ menu',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: loaded.length,
                  itemBuilder: (context, index) {
                    final routine = loaded[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(routine.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(describeRoutine(routine)),
                      onTap: () => startRoutine(
                          context, routine, widget.workouts,
                          repository: repository),
                      onLongPress: () =>
                          showRoutineActionSheet(context, routine, repository),
                      trailing: PopupMenuButton<_RoutineAction>(
                        tooltip: 'Routine actions',
                        style: IconButton.styleFrom(
                          minimumSize:
                              const Size(kMinTouchTarget, kMinTouchTarget),
                        ),
                        onSelected: (action) => _runRoutineAction(
                            context, action, routine, repository),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _RoutineAction.rename,
                            child: Text('Rename'),
                          ),
                          PopupMenuItem(
                            value: _RoutineAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

/// Home-screen quick start: a "Routines" [SectionHeader] with a "Manage"
/// action and compact chips (same as [RoutinesStrip]) for up to
/// [maxRoutines] routines. Tap = start, long-press = rename / delete.
/// Renders nothing when there are no routines.
class RoutineQuickStart extends StatefulWidget {
  const RoutineQuickStart({
    super.key,
    required this.workouts,
    this.repository,
    this.maxRoutines = 6,
  });

  final List<Workout> workouts;
  final RoutineRepository? repository;
  final int maxRoutines;

  @override
  State<RoutineQuickStart> createState() => _RoutineQuickStartState();
}

class _RoutineQuickStartState extends State<RoutineQuickStart>
    with _RoutineLoader<RoutineQuickStart> {
  @override
  late final RoutineRepository repository =
      widget.repository ?? RoutineRepository();

  void _openManage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutinesScreen(
          workouts: widget.workouts,
          repository: repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded = routines;
    if (loaded == null || loaded.isEmpty) return const SizedBox.shrink();
    final shown = loaded.take(widget.maxRoutines).toList();
    return Column(
      key: const Key('home_routines'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          'Routines',
          trailing: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
            ),
            onPressed: _openManage,
            child: const Text('Manage'),
          ),
        ),
        // Intrinsic height (not a fixed 56) so large text still fits.
        SingleChildScrollView(
          padding: AppInsets.page,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: Gap.sm),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: kMinTouchTarget + 8),
                  child: _RoutineChip(
                    routine: shown[i],
                    onTap: () => startRoutine(
                        context, shown[i], widget.workouts,
                        repository: repository),
                    onLongPress: () =>
                        showRoutineActionSheet(context, shown[i], repository),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
