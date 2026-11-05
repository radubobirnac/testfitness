import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io'; // Import dart:io for Platform check
// import 'dart:typed_data'; // For Int64List - removed, using foundation.dart instead
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testfitness/blocs/app/app_bloc.dart';
import 'package:testfitness/blocs/app/app_state.dart';
import 'package:testfitness/repositories/exercise_repository.dart';
import 'package:testfitness/repositories/workout_repository.dart';
import 'package:testfitness/screens/app_with_error_screen.dart';
import 'package:testfitness/screens/main_screen.dart';
import 'package:testfitness/screens/splash_screen.dart';
// import 'package:testfitness/screens/haptic_test_screen.dart'; // Removed - debug screen not needed
import 'package:testfitness/utils/app_logger.dart';
import 'package:testfitness/services/database_service_factory.dart';
import 'package:testfitness/services/exercise_seed_service.dart';
import 'package:testfitness/services/user_preferences_service.dart';
import 'package:testfitness/services/rest_timer_manager.dart';
import 'package:testfitness/services/timer_debug_reporter.dart';

/// SharedPreferences key AppBloc stores the dark-mode switch under. It is only
/// written once the user flips the switch, so its absence means "no choice
/// made yet": the app then follows the system light/dark setting.
const String darkModePreferenceKey = 'dark_mode';

/// Whether the user explicitly chose light or dark mode (true) or the app
/// follows the system theme (false). Loaded during start-up and updated by the
/// Dark Mode setting on the profile screen.
final ValueNotifier<bool> userThemeOverride = ValueNotifier<bool>(false);

// Global instance for notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  static const bool _autoTestHeadsUp =
      bool.fromEnvironment('TIMER_DEBUG_AUTOTEST', defaultValue: false);
  bool isLoading = true;
  String? error;
  String? stackTrace;
  bool isDatabaseInitialized = false;

  // Progress tracking for initialization
  double _initializationProgress = 0.0;
  String _currentPhase = 'Starting up...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Phase 1: Initialize Notifications
      _updateProgress(0.1, "Initializing notifications...");
      AppLogger.info("Phase 1: Initializing notifications...");
      await _initializeNotifications();
      AppLogger.info("Notifications initialized successfully");
      await _maybeScheduleHeadsUpAutotest();

      // Phase 2: Initialize rest timer manager
      _updateProgress(0.2, "Preparing rest timer...");
      AppLogger.info("Phase 2: Initializing rest timer manager...");
      RestTimerManager()
          .configureNotifications(flutterLocalNotificationsPlugin);
      await RestTimerManager().initialize();
      AppLogger.info("Rest timer manager initialized successfully");

      // Phase 3: Initialize user preferences
      _updateProgress(0.35, "Loading user preferences...");
      AppLogger.info("Phase 3: Initializing user preferences...");
      await UserPreferencesService().initialize();
      try {
        final prefs = await SharedPreferences.getInstance();
        userThemeOverride.value = prefs.containsKey(darkModePreferenceKey);
      } catch (e) {
        AppLogger.warning('Could not read theme preference: $e');
      }
      AppLogger.info("User preferences initialized successfully");

      // Phase 4: Initialize database
      _updateProgress(0.65, "Setting up database...");
      AppLogger.info("Phase 4: Initializing database...");
      await _initializeDatabase();
      AppLogger.info("Database initialized successfully");

      // Phase 5: Preload data for repositories
      _updateProgress(0.85, "Loading workout data...");
      AppLogger.info("Phase 5: Preloading repository data...");
      await _preloadRepositories();
      AppLogger.info("Repository data preloaded successfully");

      // All initialization complete
      _updateProgress(1.0, "Ready to go!");
      AppLogger.info("Initialization complete - ready to show main app");

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e, st) {
      AppLogger.error("Error during initialization", e, st);

      if (mounted) {
        setState(() {
          error = e.toString();
          stackTrace = st.toString();
          isLoading = false;
        });
      }
    }
  }

  /// Update initialization progress and current phase
  void _updateProgress(double progress, String phase) {
    if (mounted) {
      setState(() {
        _initializationProgress = progress;
        _currentPhase = phase;
      });
    }
  }

  /// Initialize the local notifications plugin
  Future<void> _initializeNotifications() async {
    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use app icon

    // iOS initialization settings (requesting permissions)
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            onDidReceiveLocalNotification: (id, title, body, payload) async {
              // Handle notification tapped logic here (optional)
            });

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) async {
      // Handle notification tapped logic here (optional)
      // e.g., navigate to a specific screen based on payload
    });

    // Create high priority notification channels for Android
    if (!kIsWeb && Platform.isAndroid) {
      // Note: We'll request permissions later when user actually wants to use timer notifications
      // This prevents the app from opening to the alarms/notifications settings page on startup
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Don't request permissions automatically - this causes the app to open to alarms page
      // await androidImplementation?.requestNotificationsPermission();
      // await androidImplementation?.requestExactAlarmsPermission();

      try {
        // Create the timer notification channel with max priority
        final AndroidNotificationChannel timerChannel =
            AndroidNotificationChannel(
          'timer_channel_id', // Channel ID
          'Timer Notifications', // Channel Name
          description:
              'Channel for timer completion sounds', // Channel Description
          importance: Importance.max, // Maximum importance
          playSound: true, // Enable sound
          enableVibration: true, // Enable vibration
          vibrationPattern:
              Int64List.fromList([0, 500, 200, 500]), // Vibration pattern
          sound: RawResourceAndroidNotificationSound(
              'shipbell'), // Use the custom sound
          showBadge: true, // Show badge on app icon
          enableLights: true, // Enable notification light
          ledColor: Color.fromARGB(255, 255, 0, 0), // Red LED for urgency
        );

        // Create the channel in the system
        await androidImplementation?.createNotificationChannel(timerChannel);

        AppLogger.info(
            "Created high-priority notification channel for timer alerts");
      } catch (e) {
        AppLogger.warning("Error creating notification channel", e);
        // Try again without vibration pattern which might be causing issues
        try {
          const AndroidNotificationChannel fallbackChannel =
              AndroidNotificationChannel(
            'timer_channel_id', // Channel ID
            'Timer Notifications', // Channel Name
            description:
                'Channel for timer completion sounds', // Channel Description
            importance: Importance.max, // Maximum importance
            playSound: true, // Enable sound
            enableVibration: true, // Enable vibration
            sound: RawResourceAndroidNotificationSound(
                'shipbell'), // Use the custom sound
          );

          // Create the channel in the system
          await androidImplementation
              ?.createNotificationChannel(fallbackChannel);
          AppLogger.info(
              "Created fallback notification channel for timer alerts");
        } catch (e) {
          AppLogger.error("Error creating fallback notification channel", e);
        }
      }
    }
  }

  Future<void> _maybeScheduleHeadsUpAutotest() async {
    if (!_autoTestHeadsUp || !kDebugMode) return;
    try {
      await TimerDebugReporter()
          .scheduleHeadsUpTest(delay: const Duration(seconds: 10));
      AppLogger.info('Heads-up debug test scheduled (10s).');
    } catch (e) {
      AppLogger.warning('Heads-up debug test scheduling failed', e);
    }
  }

  /// Initialize the database
  Future<void> _initializeDatabase() async {
    try {
      // Note: web exercise storage used to be wiped here on every launch
      // (to pick up new default exercises), which deleted users' custom
      // exercises. The web DB seeds defaults only when storage is empty, and
      // ensureDefaultExercises below adds any missing defaults by name
      // without creating duplicates.

      // Initialize database factory
      await DatabaseServiceFactory.initialize();

      // Verify database connection with a simple query
      final dbService = DatabaseServiceFactory.getDatabaseService();

      final added = await ExerciseSeedService.ensureDefaultExercises(dbService);
      final exercises = await dbService.getExercises();
      final seededMessage = added > 0 ? ' (seeded $added defaults)' : '';
      AppLogger.database(
        "Database connection verified",
        "${exercises.length} exercises loaded$seededMessage",
      );

      isDatabaseInitialized = true;
    } catch (e) {
      AppLogger.error("Database initialization error", e);
      isDatabaseInitialized = false;
      throw Exception("Failed to initialize database: $e");
    }
  }

  /// Preload repositories with data
  Future<void> _preloadRepositories() async {
    if (!isDatabaseInitialized) {
      AppLogger.warning(
          "Database not initialized, skipping repository preloading");
      return;
    }

    try {
      // Preload exercise data
      final exerciseRepo = ExerciseRepository();
      await exerciseRepo.getExercises();

      // Preload workout data
      final workoutRepo = WorkoutRepository();
      await workoutRepo.getWorkouts();

      AppLogger.info("Repositories preloaded successfully");
    } catch (e) {
      AppLogger.warning("Repository preloading error", e);
      // Continue without failing - this is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    // If still loading, show splash screen with progress
    if (isLoading) {
      return SplashScreen(
        progress: _initializationProgress,
        currentPhase: _currentPhase,
      );
    }

    // If there was an error, show error screen
    if (error != null) {
      return AppWithErrorScreen(
        error: error!,
        stackTrace: stackTrace,
        onRetry: () {
          setState(() {
            isLoading = true;
            error = null;
            stackTrace = null;
            _initializationProgress = 0.0;
            _currentPhase = 'Starting up...';
          });
          _initializeApp();
        },
      );
    }

    // If initialization is complete, show the main app
    return const MyApp();
  }
}

