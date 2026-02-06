# StrengthWave - Fitness Tracking Application

## 📱 Overview
StrengthWave is a Flutter-based strength training application designed to help users track their workouts, manage their exercise routines, and achieve their fitness goals.

**Current Status**: Production-ready with BLoC state management architecture

Note: I really, I mean, REALLY like it when you ask me questions that clarify my intent.

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.6.0 or higher
- Android SDK for Android builds
- Xcode for iOS builds (macOS only)

### Build Commands
```bash
# Navigate to project
cd C:\Users\radub\testfitness

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# APK location
build\app\outputs\flutter-apk\app-release.apk
```

## 🏗️ Architecture

### State Management
- **BLoC Pattern**: Complete implementation across all screens
- **AppBloc**: Global state (tabs, theme, preferences)
- **WorkoutBloc**: Workout CRUD operations
- **ExerciseBloc**: Exercise management and search
- **TimerBloc**: Rest timer functionality

### Project Structure
```
lib/
├── blocs/          # BLoC state management
├── models/         # Data models
├── repositories/   # Data access layer
├── screens/        # UI screens
├── services/       # Database, preferences, audio
├── utils/          # Utilities, logging, error handling
└── widgets/        # Reusable UI components
```

## Features

### New Exercises Added
- A comprehensive list of machine-based exercises has been added to the database, categorized as follows:
  - **Shoulders**: Shoulder Press, Lateral Raise, Front Raise
  - **Chest**: Chest Press, Pec Deck, Cable Fly
  - **Back**: Lat Pulldown, Seated Row, Back Extension
  - **Legs**: Leg Press, Leg Curl, Leg Extension
  - **Arms**: Bicep Curl, Tricep Pushdown, Cable Lateral Raise
  - **Core**: Ab Crunch Machine, Cable Woodchopper
  - **Cardio**: Treadmill, Elliptical, Stationary Bike

### User Experience Improvements
- Enhanced user interface for easier navigation and access to new exercises.
- Improved exercise logging functionality to ensure users can track their workouts seamlessly.

### Migration Process
- The application has been updated to allow for the addition of new exercises without losing existing workout data. Users can now add exercises through the app's UI without needing to uninstall or reinstall the application.

## State of the Union (Recent Work)

**AI & connectivity**
- Gemini API key is now loaded from `.env` (no hard‑coded key).
- Connectivity tracking is initialized at startup and the offline banner is enabled app‑wide.
- AI workout creation now asks for single vs multi‑muscle focus and uses that preference.
- AI workout suggestions are cached to avoid repeated API calls; refresh only on demand.

**Timer & watch behavior**
- Rest timer now includes a per‑timer “watch buzz” toggle (notification‑based).
- Background completion notification is skipped when watch buzz is off.
- Timer debug report is available in Profile / Settings > Developer Tools for quick troubleshooting.

**Debugging timer notifications**
- Open Profile / Settings > Developer Tools > Copy Debug Report.
- Paste the report into your issue or message so we can see permissions, channel config, and timer state.

**UX polish**
- Quick Action cards now include haptic feedback on tap.
- Exercise picker shows total count and filtered count.

**Exercise library**
- Added 15 additional machine exercises (assisted pull‑up/dip, high row, pendulum squat, hip thrust machine, etc.).
- Note: default exercises are inserted on first DB creation; existing installs need a migration/insert‑missing step to see the new machines.

**Export/Import**
- JSON export includes workouts + sets + exercises + preferences.
- CSV export includes exercise name, muscle group, and category.
- Import supports merge vs replace‑all; replace‑all creates a rollback JSON backup.
- Import preview shows counts and overwrite estimates.
- CSV import supports StrengthWave, generic CSV, and templates (Strong/Hevy).
- File picker import/export on mobile; web uses browser download prompt.

## Brainstorm: Last Set Completion & Motivation (Share With GPT 5.2)

**Goal**
- Identify reliable signals that the user completed the last set.
- Design lightweight, non-annoying encouragement for the next set.

**Context**
- Rest timer now fires in background via a foreground service.
- Watch buzz is unreliable; we may need app-side nudges.

**Questions for GPT 5.2**
- What behavioral signals can confirm a set is complete (tap, motion, HR, cadence, time)?
- How to combine weak signals into a reliable decision without false positives?
- What prompt styles work best when the user is mentally fatigued?
- How should the app adapt if the user repeatedly skips a set?
- What safeguards reduce notification fatigue?
- What on-device signals can we capture without extra permissions?
- What watch-based signals are realistic across devices?

**Answer Notes (fill in)**
- Signals:
- Signal fusion / thresholds:
- Prompt styles:
- Adaptation when skipping:
- Anti-fatigue safeguards:
- On-device signals:
- Watch signals:

## Future Enhancements
- **User Personalization**: Implement user profiles for tracking progress and personalized workout recommendations.
- **Workout Plans**: Introduce pre-defined workout plans tailored to different fitness goals.
- **Social Features**: Add features for users to connect, share workouts, and participate in challenges.
- **Nutrition Tracking**: Integrate a nutrition tracking feature to help users log meals and caloric intake.
- **Progress Tracking and Analytics**: Develop a dashboard for insights into workout history and performance analytics.
- **Gamification**: Introduce gamification elements to motivate users.
- **Feedback Mechanism**: Implement a feedback system for user suggestions and issue reporting.
- **Integration with Wearable Devices**: Explore integration with fitness trackers and smartwatches.
- **Video Demonstrations**: Include video demonstrations for each exercise.

