# UI & Device Test Tooling Evaluation — Phase 6.3

## Evaluated Tools

1. **Patrol (`patrol`, Apache-2.0)**:
   - Drives both Flutter widgets and native OS permission/notification dialogs directly from Dart tests.
   - Strong fit for Android/iOS physical device permission flows (`POST_NOTIFICATIONS`, `RECORD_AUDIO`, Wi-Fi Direct).
2. **Maestro (Apache-2.0)**:
   - YAML-based end-to-end flows driving the compiled app via accessibility/semantics tree.
   - Zero Flutter dependency coupling, ideal for smoke E2E flows on CI emulators.

## Recommendation
- Continue using `flutter_test` + `integration_test` + `ascii_layout` for fast hermetic PR gates.
- Adopt **Patrol** for native OS permission & notification tests when physical/emulator Android matrix runs are enabled in CI.
