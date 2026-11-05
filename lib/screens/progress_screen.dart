import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:testfitness/blocs/exercise/exercise_bloc.dart';
import 'package:testfitness/blocs/exercise/exercise_event.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/workout/workout_event.dart';
import 'package:testfitness/blocs/workout/workout_state.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/models/fitness_metric.dart';
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/repositories/metrics_repository.dart';
import 'package:testfitness/screens/exercise_history_screen.dart';
import 'package:testfitness/services/export_import_service.dart';
import 'package:testfitness/services/progression_coach.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/progress_period.dart';
import 'package:testfitness/ui/progress_widgets.dart';
import 'package:testfitness/utils/accessibility_helper.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/widgets/animated_feedback.dart';
import 'package:testfitness/widgets/body_weight_chart.dart';
import 'package:testfitness/widgets/muscle_balance_chart.dart';
import 'package:testfitness/widgets/volume_progression_chart.dart';
import 'package:testfitness/widgets/weekly_check_in_card.dart';
import 'package:testfitness/widgets/workout_frequency_chart.dart';

/// Overflow-menu entries in the Progress app bar.
enum ProgressMenuAction { export, import, refresh }

/// Progress tab: one scroll with "This week", a period selector, then
/// Strength, Body and Top exercises sections. Export/Import live in the
/// app-bar overflow menu.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    this.clock,
    this.loadExercises,
    this.loadBodyWeight,
  });

  /// Defaults to [DateTime.now]; tests pin it.
  final DateTime Function()? clock;

  /// Exercise library used for names and muscle groups. Defaults to the
  /// ExerciseBloc state, falling back to [ExerciseRepository].
  final Future<List<Exercise>> Function()? loadExercises;

  /// Body-weight entries ([MetricType.weight]). Defaults to
  /// [MetricsRepository.getMetricsByType].
  final Future<List<FitnessMetric>> Function()? loadBodyWeight;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<String, Exercise> _exercisesById = const {};
  List<FitnessMetric> _bodyWeight = const [];
  ProgressPeriod _period = ProgressPeriod.threeMonths;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _loadExercisesForCoach();
    _loadBodyWeight();
    // Load workouts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
    });
  }

  void _refresh() {
    context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
    _loadBodyWeight();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          AccessibilityHelper.accessibleIconButton(
            icon: Icons.smart_toy_outlined,
            onPressed: () => _getAIInsights(context),
            semanticLabel: 'Get AI insights on your progress',
            tooltip: 'AI Insights',
          ),
          PopupMenuButton<ProgressMenuAction>(
            key: const Key('progress_menu'),
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case ProgressMenuAction.export:
                  _showExportOptions(context);
                case ProgressMenuAction.import:
                  _showImportOptions(context);
                case ProgressMenuAction.refresh:
                  _refresh();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ProgressMenuAction.export,
                child: ListTile(
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('Export data'),
                  subtitle: Text('Report, CSV or JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: ProgressMenuAction.import,
                child: ListTile(
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Import data'),
                  subtitle: Text('JSON or CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: ProgressMenuAction.refresh,
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<WorkoutBloc, WorkoutState>(
        builder: (context, state) {
          // Spinner only on the first load; reloads keep content on screen.
          if (state.isLoading && state.workouts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.errorMessage != null) {
            final theme = Theme.of(context);
            return Center(
              child: Padding(
                padding: AppInsets.page,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: theme.colorScheme.error),
                    const SizedBox(height: Gap.lg),
                    Text(
                      'Error: ${state.errorMessage}',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Gap.lg),
                    FilledButton(
                      onPressed: () {
                        context
                            .read<WorkoutBloc>()
                            .add(const WorkoutLoadRequested());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildContent(context, state.workouts);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Workout> workouts) {
    final now = _now;
    final prefs = UserPreferencesService();
    final unit = prefs.getWeightUnitLabel().toLowerCase();
    final window = ProgressMath.window(
      _period,
      now,
      earliest: ProgressMath.earliestDate(workouts),
    );

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: CustomScrollView(
        key: const PageStorageKey('progress_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildPeriodSelector()),
          const SliverToBoxAdapter(child: SectionHeader('This week')),
          SliverToBoxAdapter(child: _buildWeeklyCheckIn(workouts, now)),
          SliverToBoxAdapter(child: SectionHeader('Strength')),
          ..._buildStrength(context, workouts, window, unit),
          const SliverToBoxAdapter(child: SectionHeader('Body')),
          SliverToBoxAdapter(child: _buildBody(window, prefs)),
          const SliverToBoxAdapter(child: SectionHeader('Top exercises')),
          SliverToBoxAdapter(
              child: _buildTopExercises(context, workouts, window, unit, now)),
          const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
        ],
      ),
    );
  }

  Future<void> _loadExercisesForCoach() async {
    try {
      final List<Exercise> exercises;
      if (widget.loadExercises != null) {
        exercises = await widget.loadExercises!();
      } else {
        final exerciseState = context.read<ExerciseBloc>().state;
        exercises = exerciseState.exercises.isNotEmpty
            ? exerciseState.exercises
            : await ExerciseRepository().getExercises();
      }
      if (!mounted) return;
      setState(() {
        _exercisesById = {for (final e in exercises) e.id: e};
      });
    } catch (_) {
      // Check-in still renders without names/muscle groups.
    }
  }

  Future<void> _loadBodyWeight() async {
    try {
      final entries = widget.loadBodyWeight != null
          ? await widget.loadBodyWeight!()
          : await MetricsRepository().getMetricsByType(MetricType.weight);
      if (!mounted) return;
      setState(() {
        _bodyWeight = [...entries]..sort((a, b) => a.date.compareTo(b.date));
      });
    } catch (_) {
      // Body section shows its empty state.
    }
  }

  Widget _buildWeeklyCheckIn(List<Workout> workouts, DateTime now) {
    final prefs = UserPreferencesService();
    WeeklyCheckIn? checkIn;
    try {
      checkIn = ProgressionCoach(useMetric: prefs.getUseMetricUnits())
          .weeklyCheckIn(workouts, _exercisesById, now: now);
    } catch (_) {
      checkIn = null;
    }
    return WeeklyCheckInCard(
      checkIn: checkIn,
      exercisesById: _exercisesById,
      weightUnitLabel: prefs.getWeightUnitLabel(),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xs),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ProgressPeriod>(
          key: const Key('progress_period'),
          showSelectedIcon: false,
          segments: [
            for (final p in ProgressPeriod.values)
              ButtonSegment(
                value: p,
                label: Text(p.label),
                tooltip: 'Show ${p.description}',
              ),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
      ),
    );
  }

  List<Widget> _buildStrength(
    BuildContext context,
    List<Workout> workouts,
    PeriodWindow window,
    String unit,
  ) {
    final totals = window.isEmpty
        ? PeriodTotals.zero
        : ProgressMath.totals(workouts, window.start, window.end);

    if (totals.sets == 0) {
      return [
        SliverToBoxAdapter(
          child: ProgressCard(
            child: ProgressEmptyHint(
              key: const Key('progress_strength_empty'),
              icon: Icons.show_chart,
              message: _period == ProgressPeriod.all
                  ? 'Finish a workout to start your strength charts.'
                  : 'No workouts in the ${_period.description} — '
                      'pick a longer range or log a session.',
            ),
          ),
        ),
      ];
    }

    PeriodTotals? previous;
    if (window.previousStart != null) {
      previous =
          ProgressMath.totals(workouts, window.previousStart!, window.start);
    }
    String? changeText(num current, num? before) {
      final pct = ProgressMath.changePercent(
          current.toDouble(), before?.toDouble());
      return pct == null ? null : ProgressMath.formatChange(pct);
    }

    bool? up(num current, num? before) => ProgressMath.changePercent(
                current.toDouble(), before?.toDouble()) ==
            null
        ? null
        : current >= before!;

    final completed = workouts.where((w) => w.isCompleted).length;
    final rate = workouts.isEmpty ? 0.0 : completed / workouts.length * 100;
    final exercisesTried = workouts
        .where((w) => w.isCompleted)
        .expand((w) => w.exerciseIds)
        .toSet()
        .length;
    final theme = Theme.of(context);

    return [
      SliverToBoxAdapter(
        child: ProgressCard(
          key: const Key('progress_period_stats'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressStatRow(tiles: [
                ProgressStatTile(
                  label: 'Workouts',
                  value: '${totals.workouts}',
                  change: changeText(totals.workouts, previous?.workouts),
                  changeUp: up(totals.workouts, previous?.workouts),
                ),
                ProgressStatTile(
                  label: 'Sets',
                  value: '${totals.sets}',
                  change: changeText(totals.sets, previous?.sets),
                  changeUp: up(totals.sets, previous?.sets),
                ),
                ProgressStatTile(
                  label: 'Volume',
                  value: '${ProgressMath.formatVolume(totals.volume)} $unit',
                  change: changeText(totals.volume, previous?.volume),
                  changeUp: up(totals.volume, previous?.volume),
                ),
              ]),
              const SizedBox(height: Gap.sm),
              Text(
                previous == null
                    ? 'All time: $completed workouts · '
                        '${rate.toStringAsFixed(0)}% of planned completed · '
                        '$exercisesTried exercises tried'
                    : 'Change vs the previous ${_period.description.replaceFirst('last ', '')}'
                        ' · all time: $completed workouts, '
                        '${rate.toStringAsFixed(0)}% completed, '
                        '$exercisesTried exercises',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: VolumeProgressionChart(
          key: const Key('progress_volume_chart'),
          window: window,
          values: ProgressMath.volumePerBucket(workouts, window),
          unitLabel: unit,
        ),
      ),
      SliverToBoxAdapter(
        child: WorkoutFrequencyChart(
          key: const Key('progress_frequency_chart'),
          window: window,
          counts: ProgressMath.workoutsPerBucket(workouts, window),
        ),
      ),
      SliverToBoxAdapter(
        child: Builder(builder: (context) {
          final groups = ProgressMath.setsPerMuscleGroup(
              workouts, _exercisesById, window);
          if (groups.isEmpty) return const SizedBox.shrink();
          return MuscleBalanceChart(
            key: const Key('progress_muscle_balance'),
            entries: groups,
            caption: 'Completed working sets, ${_period.description}',
          );
        }),
      ),
    ];
  }

  Widget _buildBody(PeriodWindow window, UserPreferencesService prefs) {
    if (_bodyWeight.isEmpty) {
      return const ProgressCard(
        child: ProgressEmptyHint(
          key: Key('progress_body_empty'),
          icon: Icons.monitor_weight_outlined,
          message: 'No body-weight entries yet. Entries restored from a JSON '
              'backup appear here.',
        ),
      );
    }
    final inRange = window.isEmpty
        ? _bodyWeight
        : _bodyWeight.where((m) => !m.date.isBefore(window.start)).toList();
    if (inRange.isEmpty) {
      return ProgressCard(
        child: ProgressEmptyHint(
          key: const Key('progress_body_empty'),
          icon: Icons.monitor_weight_outlined,
          message: 'No body-weight entries in the ${_period.description}.',
        ),
      );
    }
    return BodyWeightChart(
      key: const Key('progress_body_chart'),
      entries: inRange,
      unitLabel: prefs.getUseMetricUnits() ? 'kg' : 'lbs',
      caption: '${inRange.length} entries, ${_period.description}',
    );
  }

  Widget _buildTopExercises(
    BuildContext context,
    List<Workout> workouts,
    PeriodWindow window,
    String unit,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = window.isEmpty
        ? const <ExerciseVolume>[]
        : ProgressMath.topExercises(workouts, window, limit: 5)
            .where((e) => _exercisesById.containsKey(e.exerciseId))
            .toList();
    if (top.isEmpty) {
      return const ProgressCard(
        child: ProgressEmptyHint(
          key: Key('progress_exercises_empty'),
          icon: Icons.fitness_center,
          message: 'Your most-trained exercises in this range show up here.',
        ),
      );
    }

    final coach = ProgressionCoach(
        useMetric: UserPreferencesService().getUseMetricUnits());
    return ProgressCard(
      key: const Key('progress_top_exercises'),
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xs),
            child: Text(
              'By volume, ${_period.description} · tap for history',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          for (final e in top)
            Builder(builder: (context) {
              final exercise = _exercisesById[e.exerciseId]!;
              final change = coach
                  .trend(e.exerciseId, workouts, weeks: 8, now: now)
                  .changePercent;
              return ListTile(
                key: Key('progress_exercise_${e.exerciseId}'),
                minTileHeight: kMinTouchTarget,
                title: Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                subtitle: Text(
                  '${ProgressMath.formatVolume(e.volume)} $unit · '
                  '${e.sessions} session${e.sessions == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          change == null
                              ? '—'
                              : ProgressMath.formatChange(change),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: change == null
                                ? scheme.onSurfaceVariant
                                : change >= 0
                                    ? scheme.primary
                                    : scheme.error,
                          ),
                        ),
                        Text(
                          '8-wk e1RM',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(width: Gap.xs),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ExerciseHistoryScreen(
                    exercise: exercise,
                    workouts: workouts,
                  ),
                )),
              );
            }),
        ],
      ),
    );
  }

  /// Export sheet (opened from the overflow menu).
  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
              child: Text(
                'Export data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            AccessibilityHelper.accessibleListTile(
              leading: const Icon(Icons.description),
              title: const Text('Progress Report'),
              subtitle: const Text('Detailed progress summary'),
              semanticLabel: 'Export progress report',
              onTap: () => _exportProgressReport(context),
            ),
            AccessibilityHelper.accessibleListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV Data'),
              subtitle: const Text('Workout data in spreadsheet format'),
              semanticLabel: 'Export CSV data',
              onTap: () => _exportCsvData(context),
            ),
            AccessibilityHelper.accessibleListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON Backup'),
              subtitle: const Text('Complete data backup'),
              semanticLabel: 'Export JSON backup',
              onTap: () => _exportJsonBackup(context),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  /// Import sheet (opened from the overflow menu).
  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
              child: Text(
                'Import data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            AccessibilityHelper.accessibleListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Import File (JSON/CSV)'),
              subtitle: const Text('Restore or merge workout data'),
              semanticLabel: 'Import JSON or CSV file',
              onTap: () => _showFileImportDialog(context),
            ),
            AccessibilityHelper.accessibleListTile(
              leading: const Icon(Icons.paste),
              title: const Text('Paste JSON Backup'),
              subtitle: const Text('Paste JSON from clipboard'),
              semanticLabel: 'Import JSON backup via paste',
              onTap: () => _showImportDialog(context),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  /// Export progress report
  Future<void> _exportProgressReport(BuildContext context) async {
    Navigator.pop(context);

    try {
      final workouts = context.read<WorkoutBloc>().state.workouts;
      final report =
          await ExportImportService.generateProgressReport(workouts, null);

      await ExportImportService.shareContent(
        report,
        'StrengthWave_Progress_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.md',
        'text/markdown',
      );

      AccessibilityHelper.announceMessage(
          'Progress report exported successfully');
    } catch (error) {
      if (context.mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          'Export failed: $error',
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  /// Export CSV data
  Future<void> _exportCsvData(BuildContext context) async {
    Navigator.pop(context);

    try {
      final workouts = context.read<WorkoutBloc>().state.workouts;
      final exercises = await _getExercisesForExport();
      final csvData = await ExportImportService.exportToCsv(
        workouts,
        exercises: exercises,
      );
      final filename =
          'StrengthWave_Data_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
      final savedPath =
          await ExportImportService.saveContentToFile(csvData, filename);
      if (savedPath == null) {
        await ExportImportService.shareContent(
          csvData,
          filename,
          'text/csv',
        );
      }

      AccessibilityHelper.announceMessage('CSV data exported successfully');
    } catch (error) {
      if (context.mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          'Export failed: $error',
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  /// Export JSON backup
  Future<void> _exportJsonBackup(BuildContext context) async {
    Navigator.pop(context);

    try {
      final workouts = context.read<WorkoutBloc>().state.workouts;
      final exercises = await _getExercisesForExport();
      final preferences = await _getPreferencesForExport();
      final metrics = await MetricsRepository().getMetrics();
      final jsonData = await ExportImportService.exportToJson(
        workouts: workouts,
        exercises: exercises,
        metrics: metrics,
        userPreferences: preferences,
      );
      final filename =
          'StrengthWave_Backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final savedPath =
          await ExportImportService.saveContentToFile(jsonData, filename);
      if (savedPath == null) {
        await ExportImportService.shareContent(
          jsonData,
          filename,
          'application/json',
        );
      }

      AccessibilityHelper.announceMessage('JSON backup exported successfully');
    } catch (error) {
      if (context.mounted) {
        AnimatedFeedback.showSnackBar(
          context,
          'Export failed: $error',
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<List<Exercise>> _getExercisesForExport() async {
    final exerciseState = context.read<ExerciseBloc>().state;
    if (exerciseState.exercises.isNotEmpty) {
      return exerciseState.exercises;
    }

    final exerciseRepository = ExerciseRepository();
    return await exerciseRepository.getExercises();
  }

  Future<Map<String, dynamic>> _getPreferencesForExport() async {
    return await UserPreferencesService().exportPreferences();
  }

  void _showImportDialog(BuildContext context) {
    Navigator.pop(context);
    final controller = TextEditingController();
    String? errorMessage;
    bool isImporting = false;
    ImportMode selectedMode = ImportMode.merge;
    ImportPreview? preview;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Import JSON Backup'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paste your StrengthWave JSON backup below. Import will merge data by ID.',
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<ImportMode>(
                    groupValue: selectedMode,
                    onChanged: (value) {
                      if (isImporting || value == null) return;
                      setDialogState(() {
                        selectedMode = value;
                        preview = null;
                      });
                    },
                    child: Column(
                      children: [
                        RadioListTile<ImportMode>(
                          title: const Text('Merge (recommended)'),
                          value: ImportMode.merge,
                          enabled: !isImporting,
                        ),
                        RadioListTile<ImportMode>(
                          title: const Text('Replace all data'),
                          subtitle: const Text(
                            'Deletes existing workouts and exercises first',
                          ),
                          value: ImportMode.replaceAll,
                          enabled: !isImporting,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: '{"metadata": {...}, "workouts": [...]}',
                      errorText: errorMessage,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 12),
                    _buildImportPreviewCard(preview!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        final clipboard =
                            await Clipboard.getData('text/plain');
                        if (clipboard?.text != null) {
                          controller.text = clipboard!.text!;
                          setDialogState(() {
                            errorMessage = null;
                          });
                        }
                      },
                child: const Text('Paste'),
              ),
              TextButton(
                onPressed: isImporting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        final jsonString = controller.text.trim();
                        if (jsonString.isEmpty) {
                          setDialogState(() {
                            errorMessage = 'Paste JSON to preview';
                          });
                          return;
                        }

                        setDialogState(() {
                          isImporting = true;
                          errorMessage = null;
                        });

                        try {
                          final result =
                              await ExportImportService.importFromJson(
                            jsonString,
                          );
                          final importPreview =
                              await _buildImportPreview(result, selectedMode);
                          setDialogState(() {
                            preview = importPreview;
                          });
                        } catch (error) {
                          setDialogState(() {
                            errorMessage = 'Preview failed: $error';
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isImporting = false;
                            });
                          }
                        }
                      },
                child: const Text('Preview'),
              ),
              ElevatedButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        final jsonString = controller.text.trim();
                        if (jsonString.isEmpty) {
                          setDialogState(() {
                            errorMessage = 'Paste JSON to import';
                          });
                          return;
                        }

                        setDialogState(() {
                          isImporting = true;
                          errorMessage = null;
                        });

                        try {
                          await _handleImportContent(
                            jsonString,
                            selectedMode,
                            previewOverride: preview,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (error) {
                          setDialogState(() {
                            errorMessage = 'Import failed: $error';
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isImporting = false;
                            });
                          }
                        }
                      },
                child: isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  void _showFileImportDialog(BuildContext context) {
    Navigator.pop(context);
    String? errorMessage;
    bool isImporting = false;
    ImportMode selectedMode = ImportMode.merge;
    CsvImportProfile selectedProfile = CsvImportProfile.auto;
    ImportPreview? preview;
    ImportResult? pendingImport;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Import File'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose a JSON or CSV file to import.',
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    DropdownButtonFormField<CsvImportProfile>(
                      initialValue: selectedProfile,
                      decoration: const InputDecoration(
                        labelText: 'CSV format',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: CsvImportProfile.auto,
                          child: Text('Auto-detect'),
                        ),
                        DropdownMenuItem(
                          value: CsvImportProfile.strengthWave,
                          child: Text('StrengthWave'),
                        ),
                        DropdownMenuItem(
                          value: CsvImportProfile.generic,
                          child: Text('Generic CSV'),
                        ),
                        DropdownMenuItem(
                          value: CsvImportProfile.strong,
                          child: Text('Strong'),
                        ),
                        DropdownMenuItem(
                          value: CsvImportProfile.hevy,
                          child: Text('Hevy'),
                        ),
                      ],
                      onChanged: isImporting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedProfile = value;
                                preview = null;
                                pendingImport = null;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<ImportMode>(
                      groupValue: selectedMode,
                      onChanged: (value) {
                        if (isImporting || value == null) return;
                        setDialogState(() {
                          selectedMode = value;
                          preview = null;
                          pendingImport = null;
                        });
                      },
                      child: Column(
                        children: [
                          RadioListTile<ImportMode>(
                            title: const Text('Merge (recommended)'),
                            value: ImportMode.merge,
                            enabled: !isImporting,
                          ),
                          RadioListTile<ImportMode>(
                            title: const Text('Replace all data'),
                            subtitle: const Text(
                              'Deletes existing workouts and exercises first',
                            ),
                            value: ImportMode.replaceAll,
                            enabled: !isImporting,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (preview != null) ...[
                  const SizedBox(height: 12),
                  _buildImportPreviewCard(preview!),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isImporting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isImporting || pendingImport == null
                    ? null
                    : () async {
                        setDialogState(() {
                          isImporting = true;
                        });

                        try {
                          await _applyImportResultWithPreview(
                            pendingImport!,
                            selectedMode,
                            preview!,
                          );

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (error) {
                          setDialogState(() {
                            errorMessage = 'Import failed: $error';
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isImporting = false;
                            });
                          }
                        }
                      },
                child: const Text('Import'),
              ),
              ElevatedButton(
                onPressed: isImporting
                    ? null
                    : () async {
                        setDialogState(() {
                          isImporting = true;
                          errorMessage = null;
                        });

                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['json', 'csv'],
                          );

                          if (result == null || result.files.isEmpty) {
                            setDialogState(() {
                              isImporting = false;
                            });
                            return;
                          }

                          final file = result.files.first;
                          final content = await _readPickedFile(file);
                          final importResult = await _parseImportContent(
                            content,
                            selectedProfile,
                          );
                          final importPreview =
                              await _buildImportPreview(
                            importResult,
                            selectedMode,
                          );
                          setDialogState(() {
                            preview = importPreview;
                            pendingImport = importResult;
                          });
                        } catch (error) {
                          setDialogState(() {
                            errorMessage = 'Import failed: $error';
                          });
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isImporting = false;
                            });
                          }
                        }
                      },
                child: isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Choose File'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _readPickedFile(PlatformFile file) async {
    if (file.bytes != null) {
      return String.fromCharCodes(file.bytes!);
    }

    if (!kIsWeb && file.path != null) {
      return File(file.path!).readAsString();
    }

    throw Exception('Unable to read selected file');
  }

  Future<void> _handleImportContent(
    String content,
    ImportMode mode, {
    CsvImportProfile profile = CsvImportProfile.auto,
    ImportPreview? previewOverride,
  }) async {
    final result = await _parseImportContent(content, profile);
    final preview =
        previewOverride ?? await _buildImportPreview(result, mode);
    await _applyImportResultWithPreview(result, mode, preview);
  }

  Future<ImportResult> _parseImportContent(
    String content,
    CsvImportProfile profile,
  ) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('Import content is empty');
    }

    if (trimmed.startsWith('{')) {
      return await ExportImportService.importFromJson(trimmed);
    }

    return await ExportImportService.importFromCsv(
      trimmed,
      profile: profile,
    );
  }

  Future<void> _applyImportResultWithPreview(
    ImportResult result,
    ImportMode mode,
    ImportPreview preview,
  ) async {
    final backupPath = await ExportImportService.applyImportResult(
      result,
      mode: mode,
    );

    if (mounted) {
      context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
      context.read<ExerciseBloc>().add(const ExerciseLoadRequested());
      _loadBodyWeight();
      await _showImportSummary(result, mode, backupPath);
      AccessibilityHelper.announceMessage('Import completed');
    }
  }

  Future<void> _showImportSummary(
    ImportResult result,
    ImportMode mode,
    String? backupPath,
  ) async {
    final modeLabel = mode == ImportMode.replaceAll ? 'Replace All' : 'Merge';
    final backupMessage = backupPath != null
        ? 'Rollback backup saved:\n$backupPath'
        : (mode == ImportMode.replaceAll
            ? 'Rollback backup not available on web.'
            : 'No rollback backup was created.');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imported ${result.workouts.length} workouts and ${result.exercises.length} exercises.',
            ),
            const SizedBox(height: 8),
            Text('Mode: $modeLabel'),
            const SizedBox(height: 8),
            Text(backupMessage),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<ImportPreview> _buildImportPreview(
    ImportResult result,
    ImportMode mode,
  ) async {
    final existingWorkouts = context.read<WorkoutBloc>().state.workouts;
    final existingExercises = await _getExercisesForExport();

    final existingWorkoutIds =
        existingWorkouts.map((w) => w.id).toSet();
    final existingExerciseIds =
        existingExercises.map((e) => e.id).toSet();
    final existingExerciseKeys = existingExercises
        .map((e) =>
            '${e.name.trim().toLowerCase()}|${(e.category ?? '').trim().toLowerCase()}')
        .toSet();

    var newWorkouts = 0;
    var overwriteWorkouts = 0;
    for (final workout in result.workouts) {
      if (existingWorkoutIds.contains(workout.id)) {
        overwriteWorkouts++;
      } else {
        newWorkouts++;
      }
    }

    var newExercises = 0;
    var overwriteExercises = 0;
    for (final exercise in result.exercises) {
      final key =
          '${exercise.name.trim().toLowerCase()}|${(exercise.category ?? '').trim().toLowerCase()}';
      if (existingExerciseIds.contains(exercise.id) ||
          existingExerciseKeys.contains(key)) {
        overwriteExercises++;
      } else {
        newExercises++;
      }
    }

    return ImportPreview(
      totalWorkouts: result.workouts.length,
      totalExercises: result.exercises.length,
      newWorkouts: newWorkouts,
      overwriteWorkouts: overwriteWorkouts,
      newExercises: newExercises,
      overwriteExercises: overwriteExercises,
      mode: mode,
    );
  }

  Widget _buildImportPreviewCard(ImportPreview preview) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Preview',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('Workouts: ${preview.totalWorkouts}'),
            Text('Exercises: ${preview.totalExercises}'),
            const SizedBox(height: 8),
            Text('New workouts: ${preview.newWorkouts}'),
            Text('Overwritten workouts: ${preview.overwriteWorkouts}'),
            Text('New exercises: ${preview.newExercises}'),
            Text('Matched exercises: ${preview.overwriteExercises}'),
            const SizedBox(height: 8),
            Text(
              preview.mode == ImportMode.replaceAll
                  ? 'Mode: Replace All (backup created)'
                  : 'Mode: Merge',
            ),
          ],
        ),
      ),
    );
  }

  /// Get AI insights on progress
  Future<void> _getAIInsights(BuildContext context) async {
    try {
      final aiService = AIService();

      if (!aiService.isAvailable) {
        AnimatedFeedback.showSnackBar(
          context,
          'AI insights require an internet connection',
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('AI is analyzing your progress...'),
            ],
          ),
        ),
      );

      final workouts = context.read<WorkoutBloc>().state.workouts;
      final completedWorkouts = workouts.where((w) => w.isCompleted).toList();

      final insights = await aiService.analyzeProgress(
        completedWorkouts: completedWorkouts,
        timeframe: 'month',
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.smart_toy,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Flexible(child: Text('AI Progress Insights')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Powered by Gemini 2.5 Flash Lite',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(insights),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );

        AccessibilityHelper.announceMessage('AI insights generated');
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open

        AnimatedFeedback.showSnackBar(
          context,
          'Failed to get AI insights: $error',
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }
}

class ImportPreview {
  final int totalWorkouts;
  final int totalExercises;
  final int newWorkouts;
  final int overwriteWorkouts;
  final int newExercises;
  final int overwriteExercises;
  final ImportMode mode;

  const ImportPreview({
    required this.totalWorkouts,
    required this.totalExercises,
    required this.newWorkouts,
    required this.overwriteWorkouts,
    required this.newExercises,
    required this.overwriteExercises,
    required this.mode,
  });
}
