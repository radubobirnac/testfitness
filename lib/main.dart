import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/workout/workout_bloc.dart';
import 'package:testfitness/blocs/exercise/exercise_bloc.dart';
import 'package:testfitness/blocs/timer/timer_bloc.dart';
import 'package:testfitness/screens/app_loader.dart';
import 'package:testfitness/services/api_key_service.dart';
import 'package:testfitness/widgets/offline_indicator.dart';

void main() async {
  // Initialize Flutter bindings first
  WidgetsFlutterBinding.ensureInitialized();

  // Load the user's Gemini API key (stored on-device; never bundled).
  await ApiKeyService().initialize();

  // Initialize connectivity tracking for offline-aware features.
  ConnectivityService().initialize();

  // Start the app with BLoC providers and the AppLoader widget
  runApp(const StrengthWaveApp());
}

/// Root app widget with BLoC providers
class StrengthWaveApp extends StatelessWidget {
  const StrengthWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // App-level BLoC for global state
        BlocProvider<AppBloc>(
          create: (context) => AppBloc(),
        ),
        // Workout BLoC for workout management
        BlocProvider<WorkoutBloc>(
          create: (context) => WorkoutBloc(),
        ),
        // Exercise BLoC for exercise management
        BlocProvider<ExerciseBloc>(
          create: (context) => ExerciseBloc(),
        ),
        // Timer BLoC for rest timer functionality
        BlocProvider<TimerBloc>(
          create: (context) => TimerBloc(),
        ),
      ],
      child: const OfflineIndicator(
        child: AppLoader(),
      ),
    );
  }
}
