# AGENTS.md — nook

## Project
- Single-package Flutter app (not a monorepo).
- SDK constraint: Dart `>=3.5.0 <4.0.0`, Flutter stable.
- Entry point: `lib/main.dart`.
- Status: Pre-alpha, Phase 0 (foundation) — very little app code exists yet.
- Docs: `docs/notes-app-masterplan.md` (product/roadmap), `docs/notes-app-detailed-plan.md` (schema/architecture/protocols), `docs/adr/` (architecture decision records).

## Code generation
Run before tests, analysis, or any build:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```
Generates: `*.g.dart` (Drift), `*.freezed.dart` (Freezed), `*.drift.dart` (Drift). These are excluded from analysis.

## Commands (in order)
CI runs these in sequence; mirror locally:
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
`flutter test` accepts `-x <name>` to skip, or `<path>:<line>` to run a single test.

## Lint / format
- Includes `flutter_lints/flutter.yaml` plus custom rules in `analysis_options.yaml`.
- Single quotes preferred; `avoid_print: true`; generated files excluded.

## Platform
Android, iOS, macOS, Linux, Windows, and Web targets are present. `flutter run` defaults to the host platform.

## Storage / sync
- Drift + SQLCipher for encrypted local storage.
- `nearby_service` for Wi-Fi device-to-device sync — no server, no account.
- Encryption key stored in platform keystore via `flutter_secure_storage`; never hardcoded.
- DB opened only after biometric gate (`local_auth`) succeeds.

## Editor
- Uses `appflowy_editor` (node-tree document model, not Delta-based flutter_quill).
- Custom node types: `doodle` (stroke data in Attachments table, thumbnail inline) and re-skinned `todo_list`.
- Autosave is the app's responsibility: listen to `editorState.transactionStream`, debounce ~600ms, serialize `document.toJson()`, write to Drift.

## Editor gotchas
- `AppFlowyEditorLocalizations.delegate` must be added to `MaterialApp.localizationsDelegates` or the editor throws at runtime.
- Mobile support is newer than desktop/web — test touch gestures (selection handles, long-press menu, slash menu) early on real Android devices.
- No built-in Drift persistence; that is intentional and already handled by the app.
- **keyboard_height_plugin patch**: `appflowy_editor ^6.2.0` depends on `keyboard_height_plugin ^0.1.5`, which ships `compileSdkVersion 31`. On AGP 9+ (Flutter 3.44+), this fails AAR metadata checks because transitive AndroidX deps require SDK 34. The fix lives in `android/settings.gradle.kts` — it patches the plugin's `build.gradle` in the pub cache during settings evaluation. **Remove the patch block once `appflowy_editor` bumps `keyboard_height_plugin` to `>=0.3.0`.** Monitor: https://github.com/AppFlowy-IO/appflowy-editor/issues/1036
- **flutter_windowmanager replaced**: The discontinued `flutter_windowmanager 0.2.0` (v1 embedding + jcenter, incompatible with AGP 9+) has been replaced with a direct `MethodChannel` implementation at `lib/core/platform/window_manager.dart` + `MainActivity.kt`. The old pub-cache patch block in `android/settings.gradle.kts` has been removed.
- **DeltaTextInputService patch**: Flutter 3.44+ added `TextInputClient.onFocusReceived`; `appflowy_editor 6.2.0` does not implement it, so ANY test/app importing the editor fails to compile (`delta_input_service.dart:7:7 missing implementations`). CI runs `dart run tool/patch_appflowy_editor.dart` after `flutter pub get` to add the override idempotently (same one `NonDeltaTextInputService` ships). The pub cache is patched the same way on local machines. **Remove the script + CI step once `appflowy_editor` publishes the override (`>= 6.2.1`).** Note: `flutter test` caches compiled test kernels under `build/test_cache/`, so local edits to pub-cache package files may not be picked up — delete `build/` to force a fresh compile when validating.

## Testing
- Data layer: unit tests against in-memory Drift `NativeDatabase.memory()`.
- Merge resolver: table-driven tests covering every branch (new note, older incoming, same-lineage newer, true conflict).
- Widgets: `flutter_test` golden tests for NoteCard across color seeds / locked / pinned states.
- Sync integration: two-emulator test harness (Android emulators can talk over virtual network for Nearby Connections).
- Strategy documented in `docs/notes-app-detailed-plan.md` §11.

## Sync protocol
- Payload: CBOR-encoded `SyncBundle` with `SyncNoteEntry` items, SHA-256 checksum verified before deserialization.
- Conflict resolution: `promptUser` for true conflicts — never silently overwrite.
- Never auto-resolve a genuine conflict silently; surface a conflict card with "Keep this device / Keep incoming / Keep both."

## Nearby sync (out of scope for now)
- `nearby_service` v0.2.1 is in pubspec but no sync code exists yet.
- Plan is in `docs/notes-app-detailed-plan.md` §9 and `docs/notes-app-masterplan.md` §6.

## Implementation checklist
- Full task-by-task checklist: `docs/IMPLEMENTATION-CHECKLIST.md`
- Tracks completion status across all 8 phases (0–7) with file references

## Architecture plan (not yet implemented)
- Planned directory structure is in `docs/notes-app-masterplan.md` §9 (`core/`, `data/`, `sync/`, `features/`).
- Planned go_router routes (~22 routes) are documented in `docs/notes-app-part3-editor-routes-libraries.md` §3.
- Current `lib/` contains only `main.dart` (barebones Flutter template).
