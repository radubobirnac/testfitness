# Rest Timer Validation Plan

## Manual Tests
- Start timer, press Home, wait 30–60 sec, return: remaining time correct.
- Start timer, open another app, lock screen, wait, unlock: remaining time correct.
- Start timer, swipe app away from recents, reopen: timer restores correctly if still running.
- Start timer, rotate screen: no reset and remaining time stays correct.
- Start timer, toggle battery saver: notification still delivered near end; remaining time correct on return.
- Timer end in foreground: sound/vibration/notification behaves per settings.
- Timer end in background: completion notification fires; no duplicate sound on resume.
- Multiple timers: starting a new rest timer replaces the previous one (no duplicate notifications).

## Automated Tests (Recommended)
- Unit test: remainingMs computation from anchored end time.
- Unit test: restore running state from stored end times (including elapsedRealtime path).
- Unit test: pause/resume keeps remainingMs consistent.

