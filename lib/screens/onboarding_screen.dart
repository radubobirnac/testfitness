import 'package:flutter/material.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/screens/main_screen.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/services/user_profile_service.dart';
import 'package:testfitness/utils/app_logger.dart';

/// What the app should do about first-run setup at launch.
enum OnboardingDecision {
  /// New user: show the setup screen.
  show,

  /// Existing user updating the app (has workouts): mark setup done, skip it.
  skipAndMarkDone,

  /// Setup already completed.
  skip,
}

/// Pure decision: show setup only to users who never completed it and have
/// no workouts yet.
OnboardingDecision decideOnboarding({
  required bool hasCompletedOnboarding,
  required int workoutCount,
}) {
  if (hasCompletedOnboarding) return OnboardingDecision.skip;
  if (workoutCount > 0) return OnboardingDecision.skipAndMarkDone;
  return OnboardingDecision.show;
}

/// Resolves [decideOnboarding] against storage and marks setup complete for
/// existing users. Any failure skips setup (never blocks start-up).
Future<bool> shouldShowOnboarding({
  required Future<int> Function() countWorkouts,
  UserProfileService? profileService,
}) async {
  final profile = profileService ?? UserProfileService();
  try {
    final done = await profile.hasCompletedOnboarding();
    if (done) return false;
    final decision = decideOnboarding(
      hasCompletedOnboarding: done,
      workoutCount: await countWorkouts(),
    );
    if (decision == OnboardingDecision.skipAndMarkDone) {
      await profile.markOnboardingCompleted();
    }
    return decision == OnboardingDecision.show;
  } catch (e) {
    AppLogger.warning('Onboarding check failed; skipping setup', e);
    return false;
  }
}

/// Short, skippable 3-step first-run setup: units, experience, first action.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished});

  /// Called after setup is marked complete. [startWorkout] is true when the
  /// user chose "Start your first workout". Defaults to replacing this screen
  /// with [MainScreen] (and opening an empty workout editor on top).
  final void Function(BuildContext context, bool startWorkout)? onFinished;

  /// Default exit: replace setup with [MainScreen], optionally opening an
  /// empty workout editor on top.
  static void defaultFinish(BuildContext context, bool startWorkout) {
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
    if (startWorkout) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const ExerciseDetailScreen()),
      );
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _stepCount = 3;

  final UserPreferencesService _prefs = UserPreferencesService();
  int _step = 0;
  bool? _useMetric;
  ExperienceLevel? _experience;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    await _prefs.initialize();
    if (!mounted) return;
    setState(() {
      _useMetric = _prefs.getUseMetricUnits();
      _experience = _prefs.getExperienceLevel();
    });
  }

  Future<void> _setUnits(bool metric) async {
    setState(() => _useMetric = metric);
    await _prefs.initialize();
    await _prefs.setUseMetricUnits(metric);
  }

  Future<void> _setExperience(ExperienceLevel level) async {
    setState(() => _experience = level);
    await _prefs.initialize();
    await _prefs.setExperienceLevel(level);
  }

  Future<void> _finish({required bool startWorkout}) async {
    if (_finishing) return;
    _finishing = true;
    await UserProfileService().markOnboardingCompleted();
    if (!mounted) return;
    final onFinished = widget.onFinished ?? OnboardingScreen.defaultFinish;
    onFinished(context, startWorkout);
  }

  void _next() {
    if (_step < _stepCount - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    _StepDots(current: _step, count: _stepCount),
                    const Spacer(),
                    TextButton(
                      key: const ValueKey('onboarding-skip'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 48),
                      ),
                      onPressed: () => _finish(startWorkout: false),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey('onboarding-step-$_step'),
                      child: switch (_step) {
                        0 => _buildUnitsStep(context),
                        1 => _buildExperienceStep(context),
                        _ => _buildStartStep(context),
                      },
                    ),
                  ),
                ),
              ),
              if (_step < _stepCount - 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52)),
                            onPressed: _back,
                            child: const Text('Back'),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('onboarding-next'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          onPressed: _next,
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
      );

  Widget _body(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );

  Widget _buildUnitsStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.fitness_center, size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        _title(context, 'Welcome to StrengthWave'),
        _body(context,
            'Log your lifts and the coach suggests what to lift next time. '
            'First, which units do you lift in?'),
        SegmentedButton<bool>(
          key: const ValueKey('onboarding-units'),
          style: SegmentedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          segments: const [
            ButtonSegment(value: true, label: Text('Kilograms (kg)')),
            ButtonSegment(value: false, label: Text('Pounds (lb)')),
          ],
          selected: {
            if (_useMetric != null) _useMetric!,
          },
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) _setUnits(selection.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'You can change this later in Profile.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildExperienceStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const options = [
      (ExperienceLevel.beginner, 'Beginner', 'New to lifting or under 6 months'),
      (
        ExperienceLevel.intermediate,
        'Intermediate',
        'Training consistently for 6 months to 2 years'
      ),
      (ExperienceLevel.advanced, 'Advanced', 'Several years of structured training'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(context, 'Your experience'),
        _body(context, 'This helps us tailor tips. It does not lock anything.'),
        for (final (level, label, description) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChoiceTile(
              key: ValueKey('onboarding-experience-${level.name}'),
              label: label,
              description: description,
              selected: _experience == level,
              onTap: () => _setExperience(level),
            ),
          ),
        if (_experience == ExperienceLevel.beginner)
          Card(
            key: const ValueKey('onboarding-beginner-tip'),
            color: scheme.secondaryContainer,
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: scheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: start each exercise with 2–3 lighter warm-up sets. '
                      'Effort (RPE) is how hard a set felt from 1 to 10 — aim '
                      'for about 7–8, leaving 2–3 reps in the tank.',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStartStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.play_circle_outline, size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        _title(context, "You're all set"),
        _body(context,
            'Start logging right away, or look around the app first.'),
        FilledButton.icon(
          key: const ValueKey('onboarding-start-workout'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => _finish(startWorkout: true),
          icon: const Icon(Icons.add),
          label: const Text('Start your first workout'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('onboarding-explore'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => _finish(startWorkout: false),
          child: const Text('Explore first'),
        ),
        const SizedBox(height: 12),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _back,
          child: const Text('Back'),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step ${current + 1} of $count',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              width: i == current ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: selected
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: selected
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
