import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/app/app_state.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/services/user_profile_service.dart';
import 'package:testfitness/services/enhanced_tts_service.dart';
import 'package:testfitness/services/timer_debug_reporter.dart';
import 'package:testfitness/services/timer_debug_log_service.dart';
import 'package:testfitness/models/user_profile.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/screens/performance_screen.dart';
import 'package:testfitness/screens/ai_chat_screen.dart';
import 'package:testfitness/screens/app_loader.dart';
import 'package:testfitness/screens/gemini_tts_test_screen.dart';
import 'package:testfitness/screens/tts_analytics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Preference keys for AppBloc integration
  static const String _timerDurationKey = 'rest_timer_duration';
  static const String _useMetricUnitsKey = 'use_metric_units';
  static const String _playSoundOnTimerEndKey = 'play_sound_on_timer_end';

  final UserProfileService _profileService = UserProfileService();
  final EnhancedTTSService _ttsService = EnhancedTTSService();
  final TimerDebugReporter _timerDebugReporter = TimerDebugReporter();
  final TimerDebugLogService _timerDebugLogService = TimerDebugLogService();
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
    _loadUserProfile();
    _initializeTTS();
  }

  void _initializeTTS() async {
    await _ttsService.initialize();
  }

  void _loadUserProfile() async {
    final profile = await _profileService.loadProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }
  }

  void _initializePreferences() {
    AppLogger.info('ProfileScreen: Initializing preferences');

    // Load preferences into AppBloc if not already loaded
    final appState = context.read<AppBloc>().state;
    if (!appState.preferences.containsKey(_timerDurationKey)) {
      _loadDefaultPreferences();
    }
  }

  void _loadDefaultPreferences() {
    AppLogger.info('ProfileScreen: Loading default preferences');

    final defaultPreferences = {
      _timerDurationKey: UserPreferencesService.defaultRestTimerDuration,
      _useMetricUnitsKey: UserPreferencesService.defaultUseMetricUnits,
      _playSoundOnTimerEndKey:
          UserPreferencesService.defaultPlaySoundOnTimerEnd,
    };

    context.read<AppBloc>().add(AppPreferencesUpdated(defaultPreferences));
  }

  void _updatePreference(String key, dynamic value) {
    AppLogger.debug('ProfileScreen: Updating preference $key = $value');
    context.read<AppBloc>().add(AppPreferencesUpdated({key: value}));
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

  Future<void> _copyTimerDebugReport() async {
    try {
      final report = await _timerDebugReporter.buildReport();
      await Clipboard.setData(ClipboardData(text: report));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timer debug report copied to clipboard.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to build debug report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showTimerDebugReport() async {
    try {
      final report = await _timerDebugReporter.buildReport();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Timer Debug Report'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(report),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Timer debug report copied.'),
                    ),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to build debug report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestIgnoreBatteryOptimizations() async {
    try {
      final status =
          await Permission.ignoreBatteryOptimizations.request();
      if (!mounted) return;
      final message = status.isGranted
          ? 'Battery optimizations ignored for StrengthWave.'
          : 'Battery optimization permission not granted.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request battery optimization: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _showTimerDebugLog() async {
    try {
      final entries = await _timerDebugLogService.getEntries();
      final logText = entries.isEmpty
          ? 'No timer events recorded yet.'
          : entries.join('\n');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Timer Debug Log'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(logText),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: logText));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Timer debug log copied.'),
                    ),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load debug log: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearTimerDebugLog() async {
    try {
      await _timerDebugLogService.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timer debug log cleared.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear debug log: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testHeadsUpNotification() async {
    try {
      await _timerDebugReporter.scheduleHeadsUpTest();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Heads-up test scheduled in 10s. Switch apps/lock screen now.'),
        ),
      );
    } catch (e) {
      AppLogger.error('Heads-up test scheduling failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to schedule heads-up test: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppBloc, AppState>(
      listener: (context, state) {
        // Handle side effects
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        // Get preferences from AppBloc state
        final timerDuration = state.preferences[_timerDurationKey] as int? ??
            UserPreferencesService.defaultRestTimerDuration;
        final useMetricUnits = state.preferences[_useMetricUnitsKey] as bool? ??
            UserPreferencesService.defaultUseMetricUnits;
        final playSoundOnTimerEnd =
            state.preferences[_playSoundOnTimerEndKey] as bool? ??
                UserPreferencesService.defaultPlaySoundOnTimerEnd;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile & Settings')),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    // User info card
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.account_circle, size: 80),
                            const SizedBox(height: 8),
                            Text(
                              _userProfile?.name ?? 'Fitness User',
                              style: const TextStyle(fontSize: 24),
                            ),
                            if (_userProfile != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Age: ${_userProfile!.age} • ${Gender.getDisplayName(_userProfile!.gender)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Max HR: ${_userProfile!.maxHeartRate} BPM • VO2 Target: ${_userProfile!.vo2MaxTargetHeartRate} BPM',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _showProfileEditor,
                              icon: Icon(_userProfile == null
                                  ? Icons.add
                                  : Icons.edit),
                              label: Text(_userProfile == null
                                  ? 'Create Profile'
                                  : 'Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Settings section
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Workout Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Rest Timer Setting
                    _buildTimerSettingCard(context, timerDuration),

                    // Weight Unit Setting
                    _buildWeightUnitCard(context, useMetricUnits),

                    // Sound Setting
                    _buildSoundSettingCard(context, playSoundOnTimerEnd),

                    // AI Workout Preferences section
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'AI Workout Preferences',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    _buildAIWorkoutPreferencesCard(context),

                    // App Settings section
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'App Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Theme Setting
                    _buildThemeSettingCard(context, state.isDarkMode),

                    // Developer section
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Developer Tools',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    _buildDeveloperToolsCard(context),

                    // Voice & Speech section
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Voice & Speech',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    _buildTTSSettingsCard(context),

                    // AI Assistant section
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'AI Assistant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    _buildAIAssistantCard(context),

                    const SizedBox(height: 32),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTimerSettingCard(BuildContext context, int timerDuration) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Rest Timer Duration'),
                Text(
                  _formatTime(timerDuration),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              min: 15,
              max: 300,
              divisions: 57,
              value: timerDuration.toDouble(),
              onChanged: (value) {
                _updatePreference(_timerDurationKey, value.round());
              },
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade800, width: 2.0),
                ),
                child: Text(
                  _formatTime(timerDuration),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ),
            Text(
              'Adjust how long to rest between sets.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _updatePreference(_timerDurationKey,
                      UserPreferencesService.defaultRestTimerDuration);
                },
                child: const Text('Reset to Default (1:30)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightUnitCard(BuildContext context, bool useMetricUnits) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weight Unit'),
                Switch(
                  value: useMetricUnits,
                  onChanged: (value) {
                    _updatePreference(_useMetricUnitsKey, value);
                  },
                ),
              ],
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade800, width: 2.0),
                ),
                child: Text(
                  useMetricUnits ? 'Kilograms (Kg)' : 'Pounds (Lbs)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ),
            Text(
              'Toggle between imperial (Lbs) and metric (Kg) weight units.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _updatePreference(_useMetricUnitsKey,
                      UserPreferencesService.defaultUseMetricUnits);
                },
                child: const Text('Reset to Default (Lbs)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundSettingCard(
      BuildContext context, bool playSoundOnTimerEnd) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Timer Sound'),
                Switch(
                  value: playSoundOnTimerEnd,
                  onChanged: (value) {
                    _updatePreference(_playSoundOnTimerEndKey, value);
                  },
                ),
              ],
            ),
            Text(
              'Play a sound when the rest timer completes.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _updatePreference(_playSoundOnTimerEndKey,
                      UserPreferencesService.defaultPlaySoundOnTimerEnd);
                },
                child: const Text('Reset to Default (Enabled)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSettingCard(BuildContext context, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: isDarkMode ? Colors.amber : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    const Text('Dark Mode'),
                  ],
                ),
                Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    context.read<AppBloc>().add(const AppThemeToggled());
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isDarkMode
                  ? 'Using dark theme for better viewing in low light.'
                  : 'Using light theme for bright environments.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperToolsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Monitor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor app performance and database operations.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PerformanceScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.speed),
                label: const Text('Open Performance Monitor'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Timer Debug Report',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Collect notification settings, permissions, and timer state for troubleshooting.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyTimerDebugReport,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Debug Report'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showTimerDebugReport,
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Report'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testHeadsUpNotification,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Heads-Up Notification'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _requestIgnoreBatteryOptimizations,
                icon: const Icon(Icons.battery_alert_outlined),
                label: const Text('Disable Battery Optimizations'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Timer Debug Log',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Persistent background log of timer events and scheduling.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showTimerDebugLog,
                    icon: const Icon(Icons.list),
                    label: const Text('View Log'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _clearTimerDebugLog,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Log'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTTSSettingsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.purple.withValues(alpha: 0.1),
              Colors.blue.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.record_voice_over,
                    size: 32,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enhanced Text-to-Speech',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Customize voice coaching for workouts',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Enthusiasm Level Slider
              Text(
                'Enthusiasm Level: ${_ttsService.enthusiasmLevel}/5',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Slider(
                min: 1,
                max: 5,
                divisions: 4,
                value: _ttsService.enthusiasmLevel.toDouble(),
                onChanged: (value) async {
                  await _ttsService.setEnthusiasmLevel(value.round());
                  setState(() {});
                },
              ),
              Text(
                _getEnthusiasmDescription(_ttsService.enthusiasmLevel),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),

              // Voice Speed Slider
              Text(
                'Speech Rate: ${(_ttsService.speechRate * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Slider(
                min: 0.3,
                max: 1.5,
                value: _ttsService.speechRate,
                onChanged: (value) async {
                  await _ttsService.setSpeechRate(value);
                  setState(() {});
                },
              ),

              const SizedBox(height: 16),

              // Voice Pitch Slider
              Text(
                'Voice Pitch: ${(_ttsService.pitch * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Slider(
                min: 0.5,
                max: 2.0,
                value: _ttsService.pitch,
                onChanged: (value) async {
                  await _ttsService.setPitch(value);
                  setState(() {});
                },
              ),

              const SizedBox(height: 16),

              // Motivational Phrases Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Motivational Phrases'),
                  Switch(
                    value: _ttsService.useMotivationalPhrases,
                    onChanged: (value) async {
                      await _ttsService.setUseMotivationalPhrases(value);
                      setState(() {});
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Emphasis Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Voice Emphasis'),
                  Switch(
                    value: _ttsService.useEmphasis,
                    onChanged: (value) async {
                      await _ttsService.setUseEmphasis(value);
                      setState(() {});
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Test Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _ttsService.testVoice(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Test Voice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _ttsService.testBoxingVoice(),
                      icon: const Icon(Icons.sports_martial_arts),
                      label: const Text('Boxing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _ttsService.testWorkoutVoice(),
                      icon: const Icon(Icons.fitness_center),
                      label: const Text('Workout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Test timer completion message with current TTS speed
                        await _ttsService.speak(
                          'Timer complete! Time for your next set!',
                          context: 'timer_completion',
                        );
                      },
                      icon: const Icon(Icons.timer),
                      label: const Text('Timer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _ttsService.stop(),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Voice Selection Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showVoiceSelectionDialog(),
                  icon: const Icon(Icons.voice_over_off),
                  label: Text(_ttsService.selectedVoice.isEmpty
                      ? 'Select Voice'
                      : 'Voice: ${_ttsService.selectedVoice}'),
                ),
              ),

              const SizedBox(height: 8),

              // Gemini TTS Test Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GeminiTTSTestScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.science),
                  label: const Text('Test Gemini TTS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // TTS Analytics Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TTSAnalyticsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('TTS Analytics & Cost Optimization'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEnthusiasmDescription(int level) {
    switch (level) {
      case 1:
        return 'Calm and minimal - for quiet environments';
      case 2:
        return 'Low energy - gentle encouragement';
      case 3:
        return 'Moderate - balanced motivation';
      case 4:
        return 'High energy - strong encouragement';
      case 5:
        return 'Maximum - intense motivation for heavy workouts';
      default:
        return '';
    }
  }

  void _showVoiceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Voice'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _ttsService.availableVoices.length,
            itemBuilder: (context, index) {
              final voice = _ttsService.availableVoices[index];
              final voiceName = voice['name'] ?? 'Unknown';
              final locale = voice['locale'] ?? '';
              final isSelected = voiceName == _ttsService.selectedVoice;

              return ListTile(
                title: Text(voiceName),
                subtitle: Text(locale),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await _ttsService.setVoice(voiceName);
                  if (mounted) {
                    setState(() {});
                    navigator.pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Fitness Coach',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Powered by Gemini 2.5 Flash Lite',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Get personalized workout plans, exercise alternatives, and fitness advice from your AI coach.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.wifi, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text(
                    'Requires internet connection',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AIChatScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat with AI Coach'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildAIWorkoutPreferencesCard(BuildContext context) {
    final preferences = _userProfile?.preferences ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.teal.withValues(alpha: 0.1),
              Colors.green.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: 32,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Workout Guidance',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Configure how AI suggests workouts for you',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Default Body Parts
              Text(
                'Default Body Parts: ${preferences['defaultBodyParts'] ?? 2}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Slider(
                min: 1,
                max: 4,
                divisions: 3,
                value: (preferences['defaultBodyParts'] ?? 2).toDouble(),
                onChanged: (value) =>
                    _updateAIPreference('defaultBodyParts', value.round()),
              ),
              Text(
                _getBodyPartsDescription(
                    (preferences['defaultBodyParts'] ?? 2)),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),

              const SizedBox(height: 16),

              // Default Workout Duration
              Text(
                'Default Duration: ${preferences['defaultDurationMinutes'] ?? 45} minutes',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Slider(
                min: 15,
                max: 90,
                divisions: 15,
                value: (preferences['defaultDurationMinutes'] ?? 45).toDouble(),
                onChanged: (value) => _updateAIPreference(
                    'defaultDurationMinutes', value.round()),
              ),

              const SizedBox(height: 16),

              // Excluded Body Parts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Exclude Core Exercises'),
                  Switch(
                    value: preferences['excludeCore'] ?? false,
                    onChanged: (value) =>
                        _updateAIPreference('excludeCore', value),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Workout Focus
              Text(
                'Workout Focus',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: preferences['workoutFocus'] ?? 'balanced',
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'strength', child: Text('Strength Focus')),
                  DropdownMenuItem(
                      value: 'endurance', child: Text('Endurance Focus')),
                  DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
                  DropdownMenuItem(
                      value: 'upper', child: Text('Upper Body Priority')),
                  DropdownMenuItem(
                      value: 'lower', child: Text('Lower Body Priority')),
                ],
                onChanged: (value) =>
                    _updateAIPreference('workoutFocus', value),
              ),

              const SizedBox(height: 16),

              // Preferred Body Parts
              Text(
                'Preferred Body Parts',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Select body parts you want to prioritize in AI workouts',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              _buildBodyPartSelection(preferences),
            ],
          ),
        ),
      ),
    );
  }

  String _getBodyPartsDescription(int count) {
    switch (count) {
      case 1:
        return 'Single body part workouts (focused)';
      case 2:
        return 'Two body parts (balanced)';
      case 3:
        return 'Three body parts (comprehensive)';
      case 4:
        return 'Full body workouts (complete)';
      default:
        return 'Two body parts (balanced)';
    }
  }

  Widget _buildBodyPartSelection(Map<String, dynamic> preferences) {
    final availableBodyParts = [
      'Chest',
      'Back',
      'Shoulders',
      'Arms',
      'Legs',
      'Core',
      'Cardio'
    ];

    final preferredBodyParts =
        List<String>.from(preferences['preferredBodyParts'] ?? []);

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: availableBodyParts.map((bodyPart) {
        final isSelected = preferredBodyParts.contains(bodyPart);
        return FilterChip(
          label: Text(bodyPart),
          selected: isSelected,
          onSelected: (selected) {
            final updatedList = List<String>.from(preferredBodyParts);
            if (selected) {
              updatedList.add(bodyPart);
            } else {
              updatedList.remove(bodyPart);
            }
            _updateAIPreference('preferredBodyParts', updatedList);
          },
          selectedColor: Colors.teal.withValues(alpha: 0.3),
          checkmarkColor: Colors.teal,
        );
      }).toList(),
    );
  }

  void _updateAIPreference(String key, dynamic value) async {
    if (_userProfile == null) return;

    // Update state immediately for responsive UI
    final updatedPreferences =
        Map<String, dynamic>.from(_userProfile!.preferences);
    updatedPreferences[key] = value;

    final updatedProfile = _userProfile!.copyWith(
      preferences: updatedPreferences,
      lastUpdated: DateTime.now(),
    );

    setState(() {
      _userProfile = updatedProfile;
    });

    // Save to database asynchronously
    try {
      final success = await UserProfileService().saveProfile(updatedProfile);
      if (success) {
        AppLogger.info('AI preference updated: $key = $value');
      } else {
        AppLogger.error('Failed to save AI preference: $key = $value');
        // Could revert state here if needed
      }
    } catch (error) {
      AppLogger.error('Error saving AI preference: $key = $value', error);
      // Could revert state here if needed
    }
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
                  value: _selectedGender,
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
            backgroundColor: const Color(0xFF26A69A),
            foregroundColor: Colors.white,
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
            const SnackBar(
              content: Text('Profile saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to save profile');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $error'),
            backgroundColor: Colors.red,
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
