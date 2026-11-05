import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/app/app_state.dart';
import 'package:testfitness/services/api_key_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/services/user_profile_service.dart';
import 'package:testfitness/services/enhanced_tts_service.dart';
import 'package:testfitness/models/user_profile.dart';
import 'package:testfitness/screens/app_loader.dart'
    show darkModePreferenceKey, userThemeOverride;
import 'package:testfitness/screens/ai_chat_screen.dart';
import 'package:testfitness/screens/settings/developer_screen.dart';
import 'package:testfitness/screens/settings/rest_timer_sheet.dart';
import 'package:testfitness/screens/settings/voice_settings_screen.dart';
import 'package:testfitness/screens/settings/workout_suggestions_screen.dart';
import 'package:testfitness/ui/app_ui.dart';
import 'package:testfitness/ui/settings_group.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/app_version_text.dart';
import 'package:testfitness/widgets/plate_calculator_sheet.dart';
import 'package:testfitness/utils/plate_math.dart';

enum _ApiKeyDialogResult { save, clear }

/// Theme choices offered in Settings > Appearance.
enum _ThemeChoice { system, light, dark }

/// Profile & Settings tab: a compact profile header followed by a grouped
/// settings list (Training, Workout suggestions, Voice & speech, Appearance,
/// AI, Developer, About). Larger groups open subpages in
/// `lib/screens/settings/`.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.versionLoader});

  /// Injectable for tests; defaults to [PackageInfo.fromPlatform].
  final Future<PackageInfo> Function()? versionLoader;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Preference keys for AppBloc integration
  static const String _timerDurationKey =
      UserPreferencesService.restTimerDurationKey;
  static const String _useMetricUnitsKey =
      UserPreferencesService.useMetricUnitsKey;
  static const String _playSoundOnTimerEndKey =
      UserPreferencesService.playSoundOnTimerEndKey;

  final UserProfileService _profileService = UserProfileService();
  final UserPreferencesService _prefsService = UserPreferencesService();
  final EnhancedTTSService _ttsService = EnhancedTTSService();
  late final Future<PackageInfo> _versionFuture =
      (widget.versionLoader ?? PackageInfo.fromPlatform)();
  UserProfile? _userProfile;

  bool _smartRest = UserPreferencesService.defaultSmartRestEnabled;
  Map<String, dynamic> _workoutPrefs =
      Map<String, dynamic>.from(UserPreferencesService.defaultWorkoutPreferences);

  @override
  void initState() {
    super.initState();
    // Re-read stored settings into AppBloc. Read-only: never writes defaults.
    context.read<AppBloc>().add(const AppPreferencesReloaded());
    _loadLocalPreferences();
    _loadUserProfile();
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    try {
      await _ttsService.initialize();
      // Refresh the Voice & speech row subtitle with the stored values.
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.error('ProfileScreen: TTS initialization failed', e);
    }
  }

  Future<void> _loadUserProfile() async {
    final profile = await _profileService.loadProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }
  }

  Future<void> _loadLocalPreferences() async {
    await _prefsService.initialize();
    if (!mounted) return;
    setState(() {
      _smartRest = _prefsService.getSmartRestEnabled();
      _workoutPrefs = _prefsService.getWorkoutPreferences();
    });
  }

  void _updatePreference(String key, dynamic value) {
    AppLogger.debug('ProfileScreen: Updating preference $key = $value');
    context.read<AppBloc>().add(AppPreferencesUpdated({key: value}));
  }

  Future<void> _setSmartRest(bool enabled) async {
    setState(() => _smartRest = enabled);
    await _prefsService.setSmartRestEnabled(enabled);
  }

  void _showProfileEditor() {
    showDialog(
      context: context,
      builder: (context) => _ProfileEditorDialog(
        currentProfile: _userProfile,
        onProfileSaved: (profile) {
          setState(() {
            _userProfile = profile;
          });
        },
      ),
    );
  }

  /// Push a settings subpage, then refresh the row subtitles it may change.
  Future<void> _openSubpage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    await _loadLocalPreferences();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppBloc, AppState>(
      listener: (context, state) {
        // Handle side effects
        if (state.errorMessage != null) {
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!,
                  style: TextStyle(color: colorScheme.onError)),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        // Get preferences from AppBloc state
        // Fall back to the stored values (not hard-coded defaults).
        final timerDuration = state.preferences[_timerDurationKey] as int? ??
            _prefsService.getRestTimerDuration();
        final useMetricUnits = state.preferences[_useMetricUnitsKey] as bool? ??
            _prefsService.getUseMetricUnits();
        final playSoundOnTimerEnd =
            state.preferences[_playSoundOnTimerEndKey] as bool? ??
                _prefsService.getPlaySoundOnTimerEnd();

        return Scaffold(
          appBar: AppBar(title: const Text('Profile & Settings')),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  key: const ValueKey('profile-settings-list'),
                  padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xl),
                  children: [
                    _buildProfileHeader(context),
                    const SizedBox(height: Gap.sm),
                    SettingsGroup(
                      title: 'Training',
                      children: [
                        _buildWeightUnitTile(context, useMetricUnits),
                        _buildRestTimerTile(context, timerDuration),
                        _buildBarAndPlatesTile(context, useMetricUnits),
                        _buildTimerSoundTile(playSoundOnTimerEnd),
                      ],
                    ),
                    SettingsGroup(
                      title: 'Workout suggestions',
                      children: [
                        ListTile(
                          key: const ValueKey('settings-workout-suggestions'),
                          leading: const Icon(Icons.tune),
                          title: const Text('Workout suggestions'),
                          subtitle: Text(
                              workoutSuggestionsSummary(_workoutPrefs),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _openSubpage(const WorkoutSuggestionsScreen()),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      title: 'Voice & speech',
                      children: [
                        ListTile(
                          key: const ValueKey('settings-voice'),
                          leading: const Icon(Icons.record_voice_over_outlined),
                          title: const Text('Voice coaching'),
                          subtitle: Text(voiceSettingsSummary(_ttsService),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _openSubpage(const VoiceSettingsScreen()),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      title: 'Appearance',
                      children: [_buildThemeSetting(context, state.isDarkMode)],
                    ),
                    SettingsGroup(
                      title: 'AI',
                      children: [
                        _buildGeminiKeyTile(),
                        ListTile(
                          key: const ValueKey('settings-ai-chat'),
                          leading: const Icon(Icons.smart_toy_outlined),
                          title: const Text('Chat with AI coach'),
                          subtitle: const Text(
                              'Plans, alternatives and advice · needs internet'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AIChatScreen()),
                          ),
                        ),
                      ],
                    ),
                    // Developer section (debug builds only)
                    if (kDebugMode)
                      SettingsGroup(
                        title: 'Developer',
                        children: [
                          ListTile(
                            key: const ValueKey('settings-developer'),
                            leading: const Icon(Icons.developer_mode),
                            title: const Text('Developer tools'),
                            subtitle: const Text(
                                'Performance, timer debugging, TTS tests'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DeveloperScreen()),
                            ),
                          ),
                        ],
                      ),
                    SettingsGroup(
                      title: 'About',
                      children: [_buildVersionTile()],
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = _userProfile;
    if (profile == null) {
      return SettingsCard(
        child: ListTile(
          key: const ValueKey('profile-set-up'),
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: const Icon(Icons.person_outline),
          ),
          title: const Text('Set up profile'),
          subtitle: const Text('Age and gender for heart-rate zones'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showProfileEditor,
        ),
      );
    }
    final name = profile.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
      child: Row(
        key: const ValueKey('profile-header'),
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(initial, style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimaryContainer)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: Gap.xs),
                Text(
                  'Age ${profile.age} · '
                  '${Gender.getDisplayName(profile.gender)} · '
                  'Max HR ${profile.maxHeartRate}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('profile-edit'),
            style: TextButton.styleFrom(
                minimumSize: const Size(kMinTouchTarget, kMinTouchTarget)),
            onPressed: _showProfileEditor,
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightUnitTile(BuildContext context, bool useMetricUnits) {
    final theme = Theme.of(context);
    return SwitchListTile(
      key: const ValueKey('weight-unit-switch'),
      secondary: const Icon(Icons.scale_outlined),
      title: const Text('Weight unit'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(useMetricUnits ? 'Kilograms (kg)' : 'Pounds (lb)'),
          Text(
            'Changes labels and steps only — weights you already logged '
            'keep their numbers.',
            key: const ValueKey('weight-unit-note'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      value: useMetricUnits,
      onChanged: (value) => _updatePreference(_useMetricUnitsKey, value),
    );
  }

  Widget _buildRestTimerTile(BuildContext context, int timerDuration) {
    return ListTile(
      key: const ValueKey('settings-rest-timer'),
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Rest timer'),
      subtitle: Text(
        restTimerSummary(smartRest: _smartRest, seconds: timerDuration),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => RestTimerSettingsSheet.show(
        context,
        smartRest: _smartRest,
        onSmartRestChanged: _setSmartRest,
      ),
    );
  }

  Widget _buildBarAndPlatesTile(BuildContext context, bool useMetricUnits) {
    final unit = useMetricUnits ? 'kg' : 'lb';
    final bar = _prefsService.getBarWeight(metric: useMetricUnits);
    final plates = _prefsService.getAvailablePlates(metric: useMetricUnits);
    final platesLabel = plates.isEmpty
        ? 'no plates'
        : plates.map(formatPlateWeight).join(', ');
    return ListTile(
      key: const ValueKey('settings-bar-plates'),
      leading: const Icon(Icons.fitness_center),
      title: const Text('Bar & plates'),
      subtitle: Text('Bar ${formatPlateWeight(bar)} $unit · Plates: $platesLabel',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (sheetContext) {
            final theme = Theme.of(sheetContext);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bar & plates', style: theme.textTheme.titleLarge),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Used by the plate calculator. Pairs of each plate are '
                    'assumed unlimited.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Gap.md),
                  BarAndPlatesEditor(metric: useMetricUnits),
                ],
              ),
            );
          },
        );
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildTimerSoundTile(bool playSoundOnTimerEnd) {
    return SwitchListTile(
      key: const ValueKey('timer-sound-switch'),
      secondary: const Icon(Icons.volume_up_outlined),
      title: const Text('Timer sound'),
      subtitle: const Text('Play a sound when the rest timer completes'),
      value: playSoundOnTimerEnd,
      onChanged: (value) => _updatePreference(_playSoundOnTimerEndKey, value),
    );
  }

  /// Explicitly choose light ([dark] = false) or dark mode, overriding the
  /// system setting.
  Future<void> _setDarkMode(bool dark, bool storedDarkMode) async {
    userThemeOverride.value = true;
    if (dark != storedDarkMode) {
      // AppBloc flips and persists the stored value.
      context.read<AppBloc>().add(const AppThemeToggled());
    } else {
      // The stored value already matches (the app was following the system
      // theme); just persist it so the choice sticks across restarts.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(darkModePreferenceKey, dark);
    }
  }

  Future<void> _followSystemTheme() async {
    userThemeOverride.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(darkModePreferenceKey);
  }

  Widget _buildThemeSetting(BuildContext context, bool storedDarkMode) {
    return ValueListenableBuilder<bool>(
      valueListenable: userThemeOverride,
      builder: (context, overridden, _) {
        final choice = !overridden
            ? _ThemeChoice.system
            : storedDarkMode
                ? _ThemeChoice.dark
                : _ThemeChoice.light;
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.brightness_6_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme', style: theme.textTheme.bodyLarge),
                        Text(
                          switch (choice) {
                            _ThemeChoice.system =>
                              "Following your device's light/dark setting",
                            _ThemeChoice.light => 'Always light',
                            _ThemeChoice.dark => 'Always dark',
                          },
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              SegmentedButton<_ThemeChoice>(
                key: const ValueKey('theme-segmented'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _ThemeChoice.system,
                    label: Text('System', key: ValueKey('use-device-theme')),
                  ),
                  ButtonSegment(
                    value: _ThemeChoice.light,
                    label: Text('Light', key: ValueKey('theme-light')),
                  ),
                  ButtonSegment(
                    value: _ThemeChoice.dark,
                    label: Text('Dark', key: ValueKey('theme-dark')),
                  ),
                ],
                selected: {choice},
                onSelectionChanged: (selection) {
                  switch (selection.first) {
                    case _ThemeChoice.system:
                      _followSystemTheme();
                    case _ThemeChoice.light:
                      _setDarkMode(false, storedDarkMode);
                    case _ThemeChoice.dark:
                      _setDarkMode(true, storedDarkMode);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeminiKeyTile() {
    final hasKey = (ApiKeyService().cachedKey ?? '').isNotEmpty;
    return ListTile(
      key: const ValueKey('settings-gemini-key'),
      leading: const Icon(Icons.key_outlined),
      title: const Text('Gemini API key'),
      subtitle: Text(hasKey ? 'Set' : 'Not set'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showGeminiKeyDialog,
    );
  }

  Widget _buildVersionTile() {
    return FutureBuilder<PackageInfo>(
      future: _versionFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListTile(
          key: const ValueKey('settings-version'),
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          subtitle: Text(info == null ? '—' : AppVersionText.format(info)),
        );
      },
    );
  }

  Future<void> _showGeminiKeyDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<_ApiKeyDialogResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gemini API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Paste your API key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your key is stored only on this device and is sent only to '
              'Google\'s Gemini API.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ApiKeyDialogResult.clear),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ApiKeyDialogResult.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final enteredKey = controller.text.trim();
    controller.dispose();
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (result == _ApiKeyDialogResult.clear) {
      await ApiKeyService().setGeminiKey(null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gemini API key removed from this device')),
      );
    } else {
      if (enteredKey.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Please paste an API key first')),
        );
        return;
      }
      await ApiKeyService().setGeminiKey(enteredKey);
      messenger.showSnackBar(
        const SnackBar(content: Text('Gemini API key saved on this device')),
      );
    }
    if (mounted) setState(() {});
  }
}


/// Dialog for editing user profile information
class _ProfileEditorDialog extends StatefulWidget {
  final UserProfile? currentProfile;
  final Function(UserProfile) onProfileSaved;

  const _ProfileEditorDialog({
    required this.currentProfile,
    required this.onProfileSaved,
  });

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _restingHRController = TextEditingController();

  String _selectedGender = Gender.male;
  String _selectedFitnessLevel = FitnessLevel.beginner;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentProfile != null) {
      _nameController.text = widget.currentProfile!.name;
      _ageController.text = widget.currentProfile!.age.toString();
      _selectedGender = widget.currentProfile!.gender;
      _selectedFitnessLevel = widget.currentProfile!.fitnessLevel;

      if (widget.currentProfile!.restingHeartRate != null) {
        _restingHRController.text =
            widget.currentProfile!.restingHeartRate!.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _restingHRController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.currentProfile == null ? 'Create Profile' : 'Edit Profile'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age *',
                    border: OutlineInputBorder(),
                    suffixText: 'years',
                    helperText: 'Used for safe heart rate calculations',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Age is required for safe heart rate calculations';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 13 || age > 120) {
                      return 'Age must be between 13 and 120';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender *',
                    border: OutlineInputBorder(),
                  ),
                  items: Gender.all.map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(Gender.getDisplayName(gender)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _restingHRController,
                  decoration: const InputDecoration(
                    labelText: 'Resting Heart Rate',
                    border: OutlineInputBorder(),
                    suffixText: 'BPM',
                    helperText: 'Optional - improves heart rate zone accuracy',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final hr = int.tryParse(value);
                      if (hr == null || hr < 40 || hr > 120) {
                        return 'Resting HR must be between 40-120 BPM';
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final profileService = UserProfileService();
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text);
      final restingHR = _restingHRController.text.trim().isNotEmpty
          ? int.tryParse(_restingHRController.text)
          : null;

      UserProfile? savedProfile;

      if (widget.currentProfile == null) {
        // Create new profile
        savedProfile = await profileService.createProfile(
          name: name,
          age: age,
          gender: _selectedGender,
          restingHeartRate: restingHR,
          fitnessLevel: _selectedFitnessLevel,
        );
      } else {
        // Update existing profile
        final updatedProfile = widget.currentProfile!.copyWith(
          name: name,
          age: age,
          gender: _selectedGender,
          restingHeartRate: restingHR,
          fitnessLevel: _selectedFitnessLevel,
        );

        final success = await profileService.updateProfile(updatedProfile);
        if (success) {
          savedProfile = updatedProfile;
        }
      }

      if (savedProfile != null) {
        widget.onProfileSaved(savedProfile);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully!')),
          );
        }
      } else {
        throw Exception('Failed to save profile');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
