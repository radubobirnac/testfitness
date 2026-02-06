# Timer Audit

## UI entrypoints (rest timer)
- `lib/screens/workout_detail_screen.dart`: `_completeSet` calls `showRestTimer(...)` to open `RestTimerScreen` after a set is completed; `_showRestTimer` allows manual launch.
- `lib/screens/exercise_detail_screen.dart`: `_toggleSetCompletionForExercise` calls `_startRestTimer`, which dispatches `TimerInitialized` and `TimerStarted` into `TimerBloc`.

## Where the timer truth lives (post-fix)
- `lib/services/rest_timer_manager.dart`: `RestTimerManager` holds the anchored end times, remaining time, status, persistence, and notification scheduling.
- `lib/blocs/timer/timer_state.dart`: `TimerState` mirrors manager state for UI rendering (not the source of truth).

## Tick mechanism (per-second updates)
- `lib/services/rest_timer_manager.dart`: internal periodic refresh runs while foregrounded; remaining time is computed from anchored end times.
- `lib/screens/rest_timer_screen.dart`: subscribes to the manager stream and renders state; no local ticking logic.
- `lib/blocs/timer/timer_bloc.dart`: subscribes to the manager stream and emits `TimerState` updates; no tick decrement logic.

## Cancellation/cleanup
- `lib/services/rest_timer_manager.dart`: stops internal ticker on pause/stop/complete; clears persisted state on stop/complete.
- `lib/screens/rest_timer_screen.dart`: cancels subscription on dispose and stops manager when closing the full-screen timer.
- `lib/blocs/timer/timer_bloc.dart`: cancels manager subscription on close.

## Background/lifecycle handling
- `lib/services/rest_timer_manager.dart`: `WidgetsBindingObserver` refreshes timing on resume and marks completions that occur while backgrounded.

## Notifications/scheduling
- `lib/services/rest_timer_manager.dart`: schedules a completion notification at the anchored end time; cancels on pause/stop/complete.
- `lib/screens/app_loader.dart`: creates the `timer_channel_id` notification channel for timer alerts and configures the manager with the plugin.
- `android/app/src/main/AndroidManifest.xml`: includes `SCHEDULE_EXACT_ALARM` permission for exact alarms.

## Persistence (state survival)
- `lib/services/rest_timer_manager.dart`: persists end time anchors, duration, remaining time, and status in SharedPreferences.
- `lib/services/user_preferences_service.dart`: persists default rest timer duration and sound preference.

## Other timer-like code paths (non-rest-timer)
- `lib/services/boxing_service.dart`: uses `Timer` and `Timer.periodic` for boxing rounds/rest/combination calls.
- `lib/screens/vo2_max_training_screen.dart`: uses periodic timing for interval training.

## Observed root cause(s) (captured before refactor)
- FM-1 (UI-owned timer): fullscreen rest timer state was kept in widget fields and cancelled in `dispose`.
- FM-2 (lifecycle-tied timer): app-bar rest timer used a plain `Timer.periodic` with no background scheduling.
- FM-3 (tick = truth): remaining time was decremented on each tick (no anchor end timestamp).
- FM-4 (background restrictions): notifications were only scheduled for very short timers; no background worker/FGS path.
- FM-5 (process death): no persisted end timestamp or status.
- FM-6 (incorrect clocks risk): elapsed timing used wall clock time.

