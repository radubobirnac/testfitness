# StrengthWave Context

StrengthWave is a Flutter app for strength training with BLoC-based state management. Rest timing exists in two user flows: a fullscreen rest timer dialog and an app-bar timer used during set completion. The rest timer is now centralized so both UI surfaces read from the same source of truth.

Key rest timer components:
- `lib/services/rest_timer_manager.dart`: Single source of truth for rest timer state, anchored end time, persistence, and completion notification scheduling.
- `lib/blocs/timer/timer_bloc.dart`: Adapts `RestTimerManager` state into UI-facing `TimerState` for the exercise detail screen.
- `lib/screens/rest_timer_screen.dart`: Fullscreen rest timer UI subscribing to `RestTimerManager`.
- `lib/screens/app_loader.dart`: Initializes notifications and configures the timer manager.

Notifications:
- The `timer_channel_id` channel is created in `lib/screens/app_loader.dart` and used for timer completion alerts.
