# AGENTS.md — nook

## Project
- Single-package Flutter app (not a monorepo).
- SDK constraint: Dart `>=3.5.0 <4.0.0`, Flutter stable.
- Entry point: `lib/main.dart`.
- Status: Pre-alpha, Phase 0 (foundation) — very little app code exists yet.
- Docs: `docs/notes-app-masterplan.md` (product/roadmap), `docs/notes-app-detailed-plan.md` (schema/architecture/protocols), `docs/SYNC-LIBP2P-TRANSPORT.md` (current sync transport reference), `docs/adr/` (architecture decision records).

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
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage -x network
```
`flutter test` accepts `-x <name>` to skip (CI skips the real-mDNS test, tagged `network`), or `<path>:<line>` to run a single test.

## Lint / format
- Includes `flutter_lints/flutter.yaml` plus custom rules in `analysis_options.yaml`.
- Single quotes preferred; `avoid_print: true`; generated files excluded.

## Platform
Android, iOS, macOS, Linux, Windows, and Web targets are present. `flutter run` defaults to the host platform.

## Storage / sync
- Drift + SQLCipher for encrypted local storage.
- **libp2p (UDX) is the default sync transport** (`dart_libp2p ^1.0.3`): Noise encryption + Yamux multiplexing over UDP. No server, no account. The legacy TCP transport (`TcpSyncTransport`) is kept behind `useTcpFallback: true`.
- Stable device identity = libp2p peer id derived from a 32-byte Ed25519 seed persisted in `flutter_secure_storage` (`lib/sync/crypto/identity_store.dart`); never hardcoded.
- Encryption key stored in platform keystore via `flutter_secure_storage`; never hardcoded.
- DB opened only after biometric gate (`local_auth`) succeeds.

## Sync architecture (libp2p transport)
- Wire envelope (`lib/sync/protocol/sync_message.dart`): `[4B big-endian length][32B SHA-256][CBOR]`, checksum verified before deserialization. One `SyncMessage` per stream: `pairingRequest/pairingAccepted/pairingRejected/dataBundle/ack`.
- One stream per transaction with half-close (`closeWrite` → read response to EOF). `read()` returns ONE chunk and blocks ~5 min by default — the transport sets `setReadDeadline()` before every await so a missing ack times out in seconds.
- Discovery: `lib/sync/discovery/nook_mdns_discovery.dart` — a fork of dart_libp2p's mDNS with its own `_syncnotenet._udp` service, `devicename=` TXT record, and split `advertiseOnly()`/`discoverOnly()` modes (sender discovers, receiver advertises). `debugInjectPeer()` makes it testable without multicast.
- The receiver holds a pairing stream until the user decides (`respondToPairing`), with a 120s cleanup deadline so undecided requests don't leak; a rejected pairing is a distinct outcome from a timeout.
- `SyncOutcomeCategory` (`rejected | timedOut | connectionLost | cancelled | protocol | internal`) drives distinct UI treatments in `sync_transfer_screen.dart` — a decline is NOT shown as a generic red error.
- AutoNAT: `applyDefaults()` hard-sets `enableAutoNAT = true` after options run, so the transport forces `Reachability.private` (skips ambient probing dials) instead — a LAN-only app must never dial public peers.
- AutoNAT stray dials / Android MulticastLock (pure Dart can't hold one) are known open items; mDNS works but is unproven on some Android stacks.

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
- **local_auth_windows MSVC coroutine patch**: `local_auth_windows 2.0.1` passes `/await` and pulls in `<experimental/coroutine>`, which newer MSVC toolchains reject with `error C2338` unless `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` is defined. CI and local Windows builds must run `dart run tool/patch_local_auth_windows.dart` after `flutter pub get` to add the define to the plugin’s CMake target. **Remove once `local_auth_windows` stops using deprecated coroutine headers.**

## Testing
- Data layer: unit tests against in-memory Drift `NativeDatabase.memory()`.
- Merge resolver: table-driven tests covering every branch (new note, older incoming, same-lineage newer, true conflict).
- Widgets: `flutter_test` golden tests for NoteCard across color seeds / locked / pinned states.
- Sync transport: loopback UDX tests between two in-process libp2p hosts (no multicast) — `test/sync/libp2p_test_host.dart` builds hosts with `forceReachability(Reachability.private)` + a keep-all addrs factory (the defaults strip loopback and would make dials fail). The real-mDNS round trip is tagged `network` and skipped by CI.
- Sync integration: two-emulator test harness (Android emulators can talk over virtual network for Nearby Connections).
- Strategy documented in `docs/notes-app-detailed-plan.md` §11.

## Sync protocol
- Payload: CBOR-encoded `SyncBundle` with `SyncNoteEntry` items, SHA-256 checksum verified before deserialization.
- Conflict resolution: `promptUser` for true conflicts — never silently overwrite.
- Never auto-resolve a genuine conflict silently; surface a conflict card with "Keep this device / Keep incoming / Keep both."

## Implementation checklist
- Full task-by-task checklist: `docs/IMPLEMENTATION-CHECKLIST.md`
- Tracks completion status across all 8 phases (0–7) with file references

## Architecture plan
- Planned directory structure is in `docs/notes-app-masterplan.md` §9 (`core/`, `data/`, `sync/`, `features/`).
- Planned go_router routes (~22 routes) are documented in `docs/notes-app-part3-editor-routes-libraries.md` §3.
- Implemented under `lib/` (`main.dart` entry point); sync lives in `lib/sync/`.
