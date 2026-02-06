import 'package:flutter/material.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/utils/exercise_metadata.dart';

/// Bottom sheet widget for selecting an exercise
/// Returns the selected Exercise when popped
class ExerciseSelectionSheet extends StatefulWidget {
  const ExerciseSelectionSheet({super.key});

  @override
  State<ExerciseSelectionSheet> createState() => _ExerciseSelectionSheetState();
}

class _ExerciseSelectionSheetState extends State<ExerciseSelectionSheet> {
  final ExerciseRepository _exerciseRepository = ExerciseRepository();
  List<Exercise> _exercises = [];
  List<Exercise> _filteredExercises = [];
  List<String> _categories = ['Any Category'];
  List<String> _bodyParts = ['Any Body Part'];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'Any Category';
  String _selectedBodyPart = 'Any Body Part';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load exercises, categories, and body parts
      final exercises = await _exerciseRepository.getExercises();
      final categories = await _exerciseRepository.getCategories();
      final bodyParts = await _exerciseRepository.getBodyParts();

      // Log what we're getting from the repository for debugging
      AppLogger.debug('Categories from repo: $categories');
      AppLogger.debug('Body parts from repo: $bodyParts');

      setState(() {
        _exercises = exercises;
        _filteredExercises = exercises;

        // Repository already includes "Any Category"/"Any Body Part"
        // so we don't need to add them again
        _categories = categories;
        _bodyParts = bodyParts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading exercises: $e')));
      }
    }
  }

  void _applyFilters() {
    if (_exercises.isEmpty) return;

    setState(() {
      _filteredExercises = _exercises.where((exercise) {
        // Apply search filter
        final nameMatches = _searchQuery.isEmpty ||
            exercise.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

        // Apply category filter
        final categoryMatches = _selectedCategory == 'Any Category' ||
            ExerciseMetadata.matchesCategory(exercise, _selectedCategory);

        // Apply body part filter
        final bodyPartMatches = _selectedBodyPart == 'Any Body Part' ||
            ExerciseMetadata.matchesBodyPart(exercise, _selectedBodyPart);

        return nameMatches && categoryMatches && bodyPartMatches;
      }).toList();
    });
  }

  String _exerciseSubtitle(Exercise exercise) {
    final category = ExerciseMetadata.resolveCategory(exercise);
    final bodyParts = ExerciseMetadata.resolveBodyParts(exercise);
    final bodyPartLabel =
        bodyParts.isEmpty ? '' : bodyParts.join(', ');
    if (category.isEmpty) return bodyPartLabel;
    if (bodyPartLabel.isEmpty) return category;
    return '$category · $bodyPartLabel';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          MediaQuery.of(context).size.height * 0.8, // Takes up 4/5 of screen
      padding: const EdgeInsets.only(top: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _exercises.isEmpty
                      ? 'Select Exercise'
                      : 'Select Exercise (${_exercises.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(25.0)),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _applyFilters();
                            });
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Showing ${_filteredExercises.length} of ${_exercises.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Filters
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Show a dialog with all categories
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Select Category'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        height:
                                            300, // Fixed height to show more items
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _categories.length,
                                          itemBuilder: (context, index) {
                                            final category = _categories[index];
                                            return ListTile(
                                              title: Text(category),
                                              selected:
                                                  category == _selectedCategory,
                                              onTap: () {
                                                setState(() {
                                                  _selectedCategory = category;
                                                  _applyFilters();
                                                });
                                                Navigator.pop(context);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Theme.of(context).dividerColor),
                                    borderRadius: BorderRadius.circular(25.0),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedCategory,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Show a dialog with all body parts
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Select Body Part'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        height:
                                            300, // Fixed height to show more items
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _bodyParts.length,
                                          itemBuilder: (context, index) {
                                            final bodyPart = _bodyParts[index];
                                            return ListTile(
                                              title: Text(bodyPart),
                                              selected:
                                                  bodyPart == _selectedBodyPart,
                                              onTap: () {
                                                setState(() {
                                                  _selectedBodyPart = bodyPart;
                                                  _applyFilters();
                                                });
                                                Navigator.pop(context);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Theme.of(context).dividerColor),
                                    borderRadius: BorderRadius.circular(25.0),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedBodyPart,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Exercise list
                      Expanded(
                        child: _filteredExercises.isEmpty
                            ? const Center(child: Text('No exercises found'))
                            : ListView.builder(
                                itemCount: _filteredExercises.length,
                                itemBuilder: (context, index) {
                                  final exercise = _filteredExercises[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 4.0,
                                    ),
                                    child: ListTile(
                                      title: Text(exercise.name),
                                      subtitle: Text(
                                        _exerciseSubtitle(exercise),
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () {
                                        // Return the exercise when selected
                                        Navigator.pop(context, exercise);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
