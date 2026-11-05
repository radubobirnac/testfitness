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
import 'package:testfitness/models/workout.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/repositories/metrics_repository.dart';
import 'package:testfitness/widgets/advanced_charts.dart';
import 'package:testfitness/widgets/weight_tracking_chart.dart';
import 'package:testfitness/widgets/volume_progression_chart.dart';
import 'package:testfitness/services/weight_tracking_service.dart';
import 'package:testfitness/services/export_import_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/accessibility_helper.dart';
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/widgets/animated_feedback.dart';

/// Progress tracking screen showing workout statistics and charts
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    // Load workouts when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          AccessibilityHelper.accessibleIconButton(
            icon: Icons.smart_toy,
            onPressed: () => _getAIInsights(context),
            semanticLabel: 'Get AI insights on your progress',
            tooltip: 'AI Insights',
          ),
          AccessibilityHelper.accessibleIconButton(
            icon: Icons.share,
            onPressed: () => _showExportOptions(context),
            semanticLabel: 'Export progress data',
            tooltip: 'Export Data',
          ),
          AccessibilityHelper.accessibleIconButton(
            icon: Icons.refresh,
            onPressed: () {
              context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
            },
            semanticLabel: 'Refresh progress data',
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocBuilder<WorkoutBloc, WorkoutState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.errorMessage}',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context
                          .read<WorkoutBloc>()
                          .add(const WorkoutLoadRequested());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final workouts = state.workouts;
          final completedWorkouts =
              workouts.where((w) => w.isCompleted).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Stats Cards
                _buildOverviewStats(workouts, completedWorkouts),
                const SizedBox(height: 24),

                // Weekly Progress Chart
                _buildWeeklyProgressChart(completedWorkouts),
                const SizedBox(height: 24),

                // Weight Tracking Chart
                WeightTrackingChart(
                  workouts: completedWorkouts,
                  title: 'Total Weight Lifted Over Time',
                ),
                const SizedBox(height: 24),

                // Volume Progression Chart
                VolumeProgressionChart(
                  workouts: completedWorkouts,
                  title: 'Volume Progression Analysis',
                ),
                const SizedBox(height: 24),

                // Exercise Distribution Chart
                AdvancedCharts.buildExerciseDistributionChart(
                    completedWorkouts, context),
                const SizedBox(height: 24),

                // Monthly Summary
                _buildMonthlySummary(completedWorkouts),
                const SizedBox(height: 24),

                // Recent Achievements
                _buildRecentAchievements(completedWorkouts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewStats(
      List<Workout> allWorkouts, List<Workout> completedWorkouts) {
    final totalWorkouts = allWorkouts.length;
    final completedCount = completedWorkouts.length;
    final completionRate =
        totalWorkouts > 0 ? (completedCount / totalWorkouts * 100) : 0.0;

    // Calculate total sets and exercises
    final totalSets =
        completedWorkouts.fold<int>(0, (sum, w) => sum + w.sets.length);
    final uniqueExercises =
        completedWorkouts.expand((w) => w.exerciseIds).toSet().length;

    // Calculate total weight lifted
    final weightStats =
        WeightTrackingService.getWeightTrackingStats(completedWorkouts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Workouts Completed',
                completedCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Completion Rate',
                '${completionRate.toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Weight Lifted',
                weightStats.formatWeight(weightStats.totalWeightLifted),
                Icons.fitness_center,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg per Workout',
                weightStats.formatWeight(weightStats.averagePerWorkout),
                Icons.trending_up,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Sets',
                totalSets.toString(),
                Icons.repeat,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Exercises Tried',
                uniqueExercises.toString(),
                Icons.sports_gymnastics,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressChart(List<Workout> completedWorkouts) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Progress',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSimpleWeeklyChart(completedWorkouts),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleWeeklyChart(List<Workout> completedWorkouts) {
    // Get last 7 days
    final now = DateTime.now();
    final weekData = <String, int>{};

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('E').format(date); // Mon, Tue, etc.
      weekData[dayKey] = 0;
    }

    // Count workouts for each day
    for (final workout in completedWorkouts) {
      if (workout.completedDate != null) {
        final daysDiff = now.difference(workout.completedDate!).inDays;
        if (daysDiff >= 0 && daysDiff < 7) {
          final dayKey = DateFormat('E').format(workout.completedDate!);
          weekData[dayKey] = (weekData[dayKey] ?? 0) + 1;
        }
      }
    }

    final maxCount = weekData.values.isEmpty
        ? 1
        : weekData.values.reduce((a, b) => a > b ? a : b);
    final chartHeight = 120.0;

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weekData.entries.map((entry) {
          final barHeight =
              maxCount > 0 ? (entry.value / maxCount) * chartHeight : 0.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                entry.value.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: barHeight.clamp(4.0, chartHeight),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.key,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlySummary(List<Workout> completedWorkouts) {
    final now = DateTime.now();
    final thisMonth = completedWorkouts.where((w) {
      if (w.completedDate == null) return false;
      final date = w.completedDate!;
      return date.year == now.year && date.month == now.month;
    }).toList();

    final lastMonth = completedWorkouts.where((w) {
      if (w.completedDate == null) return false;
      final date = w.completedDate!;
      final lastMonthDate = DateTime(now.year, now.month - 1);
      return date.year == lastMonthDate.year &&
          date.month == lastMonthDate.month;
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMonthlyStatItem(
                    'This Month',
                    thisMonth.length,
                    thisMonth.fold<int>(0, (sum, w) => sum + w.sets.length),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMonthlyStatItem(
                    'Last Month',
                    lastMonth.length,
                    lastMonth.fold<int>(0, (sum, w) => sum + w.sets.length),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStatItem(String title, int workouts, int sets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '$workouts workouts',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          '$sets sets',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildRecentAchievements(List<Workout> completedWorkouts) {
    // Sort by completion date (most recent first)
    final recentWorkouts = completedWorkouts
        .where((w) => w.completedDate != null)
        .toList()
      ..sort((a, b) => b.completedDate!.compareTo(a.completedDate!));

    final achievements = <String>[];

    // Add some simple achievements
    if (completedWorkouts.length >= 10) {
      achievements.add('🏆 Completed 10+ workouts');
    }
    if (completedWorkouts.length >= 5) {
      achievements.add('💪 Completed 5+ workouts');
    }
    if (recentWorkouts.isNotEmpty) {
      final lastWorkout = recentWorkouts.first;
      final daysSince =
          DateTime.now().difference(lastWorkout.completedDate!).inDays;
      if (daysSince == 0) {
        achievements.add('🔥 Worked out today');
      } else if (daysSince == 1) {
        achievements.add('⚡ Worked out yesterday');
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Achievements',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (achievements.isEmpty)
              Text(
                'Complete your first workout to unlock achievements!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              )
            else
              ...achievements.map((achievement) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Text(
                          achievement,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  /// Show export options dialog
  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export & Import Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
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
            const Divider(),
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
          backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
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
                  Column(
                    children: [
                      RadioListTile<ImportMode>(
                        title: const Text('Merge (recommended)'),
                        value: ImportMode.merge,
                        groupValue: selectedMode,
                        onChanged: isImporting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedMode = value;
                                  preview = null;
                                });
                              },
                      ),
                      RadioListTile<ImportMode>(
                        title: const Text('Replace all data'),
                        subtitle: const Text(
                          'Deletes existing workouts and exercises first',
                        ),
                        value: ImportMode.replaceAll,
                        groupValue: selectedMode,
                        onChanged: isImporting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  selectedMode = value;
                                  preview = null;
                                });
                              },
                      ),
                    ],
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
                      value: selectedProfile,
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
                    RadioListTile<ImportMode>(
                      title: const Text('Merge (recommended)'),
                      value: ImportMode.merge,
                      groupValue: selectedMode,
                      onChanged: isImporting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedMode = value;
                                preview = null;
                                pendingImport = null;
                              });
                            },
                    ),
                    RadioListTile<ImportMode>(
                      title: const Text('Replace all data'),
                      subtitle: const Text(
                        'Deletes existing workouts and exercises first',
                      ),
                      value: ImportMode.replaceAll,
                      groupValue: selectedMode,
                      onChanged: isImporting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedMode = value;
                                preview = null;
                                pendingImport = null;
                              });
                            },
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
                    style: const TextStyle(color: Colors.red),
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

    if (context.mounted) {
      context.read<WorkoutBloc>().add(const WorkoutLoadRequested());
      context.read<ExerciseBloc>().add(const ExerciseLoadRequested());
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
            const Text(
              'Import Preview',
              style: TextStyle(fontWeight: FontWeight.bold),
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
          backgroundColor: Colors.orange,
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
            title: const Row(
              children: [
                Icon(Icons.smart_toy, color: Colors.blue),
                SizedBox(width: 8),
                Text('AI Progress Insights'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Powered by Gemini 2.5 Flash Lite',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
          backgroundColor: Colors.red,
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