## Screen Naming Reference

Use these names when referring to screens so we stay aligned:

**Primary tabs**
- Home: `lib/screens/home_screen.dart`
- Workouts (list): `lib/screens/workouts_screen.dart`
- Exercises (library): `lib/screens/exercises_screen.dart`
- Progress: `lib/screens/progress_screen.dart`
- Profile / Settings: `lib/screens/profile_screen.dart`

**Workout flows**
- Workout Detail / Edit Workout: `lib/screens/exercise_detail_screen.dart`
- Exercise Detail / Edit Workout (current editor UI): `lib/screens/exercise_detail_screen.dart`
- Add Exercises (bottom sheet): `lib/screens/exercise_selection_sheet.dart`
- Rest Timer: `lib/screens/rest_timer_screen.dart`

**Feature screens**
- Boxing Cardio: `lib/screens/boxing_cardio_screen.dart`
- Heart Rate Monitor: `lib/screens/heart_rate_monitor_screen.dart`
- VO2 Max Training: `lib/screens/vo2_max_training_screen.dart`
- Weight Test → Selection: `lib/screens/weight_test_selection_screen.dart`
- Weight Test → Execution: `lib/screens/weight_test_execution_screen.dart`
- AI Chat: `lib/screens/ai_chat_screen.dart`
- Performance: `lib/screens/performance_screen.dart`
- TTS Analytics: `lib/screens/tts_analytics_screen.dart`
- Gemini TTS Test: `lib/screens/gemini_tts_test_screen.dart`

**App flow**
- App Loader: `lib/screens/app_loader.dart`
- Splash: `lib/screens/splash_screen.dart`
- Error Screen: `lib/screens/app_with_error_screen.dart`

## Export & Import Status

**Current export support**
- Progress screen has an export + import dialog:
  - Progress report (Markdown)
  - CSV (workouts/sets + exercise names)
  - JSON backup (workouts + sets + exercises + preferences)
  - File save (JSON/CSV) via file picker; web downloads use a browser save prompt
- Implemented in `lib/services/export_import_service.dart` and surfaced in
  `lib/screens/progress_screen.dart`.

**Current import support**
- JSON backup import via paste dialog or file picker (JSON/CSV).
- Import supports Merge or Replace‑All modes.
- CSV import accepts StrengthWave export, generic CSV, and templates (Strong/Hevy).
- Import preview shows counts and overwrite estimates before applying.
- Replace‑All creates a rollback JSON backup when possible.

**Current limitations**
- Goals export/import is supported in the data format but not wired to a user
  goal UI yet.

**Interoperability goal**
- Continue improving portability:
  - Optional file-based import/export (CSV/JSON).
  - Mappings for third‑party app formats.
  - More robust merge options (replace vs merge).

## Getting Started
To get started with the StrengthWave application:

1. **Prerequisites**: Ensure you have Flutter SDK installed (version 3.6.0 or higher)
2. **Clone the repository**: `git clone <repository-url>`
3. **Install dependencies**: `flutter pub get`
4. **Run the app**: `flutter run`

## Building for Release
- **Android APK**: `flutter build apk --release`
- **iOS**: `flutter build ios --release`
- **APK Location**: `build\app\outputs\flutter-apk\app-release.apk`

## 📋 Quick Reference for Augment

### Thread Summary Template
```markdown
# StrengthWave - [Current Phase] Status

**Location**: C:\Users\radub\testfitness\
**Build**: build\app\outputs\flutter-apk\app-release.apk (25.6MB)
**Architecture**: BLoC Pattern (100% Complete)
**Status**: [Current Status - e.g., Production Ready, Phase 3 Development]

## Recent Work
- [List recent changes and features added]

## Architecture Status
- **BLoC State Management**: 100% Complete
- **Repository Pattern**: Maintained with performance monitoring
- **Error Handling**: Enhanced with user-friendly messages
- **Performance**: Real-time monitoring system implemented

## Ready For
- [Next development phase or deployment steps]

## Build Commands
```bash
cd C:\Users\radub\testfitness
flutter build apk --release
# APK: build\app\outputs\flutter-apk\app-release.apk
```
```

### Common Development Commands
```bash
# Build release APK
flutter build apk --release

# Run in debug mode
flutter run

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean build
flutter clean && flutter pub get
```

### Key File Locations
- **Performance Monitor**: `lib/utils/performance_monitor.dart`
- **Error Handling**: `lib/utils/error_handler.dart`
- **BLoC Files**: `lib/blocs/[app|workout|exercise|timer]/`
- **Screens**: `lib/screens/`
- **Models**: `lib/models/`

## Contributing
Contributions are welcome! Please follow standard Flutter development practices and ensure all tests pass before submitting pull requests.

## License
This project is licensed under the MIT License.
