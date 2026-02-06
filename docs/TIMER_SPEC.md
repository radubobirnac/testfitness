# Rest Timer Spec (Chosen Architecture)

## Behavior Summary
- Rest timer is the set-completion timer and manual timer launched from workout screens.
- Background behavior: remaining time must be accurate on return; a completion notification should fire even if the app is backgrounded.
- Per-second background UI updates are not required; per-second updates occur only while the app is foregrounded.

## Ranked Options

### Option A (Recommended baseline): Anchor end time + persistence
- Store an end time anchor (prefer monotonic clock) and compute remaining time from it.
- Persist end time and duration so the timer survives process death.
- Pros: reliable accuracy on return, minimal battery impact, survives process death.
- Cons: no continuous background UI updates.

### Option B (Recommended add-on): Completion notification scheduling
- Schedule a one-shot local notification at the anchored end time.
- Use `exactAllowWhileIdle` for better delivery in Doze.
- Pros: user gets a completion alert while backgrounded; pairs cleanly with Option A.
- Cons: exact alarms may require permission; exact delivery not guaranteed on all OEMs.

### Option C (Not chosen unless strict background ticking is required): Foreground service
- Run a ForegroundService updating a persistent notification each second.
- Pros: true background ticking and visible countdown.
- Cons: higher battery cost and UX friction (persistent notification), more Android-specific work.

## Chosen Solution
Option A + Option B.

## Implementation Summary
- `RestTimerManager` is the single source of truth. It stores:
  - `endElapsedMs` (monotonic when available) and `endEpochMs` as fallback.
  - `totalDurationMs`, `remainingMs`, `status`, `notificationsEnabled`.
- UI renders based on manager state; the UI never decrements time itself.
- State is persisted in SharedPreferences and restored on app start.
- Completion notifications are scheduled for the end timestamp and cancelled on pause/stop/complete.
- Timer completion while backgrounded is flagged so UI avoids replaying completion sound on resume.

## Files/Components
- `lib/services/rest_timer_manager.dart`: Source of truth + persistence + scheduling.
- `lib/blocs/timer/timer_bloc.dart`: Maps manager state to `TimerState` for app-bar UI.
- `lib/screens/rest_timer_screen.dart`: Fullscreen UI subscribing to manager.
- `android/app/src/main/kotlin/com/radubobirnac/testfitness/MainActivity.kt`: Method channel for monotonic time.
- `lib/screens/app_loader.dart`: Initializes notification system and timer manager.

## Constraints and Tradeoffs
- Exact alarm delivery depends on Android exact alarm permission and OEM policies.
- If monotonic clock is unavailable, the timer falls back to wall-clock time.
