import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/exercise/exercise_bloc.dart';
import 'package:testfitness/blocs/exercise/exercise_event.dart';
import 'package:testfitness/blocs/exercise/exercise_state.dart';
import 'package:testfitness/models/exercise.dart';
import 'package:testfitness/screens/exercise_detail_screen.dart';
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/widgets/animated_feedback.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
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

  void _loadExercises() {
    AppLogger.info('ExercisesScreen: Loading exercises');
    context.read<ExerciseBloc>().add(const ExerciseLoadRequested());
    context.read<ExerciseBloc>().add(const ExerciseCategoriesLoadRequested());
    context.read<ExerciseBloc>().add(const ExerciseBodyPartsLoadRequested());
  }

  void _refreshExercises() {
    AppLogger.info('ExercisesScreen: Refreshing exercises');
    _loadExercises();
  }

  void _onSearchChanged(String query) {
    AppLogger.debug('ExercisesScreen: Search query changed to: $query');
    context.read<ExerciseBloc>().add(ExerciseSearchRequested(query));
  }

  void _onCategoryChanged(String category) {
    AppLogger.debug('ExercisesScreen: Category filter changed to: $category');
    context.read<ExerciseBloc>().add(ExerciseCategoryFilterChanged(category));
  }

  void _onBodyPartChanged(String bodyPart) {
    AppLogger.debug('ExercisesScreen: Body part filter changed to: $bodyPart');
    context.read<ExerciseBloc>().add(ExerciseBodyPartFilterChanged(bodyPart));
  }

  Future<void> _showCreateExerciseSheet() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController();
    final muscleGroupController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Exercise',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: muscleGroupController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Muscle Group (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final exercise = Exercise.create(
                            name: nameController.text.trim(),
                            category: categoryController.text.trim().isEmpty
                                ? null
                                : categoryController.text.trim(),
                            muscleGroup:
                                muscleGroupController.text.trim().isEmpty
                                    ? null
                                    : muscleGroupController.text.trim(),
                            description:
                                descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                            isCustom: true,
                          );
                          context
                              .read<ExerciseBloc>()
                              .add(ExerciseCreateRequested(exercise));
                          Navigator.pop(context);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    muscleGroupController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExerciseBloc, ExerciseState>(
      listener: (context, state) {
        // Handle side effects
        if (state.errorMessage != null) {
          AnimatedFeedback.showSnackBar(
            context,
            state.errorMessage!,
            backgroundColor: Colors.red,
          );
        }

        if (state.successMessage != null) {
          AnimatedFeedback.showSnackBar(
            context,
            state.successMessage!,
            backgroundColor: Colors.green,
          );
          if (state.successMessage!.contains('Exercise')) {
            context
                .read<ExerciseBloc>()
                .add(const ExerciseCategoriesLoadRequested());
            context
                .read<ExerciseBloc>()
                .add(const ExerciseBodyPartsLoadRequested());
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Exercises'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showCreateExerciseSheet,
                tooltip: 'Create Exercise',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshExercises,
              ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Search bar
                    _buildSearchBar(context, state),

                    // Filters
                    _buildFilters(context, state),

                    // Exercise list
                    _buildExerciseList(context, state),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, ExerciseState state) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(25.0)),
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilters(BuildContext context, ExerciseState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
              ),
              value: state.selectedCategory,
              items: state.categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _onCategoryChanged(value);
                }
              },
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Muscle Group',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
              ),
              value: state.selectedBodyPart,
              items: state.bodyParts.map((bodyPart) {
                return DropdownMenuItem(
                  value: bodyPart,
                  child: Text(bodyPart),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _onBodyPartChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(BuildContext context, ExerciseState state) {
    return Expanded(
      child: state.filteredExercises.isEmpty
          ? const Center(child: Text('No exercises found'))
          : ListView.builder(
              itemCount: state.filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = state.filteredExercises[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  child: ListTile(
                    title: Text(exercise.name),
                    subtitle: Text(exercise.category ?? ''),
                    trailing: Text(exercise.muscleGroup ?? ''),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExerciseDetailScreen(exercise: exercise),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
