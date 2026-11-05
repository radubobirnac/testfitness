import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:testfitness/models/weight_test.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart'
    show DecimalWeightInputFormatter;
import 'package:testfitness/services/ai_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/offline_indicator.dart';

/// Screen for executing weight tests with real-time guidance
class WeightTestExecutionScreen extends StatefulWidget {
  final String exerciseName;
  final int targetReps;
  final WeightTestType testType;

  const WeightTestExecutionScreen({
    super.key,
    required this.exerciseName,
    required this.targetReps,
    required this.testType,
  });

  @override
  State<WeightTestExecutionScreen> createState() =>
      _WeightTestExecutionScreenState();
}

class _WeightTestExecutionScreenState extends State<WeightTestExecutionScreen> {
  final AIService _aiService = AIService();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  // Test state
  final List<WeightTestSet> _completedSets = [];
  int _currentSetNumber = 1;
  double _currentWeight = 0;
  int _currentReps = 0;
  int _currentRpe = 5;
  bool _formBreakdown = false;
  String _aiCoaching = '';

  // Progressive loading algorithm
  double _startingWeight = 0;
  double _weightIncrement = 0;

  /// The user's preferred weight unit, lower-cased for inline text
  /// ("kg" / "lbs").
  String get _unit =>
      UserPreferencesService().getWeightUnitLabel().toLowerCase();

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  void _initializeTest() {
    // Calculate starting weight based on exercise type
    _startingWeight = _getStartingWeight(widget.exerciseName);
    _weightIncrement = _getWeightIncrement(widget.exerciseName);
    _currentWeight = _startingWeight;

    _weightController.text = _currentWeight.toString();
    _repsController.text = widget.targetReps.toString();

    _generateInitialCoaching();
  }

  double _getStartingWeight(String exerciseName) {
    // Conservative starting weights for safety - simplified for beginners
    final Map<String, double> startingWeights = {
      'Bench Press': 45.0, // Empty barbell
      'Squat': 45.0, // Empty barbell
      'Deadlift': 65.0, // Slightly heavier start
      'Overhead Press': 25.0, // Lighter for shoulder safety
      'Barbell Row': 45.0, // Empty barbell
      'Bicep Curls': 15.0, // Light dumbbells
    };

    return startingWeights[exerciseName] ?? 20.0;
  }

  double _getWeightIncrement(String exerciseName) {
    // Appropriate increments for different exercises - simplified for beginners
    final Map<String, double> increments = {
      'Bench Press': 10.0, // Standard barbell increment
      'Squat': 15.0, // Larger increment for legs
      'Deadlift': 20.0, // Largest increment for strongest lift
      'Overhead Press': 5.0, // Smaller increment for shoulders
      'Barbell Row': 10.0, // Standard increment
      'Bicep Curls': 5.0, // Small increment for isolation
    };

    return increments[exerciseName] ?? 5.0;
  }

  void _generateInitialCoaching() async {
    try {
      final coaching = await _aiService.answerFitnessQuestion(
        'Provide encouraging coaching for starting a ${widget.exerciseName} weight test. '
        'The user is starting with $_currentWeight$_unit for ${widget.targetReps} reps. '
        'Give safety tips and form reminders. Keep it brief and motivational.',
      );

      setState(() {
        _aiCoaching = coaching;
      });
    } catch (e) {
      setState(() {
        _aiCoaching = 'Welcome to your ${widget.exerciseName} weight test! '
            'Start with $_currentWeight$_unit and focus on perfect form. '
            'We\'ll gradually increase the weight to find your optimal working weight.';
      });
    }
  }

  void _completeSet() async {
    if (_currentReps == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter the number of reps completed')),
      );
      return;
    }

    // Create the completed set
    final set = WeightTestSet(
      setNumber: _currentSetNumber,
      weight: _currentWeight,
      reps: _currentReps,
      rpe: _currentRpe,
      formBreakdown: _formBreakdown,
    );

    setState(() {
      _completedSets.add(set);
    });

    HapticFeedback.lightImpact();
    AppLogger.info(
        'Completed set $_currentSetNumber: $_currentWeight$_unit x $_currentReps reps (RPE: $_currentRpe)');

