# Rest Timer TODO

1) Run the manual rest-timer validation checklist on a real Android device.
   Done when: all items in `docs/TIMER_TESTS.md` pass.

2) Confirm exact-alarm permission behavior on Android 12+.
   Done when: the timer completion notification schedules reliably and the permission flow is acceptable.

3) Add unit tests for RestTimerManager timing/persistence paths.
   Done when: tests cover remainingMs computation, pause/resume, and restore.
