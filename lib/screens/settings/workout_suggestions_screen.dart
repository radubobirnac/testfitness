import 'package:flutter/material.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/settings_group.dart';
import 'package:testfitness/utils/app_logger.dart';

/// Display names for the "Workout focus" values.
const Map<String, String> workoutFocusLabels = {
  'strength': 'Strength Focus',
  'endurance': 'Endurance Focus',
  'balanced': 'Balanced',
  'upper': 'Upper Body Priority',
  'lower': 'Lower Body Priority',
};

/// One-line summary of the workout-suggestion preferences, used as the
/// Profile row subtitle.
String workoutSuggestionsSummary(Map<String, dynamic> prefs) {
  final focus = workoutFocusLabels[prefs['workoutFocus']] ?? 'Balanced';
  final parts = prefs['defaultBodyParts'];
  final minutes = prefs['defaultDurationMinutes'];
  return '$focus · $parts body part${parts == 1 ? '' : 's'} · $minutes min';
}

/// Settings > Workout suggestions: preferences used by the coach (and AI, if
/// a key is set) when suggesting workouts. Stored via
/// [UserPreferencesService]; works without a user profile.
class WorkoutSuggestionsScreen extends StatefulWidget {
  const WorkoutSuggestionsScreen({super.key});

  @override
  State<WorkoutSuggestionsScreen> createState() =>
      _WorkoutSuggestionsScreenState();
}

class _WorkoutSuggestionsScreenState extends State<WorkoutSuggestionsScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();
  Map<String, dynamic> _prefs =
      Map<String, dynamic>.from(UserPreferencesService.defaultWorkoutPreferences);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _prefsService.initialize();
    if (!mounted) return;
    setState(() => _prefs = _prefsService.getWorkoutPreferences());
  }

  /// Update one preference: the UI first, then storage.
  Future<void> _update(String key, dynamic value) async {
    setState(() => _prefs = {..._prefs, key: value});
    try {
      await _prefsService.setWorkoutPreference(key, value);
    } catch (error) {
      AppLogger.error('Error saving workout preference: $key = $value', error);
    }
  }

  Future<void> _resetToDefaults() async {
    final defaults = UserPreferencesService.defaultWorkoutPreferences;
    setState(() => _prefs = Map<String, dynamic>.from(defaults));
    try {
      for (final entry in defaults.entries) {
        await _prefsService.setWorkoutPreference(entry.key, entry.value);
      }
    } catch (error) {
      AppLogger.error('Error resetting workout preferences', error);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workout suggestions reset to defaults')),
    );
  }

  static String _bodyPartsDescription(int count) {
    switch (count) {
      case 1:
        return 'Single body part workouts (focused)';
      case 3:
        return 'Three body parts (comprehensive)';
      case 2:
      default:
        return 'Two body parts (balanced)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyParts = (_prefs['defaultBodyParts'] as int).clamp(1, 3);
    final duration = (_prefs['defaultDurationMinutes'] as int).clamp(15, 90);
    final focus = _prefs['workoutFocus'] as String;
    final preferred = List<String>.from(_prefs['preferredBodyParts'] as List);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout suggestions')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
            child: Text(
              'Used by your coach (and AI, if a key is set) when suggesting '
              'workouts.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          SettingsGroup(
            title: 'Session',
            children: [
              SettingsSlider(
                title: 'Body parts per workout',
                valueLabel: '$bodyParts',
                helper: _bodyPartsDescription(bodyParts),
                slider: Slider(
                  key: const ValueKey('workout-body-parts-slider'),
                  min: 1,
                  max: 3,
                  divisions: 2,
                  value: bodyParts.toDouble(),
                  label: '$bodyParts',
                  onChanged: (v) => _update('defaultBodyParts', v.round()),
                ),
              ),
              SettingsSlider(
                title: 'Duration',
                valueLabel: '$duration min',
                slider: Slider(
                  key: const ValueKey('workout-duration-slider'),
                  min: 15,
                  max: 90,
                  divisions: 15,
                  value: duration.toDouble(),
                  label: '$duration min',
                  onChanged: (v) =>
                      _update('defaultDurationMinutes', v.round()),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('workout-exclude-core'),
                title: const Text('Exclude core exercises'),
                value: _prefs['excludeCore'] as bool,
                onChanged: (v) => _update('excludeCore', v),
              ),
            ],
          ),
          SettingsGroup(
            title: 'Focus',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: DropdownButtonFormField<String>(
                  // Keyed on the value so a value loaded after the first
                  // build is shown (initialValue is only read once).
                  key: ValueKey('workout-focus-$focus'),
                  initialValue: focus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Workout focus',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in UserPreferencesService
                        .workoutFocusValues)
                      DropdownMenuItem(
                        value: value,
                        child: Text(workoutFocusLabels[value] ?? value,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _update('workoutFocus', value);
                  },
                ),
              ),
            ],
          ),
          SettingsGroup(
            title: 'Preferred body parts',
            children: [
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prioritized in suggested workouts',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final part in UserPreferencesService.workoutBodyParts)
                          FilterChip(
                            key: ValueKey('workout-body-part-$part'),
                            label: Text(part),
                            selected: preferred.contains(part),
                            onSelected: (selected) {
                              final updated = List<String>.from(preferred);
                              selected
                                  ? updated.add(part)
                                  : updated.remove(part);
                              _update('preferredBodyParts', updated);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Center(
            child: TextButton.icon(
              key: const ValueKey('workout-suggestions-reset'),
              style: TextButton.styleFrom(
                  minimumSize: const Size(kMinTouchTarget, kMinTouchTarget)),
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset to defaults'),
            ),
          ),
        ],
      ),
    );
  }
}