/// The main app widget with proper theme and routing
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        // Define our color schemes
        final ColorScheme lightColorScheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
          primary: Colors.teal.shade600,
          secondary: Colors.teal.shade400,
        );

        final ColorScheme darkColorScheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
          primary: Colors.teal.shade400,
          secondary: Colors.teal.shade300,
        );

        return ValueListenableBuilder<bool>(
          valueListenable: userThemeOverride,
          builder: (context, hasOverride, _) => MaterialApp(
            title: 'StrengthWave',
            theme: _buildTheme(lightColorScheme),
            darkTheme: _buildTheme(darkColorScheme),
            // Follow the system light/dark setting until the user explicitly
            // picks one in Profile > Dark Mode.
            themeMode: hasOverride
                ? (state.isDarkMode ? ThemeMode.dark : ThemeMode.light)
                : ThemeMode.system,
            initialRoute: '/',
            onGenerateRoute: (settings) {
              // Define named routes
              if (settings.name == '/') {
                // Extract the initialIndex argument if it exists
                final int? initialIndex = settings.arguments as int?;
                return MaterialPageRoute(
                  builder: (context) =>
                      MainScreen(initialIndex: initialIndex ?? 0),
                );
              }
              // haptic_test route removed - debug screen not needed in production

              // Return null for unknown routes
              return null;
            },
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // AppBar theme - use semantic colors from the scheme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
        actionsIconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),

      // Button themes - use semantic colors
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),

      // Text buttons - no explicit foreground color, let Material decide based on context
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
      ),

      // Floating action button theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      // Dialog theme for better visibility
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
        ),
      ),
    );
  }
}