    // Check if test should continue
    if (_shouldContinueTest(set)) {
      _prepareNextSet();
    } else {
      _completeTest();
    }
  }

  bool _shouldContinueTest(WeightTestSet lastSet) {
    // Stop if form broke down
    if (lastSet.formBreakdown) return false;

    // Stop if RPE is too high (9-10)
    if (lastSet.rpe != null && lastSet.rpe! >= 9) return false;

    // Stop if couldn't complete target reps
    if (lastSet.reps < widget.targetReps) return false;

    // Stop if we've done too many sets (safety limit)
    if (_completedSets.length >= 8) return false;

    return true;
  }

  void _prepareNextSet() async {
    setState(() {
      _currentSetNumber++;
      _currentWeight += _weightIncrement;
      _currentReps = 0;
      _currentRpe = 5;
      _formBreakdown = false;
    });

    _weightController.text = _currentWeight.toString();
    _repsController.text = widget.targetReps.toString();

    // Generate AI coaching for next set
    try {
      final coaching = await _aiService.answerFitnessQuestion(
        'Provide coaching for set $_currentSetNumber of a ${widget.exerciseName} weight test. '
        'Previous set: ${_completedSets.last.weight}$_unit x ${_completedSets.last.reps} reps (RPE: ${_completedSets.last.rpe}). '
        'Next weight: $_currentWeight$_unit. Give encouragement and form tips. Keep it brief.',
      );

      setState(() {
        _aiCoaching = coaching;
      });
    } catch (e) {
      setState(() {
        _aiCoaching =
            'Great job! Now try $_currentWeight$_unit for ${widget.targetReps} reps. '
            'Focus on maintaining perfect form as the weight increases.';
      });
    }
  }

  void _completeTest() {
    // Navigate to results screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WeightTestResultsScreen(
          exerciseName: widget.exerciseName,
          targetReps: widget.targetReps,
          testType: widget.testType,
          completedSets: _completedSets,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OfflineIndicator(
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.exerciseName} Test'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 24),
              _buildAICoaching(),
              const SizedBox(height: 24),
              _buildCurrentSetInput(),
              const SizedBox(height: 24),
              _buildCompletedSets(),
              const SizedBox(height: 24),
              _buildActionButtons(),
              const SizedBox(height: 24), // Extra padding at bottom
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.primary,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Set $_currentSetNumber',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.exerciseName} • Target: ${widget.targetReps} reps',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _completedSets.length / 6, // Assume max 6 sets
                // Drawn on a primary-coloured card, so use onPrimary for the
                // bar (a primary bar would be invisible).
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAICoaching() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Coach',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _aiCoaching,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSetInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Set',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Weight and Reps Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [DecimalWeightInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Weight ($_unit)',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _currentWeight = double.tryParse(value) ?? 0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Reps Completed',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _currentReps = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // RPE Slider
            Text('Rate of Perceived Exertion (RPE): $_currentRpe'),
            Slider(
              value: _currentRpe.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_currentRpe',
              onChanged: (value) {
                setState(() {
                  _currentRpe = value.round();
                });
              },
            ),

            const SizedBox(height: 8),

            // Form Breakdown Checkbox
            CheckboxListTile(
              title: const Text('Form broke down during this set'),
              value: _formBreakdown,
              onChanged: (value) {
                setState(() {
                  _formBreakdown = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSets() {
    if (_completedSets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completed Sets',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...(_completedSets.map((set) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${set.setNumber}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('${set.weight}$_unit × ${set.reps} reps'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              _getRpeColor(set.rpe ?? 5).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'RPE ${set.rpe ?? 5}',
                          style: TextStyle(
                            color: _getRpeColor(set.rpe ?? 5),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (set.formBreakdown) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _completeSet,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Complete Set $_currentSetNumber',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _completeTest,
            child: const Text('Finish Test Early'),
          ),
        ),
      ],
    );
  }

  Color _getRpeColor(int rpe) {
    if (rpe <= 3) return Colors.green;
    if (rpe <= 6) return Colors.blue;
    if (rpe <= 8) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }
}

/// Placeholder for weight test results screen
class WeightTestResultsScreen extends StatelessWidget {
  final String exerciseName;
  final int targetReps;
  final WeightTestType testType;
  final List<WeightTestSet> completedSets;

  const WeightTestResultsScreen({
    super.key,
    required this.exerciseName,
    required this.targetReps,
    required this.testType,
    required this.completedSets,
  });

  String get _unit =>
      UserPreferencesService().getWeightUnitLabel().toLowerCase();

  @override
  Widget build(BuildContext context) {
    // Calculate 1RM and working weight
    final weightTest = WeightTest(
      userId: 'user1',
      exerciseId: 'exercise1',
      exerciseName: exerciseName,
      testDate: DateTime.now(),
      testType: testType,
      targetReps: targetReps,
      testSets: completedSets,
      isCompleted: true,
    );

    final oneRepMax = weightTest.calculateOneRepMax();
    final workingWeight = weightTest.getWorkingWeight();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Results'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Weight Test Complete!',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 16),
                    if (oneRepMax != null) ...[
                      Text(
                          'Estimated 1RM: ${oneRepMax.toStringAsFixed(1)} $_unit'),
                      const SizedBox(height: 8),
                    ],
                    if (workingWeight != null) ...[
                      Text(
                          'Recommended Working Weight: ${workingWeight.toStringAsFixed(1)} $_unit'),
                      const SizedBox(height: 8),
                    ],
                    Text('Sets Completed: ${completedSets.length}'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Return to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
