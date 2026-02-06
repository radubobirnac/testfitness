# Rest Timer Behavior (Expected)

Scope: the rest timer that starts after a set is completed or when the user opens the rest timer UI.

- Timer type: rest timer (not the workout duration timer or VO2/boxing interval timers).
- Entry points:
  - Completed-set flow in the workout UI should start a rest timer.
  - Manual rest timer launch should start the same rest timer behavior.
- Background behavior expectation:
  - Time should continue to elapse accurately while the app is backgrounded so the remaining time is correct on return.
  - A completion alert should be delivered when the timer finishes even if the app is backgrounded (sound/vibration/notification), matching the existing “Timer Notifications” and “Watch buzz” intent in the UI.
- Update frequency:
  - Per-second background updates are not required as long as the finish time and remaining time are accurate when the user returns.

