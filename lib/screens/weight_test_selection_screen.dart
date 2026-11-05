import 'package:flutter/material.dart';
import 'package:testfitness/models/weight_test.dart';
import 'package:testfitness/screens/weight_test_execution_screen.dart';

class WeightTestSelectionScreen extends StatefulWidget {
  const WeightTestSelectionScreen({super.key});

  @override
  State<WeightTestSelectionScreen> createState() =>
      _WeightTestSelectionScreenState();
}

class _WeightTestSelectionScreenState extends State<WeightTestSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedExercise = '';
  int _targetReps = 12; // Changed to 12 for safety
  final String _testType = 'Progressive Loading';

  // Essential exercises - one per major muscle group for beginners
  final List<String> _exercises = [
    'Bench Press', // Chest
    'Squat', // Legs (Quads/Glutes)
    'Deadlift', // Back/Hamstrings
    'Overhead Press', // Shoulders
    'Barbell Row', // Back (Lats)
    'Bicep Curls', // Arms (Biceps)
  ];

  List<String> get _filteredExercises {
    if (_searchController.text.isEmpty) {
      return _exercises;
    }
    return _exercises
        .where((exercise) => exercise
            .toLowerCase()
            .contains(_searchController.text.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Weight'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Find Your Working Weight',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Systematically determine your optimal weight for each exercise',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Exercise Selection
            const Text(
              'Select Exercise',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Exercise List
            Expanded(
              child: Card(
                child: RadioGroup<String>(
                  groupValue: _selectedExercise,
                  onChanged: (value) {
                    setState(() {
                      _selectedExercise = value ?? '';
                    });
                  },
                  child: ListView.builder(
                    itemCount: _filteredExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _filteredExercises[index];
                      final isSelected = _selectedExercise == exercise;

                      return ListTile(
                        title: Text(exercise),
                        leading: Radio<String>(
                          value: exercise,
                        ),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedExercise = exercise;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Configuration
            if (_selectedExercise.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Configuration',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Target Reps
                      Row(
                        children: [
                          const Text('Target Reps: '),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _targetReps,
                            items: List.generate(
                                    6,
                                    (index) =>
                                        index + 10) // 10-15 reps for safety
                                .map((reps) => DropdownMenuItem(
                                      value: reps,
                                      child: Text('$reps reps'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _targetReps = value ?? 12;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Test Type
                      const Text('Test Type: '),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progressive Loading Test',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Start light and gradually increase weight until you reach your target difficulty (RPE 7-8)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Start Test Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _startWeightTest();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Start Weight Test for $_selectedExercise',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startWeightTest() {
    // Convert test type string to enum
    WeightTestType testType;
    switch (_testType) {
      case 'Progressive Loading':
        testType = WeightTestType.progressiveLoading;
        break;
      case 'Reverse Pyramid':
        testType = WeightTestType.reversePyramid;
        break;
      case 'RPE Assessment':
        testType = WeightTestType.rpeAssessment;
        break;
      case 'One Rep Max':
        testType = WeightTestType.oneRepMax;
        break;
      default:
        testType = WeightTestType.progressiveLoading;
    }

    // Navigate to weight test execution screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightTestExecutionScreen(
          exerciseName: _selectedExercise,
          targetReps: _targetReps,
          testType: testType,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
