import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_event.dart';
import 'package:testfitness/blocs/app/app_state.dart';
import 'package:testfitness/screens/exercises_screen.dart';
import 'package:testfitness/screens/home_screen.dart';
import 'package:testfitness/screens/profile_screen.dart';
import 'package:testfitness/screens/progress_screen.dart';
import 'package:testfitness/screens/workouts_screen.dart';
import 'package:testfitness/utils/app_logger.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  // Static method to switch tabs using BLoC
  static void switchToTab(BuildContext context, int index) {
    try {
      AppLogger.navigation('Switching to tab $index via static method');
      context.read<AppBloc>().add(AppTabChanged(index));
    } catch (error) {
      AppLogger.error('Failed to switch tab via static method', error);
    }
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const List<Widget> _screens = [
    HomeScreen(),
    WorkoutsScreen(),
    ExercisesScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize app state and set initial tab if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBloc = context.read<AppBloc>();

      // Initialize the app
      appBloc.add(const AppInitialize());

      // Set initial tab if different from default
      if (widget.initialIndex != 0) {
        AppLogger.navigation('Setting initial tab to ${widget.initialIndex}');
        appBloc.add(AppTabChanged(widget.initialIndex));
      }
    });
  }

  void _onItemTapped(int index) {
    AppLogger.navigation('Tab tapped: $index');
    context.read<AppBloc>().add(AppTabChanged(index));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        // Show loading screen while app is initializing
        if (!state.isInitialized && state.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show error screen if initialization failed
        if (!state.isInitialized && state.errorMessage != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to initialize app',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ?? 'Unknown error occurred',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AppBloc>().add(const AppInitialize());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Main app UI
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: child,
                ),
              );
            },
            child: IndexedStack(
              key: ValueKey(state.currentTabIndex),
              index: state.currentTabIndex,
              children: _screens,
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: state.currentTabIndex,
              onTap: _onItemTapped,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center),
                  label: 'Workouts',
                ),
                BottomNavigationBarItem(
                    icon: Icon(Icons.list), label: 'Exercises'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.trending_up), label: 'Progress'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
        );
      },
    );
  }
}
