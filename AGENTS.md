# AGENTS.md — nook

## Project
- Single-package Flutter app (not a monorepo).
- SDK constraint: Dart `>=3.5.0 <4.0.0`, Flutter stable.
- Entry point: `lib/main.dart`.
- Status: Alpha — v0.8.2 (store-ready builds, in-app update checker).
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

## CI (`CI & Release` — `.github/workflows/ci.yml`)
- Every job starts with the shared composite action `.github/actions/flutter-prep`
  (pub get + appflowy/talker patches + build_runner). The Windows job passes
  `patch-local-auth: 'true'`. **If you add a new pre-build step, put it in the
  composite action so every job gets it.**
- Triggers: `workflow_dispatch`, push to `main`, tags `v*`, PRs to `main`.
  `concurrency` cancels superseded runs; every job has a `timeout-minutes`.
- Artifact jobs (all `needs: analyze-and-test`, parallel): `build-android`
  (split-per-ABI APKs), `build-windows` (zip + Inno Setup `.exe`), `build-ios`
  (unsigned), `build-macos` (unsigned `.app`), `build-linux` (release bundle
  tarball; needs `ninja-build libgtk-3-dev libsecret-1-dev`).
- `release` runs only on tags, requires Android to succeed, and attaches every
  artifact that built successfully. Release body is extracted from CHANGELOG
  by tag name — a `## [x.y.z]` entry must exist for each tagged version.

## Android ABI splits & version codes (F-Droid)
- Release builds are split per ABI: `flutter build apk --release --split-per-abi`
  produces `app-armeabi-v7a/arm64-v8a/x86_64-release.apk`. The gradle block in
  `android/app/build.gradle.kts` re-encodes each ABI's version code as
  `base × 10 + offset` (v7a=1, arm64=2, x86_64=3) — **base 6 → 61/62/63** — so
  F-Droid's `VercodeOperation: ['%c * 10 + 1', '%c * 10 + 2', '%c * 10 + 3']`
  matches. Bump the base code in `pubspec.yaml` (version `x.y.z+N`) for every
  release; the offsets stay fixed.
- The override MUST be `android.applicationVariants.configureEach` (registered
  after the Flutter Gradle plugin's own `abi*1000+base` override at
  `FlutterPlugin.kt`), because `configureEach` runs in registration order and
  the later block wins. `androidComponents.onVariants` is overwritten by the
  plugin and yields `1xxx/2xxx/4xxx` codes — do not switch back.
- Release builds use `--obfuscate --split-debug-info=build/symbols` (smaller
  `libapp.so`; symbols archived by CI for `flutter symbolize`). The F-Droid
  metadata (`metadata/com.devparadise.nook.yml` in the fdroiddata repo) uses
  `srclibs: flutter@3.44.8`, `ndk: r28c` (= 28.2.13676358), and three per-ABI
  build blocks with `--split-per-abi --target-platform=android-arm|arm64|x64`.

## Lint / format
- Includes `flutter_lints/flutter.yaml` plus custom rules in `analysis_options.yaml`.
- Single quotes preferred; `avoid_print: true`; generated files excluded.

## Icons
- **Hugeicons** (`hugeicons ^1.1.7`): 5,100+ stroke-rounded icons, the sole icon library.
- All widgets use `HugeIcon(icon: HugeIcons.strokeRoundedXxx, size: N)`. `HugeIcon` has a `const` constructor — use `const` where possible.
- `HugeIcon.icon` is `List<List<dynamic>>` (not `IconData`). `empty_state.dart`'s `icon` field is `List<List<dynamic>>` accordingly.
- In tests, `find.byIcon(...)` does NOT work. Use: `find.byWidgetPredicate((w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedXxx)`.
- No `lucide_flutter`, no `Icons.xxx`, no `cupertino_icons` — those dependencies are removed.
- `appflowy_editor`'s `AFMobileIcons` are NOT replaced (different package).

## Platform
Android, iOS, macOS, Linux, Windows, and Web targets are present. `flutter run` defaults to the host platform.
- Wide (tablet/desktop/web) shell pins the left `NavigationRail` at 80px (`lib/core/widgets/app_shell.dart`).
- Dual-pane list screens (Home, Notebooks, Tags) tint the left list pane with `scheme.surfaceContainerLow` so it reads as a distinct surface against the detail pane.

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
- AutoNAT stray dials are a known open item. mDNS on physical devices is handled by `NookMdnsDiscovery.resolveActiveInterface()` (pins the active LAN NIC), `reusePort: false` on Android, an Android `WifiManager.MulticastLock` held via the `com.nook/multicast_lock` channel (`MainActivity.kt`), and a manual "Add device by address" fallback (`SyncDevice.fromManualAddress`) when multicast is blocked. **Cross-network discovery** uses Android Wi-Fi Direct (`WifiDirect` in `lib/core/platform/wifi_direct.dart` + `com.nook/wifi_direct` channels) to join the receiver's P2P group and dial it over the P2P link — Android-only and safely a no-op on other platforms. Real-device mDNS/Wi-Fi Direct is still worth re-validating per Android stack.

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
- **appflowy_editor patches**: `tool/patch_appflowy_editor.dart` idempotently patches two files in the pub cache after `flutter pub get` (CI step name: "Patch appflowy_editor (onFocusReceived + mobile slash)"):
  - `delta_input_service.dart` — adds the `TextInputClient.onFocusReceived` override Flutter 3.44+ requires; `appflowy_editor 6.2.0` does not implement it, so ANY test/app importing the editor fails to compile (`delta_input_service.dart:7:7 missing implementations`). Same override `NonDeltaTextInputService` ships.
  - `slash_command.dart` — makes the `/` slash command work on mobile. The stock `_showSlashMenu` returns false on mobile, so typing `/` silently does nothing; simply removing the guard breaks touch devices because the SelectionMenu overlay closes the soft keyboard and relies on hardware-keyboard navigation. The patch inserts the `/` character (visual breadcrumb) and consumes the event without showing the overlay; block insertion on mobile comes from `MobileToolbarV2` instead.
  - **Remove the script + CI step once `appflowy_editor` publishes both fixes (`>= 6.2.1`).** Note: `flutter test` caches compiled test kernels under `build/test_cache/`, so local edits to pub-cache package files may not be picked up — delete `build/` to force a fresh compile when validating.
- **local_auth_windows MSVC coroutine patch**: `local_auth_windows 2.0.1` passes `/await` and pulls in `<experimental/coroutine>`, which newer MSVC toolchains reject with `error C2338` unless `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` is defined. CI and local Windows builds must run `dart run tool/patch_local_auth_windows.dart` after `flutter pub get` to add the define to the plugin’s CMake target. **Remove once `local_auth_windows` stops using deprecated coroutine headers.**

## Mobile toolbar & global shortcuts
- Non-checklist notes wrap `AppFlowyEditor` in `MobileToolbarV2` (`lib/features/editor/note_editor_screen.dart`, `_buildMobileToolbarItems()`), themed to the note's scheme with translucent frosted surfaces: a custom blocks menu (H1/H2/H3, bulleted/numbered lists, checkbox, quote — the same block types the desktop `/` slash menu offers), a Doodle action item that opens the doodle canvas via `_insertDoodle()`, and `textDecorationMobileToolbarItemV2`. This is the **only** keyboard toolbar — the old `_FloatingFormatBar` pill was removed; do not reintroduce it (it duplicated the toolbar above the keyboard).
- Global desktop shortcuts live in `lib/core/widgets/keyboard_shortcuts.dart` (wraps the `MaterialApp.router.builder` output): `/` and Ctrl/Cmd+K open search (`/home/search`), Ctrl/Cmd+N creates a note (`/note/new`). A guard suppresses them while a text input has focus (an `EditableText` anywhere in the focused widget's ancestry, or the AppFlowy editor's nested `FocusScope`), so typing `/` inside the editor still opens AppFlowy's slash menu. Covered by `test/core/widgets/keyboard_shortcuts_test.dart`.

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

## Developer tools
- **In-app log viewer**: `talker_flutter` (`TalkerFlutter.init`, global instance in `lib/core/providers/talker_provider.dart`) records app, sync, database, editor, and security events. `Settings → Developer → App Logs` (`lib/features/settings/settings_logs_screen.dart`) renders `TalkerScreen` with a theme-aware `logColors` map (scheme colors for error/info/debug plus distinct colors for the `sync`, `database`, `editor`, `security` domain keys), newest-first, plus a pure-Flutter first-visit help tour. `FlutterError.onError` and `PlatformDispatcher.instance.onError` are hooked to `talker.handle()` in `main.dart`, and startup events (DB open/fallback, preferences loaded) are logged there.
- **talker_flutter ListTile patch**: `tool/patch_talker_flutter.dart` idempotently wraps the package's `ListTile`s (actions bottom sheet + settings cards) in `Material(type: MaterialType.transparency)` so they stop triggering Flutter's "ListTile background color or ink splashes may be invisible" framework warning (which would otherwise flood the log viewer). CI runs it after `flutter pub get`, right after the appflowy patch. Remove once upstream wraps the tiles.

## Branding & distribution
- **Launcher icons**: `flutter_launcher_icons ^0.14.4` (config block at the bottom of `pubspec.yaml`). Sources in `assets/icons/` (`favicon_fg.png` transparent foreground, `favicon_full.png` full logo). Android adaptive icon = foreground over `#FBFBFB` (`android/app/src/main/res/values/colors.xml`), regenerated legacy mipmaps, plus iOS/macOS/Windows icons. Re-run after changing art: `flutter pub get && dart run flutter_launcher_icons`.
- **Linux window icon**: `linux/runner/icon.png` installs to `bundle/data/icon.png` via `linux/CMakeLists.txt`; `linux/runner/my_application.cc` applies it with `gtk_window_set_icon_from_file` (path derived from `fl_dart_project_get_assets_path`). If the icon ever moves, both the CMake DESTINATION and the C++ path must change together.
- **Windows installer**: `dart run tool/build_installer.dart` (run after `flutter build windows --release`, on a Windows host with Inno Setup installed) writes `build/installers/nook_setup_<ver>.iss` and compiles it with `iscc`. Flags: `--dry-run` validates ISS generation on any host; `--iscc <path>` points at ISCC.exe. A real build **fails loudly** (exit 1) if `iscc` is missing — it must never report success without an `.exe`. Installs to `{localappdata}\nook` with `PrivilegesRequired=lowest` (no admin), stable `AppId`, modern wizard, LZMA2, Start Menu folder + opt-in desktop shortcut. `_homeUrl` points at the `prit-007/nook` repo. CI (`.github/workflows/ci.yml` `build-windows`) installs Inno Setup via Chocolatey, builds the installer, verifies the `.exe` was produced, and ships it.
- **Linux build prerequisite**: Linux desktop builds require the system package `libsecret-1-dev` (`pkg_check_modules` in `flutter_secure_storage_linux`). `sudo apt-get install -y libsecret-1-dev`.
- **Docs**: ADRs `docs/adr/0009-app-launcher-icons-and-linux-window-icon.md` and `docs/adr/0010-windows-installer.md` record the decisions.

## Implementation checklist
- Full task-by-task checklist: `docs/IMPLEMENTATION-CHECKLIST.md`
- Tracks completion status across all 8 phases (0–7) with file references

## Architecture plan
- Planned directory structure is in `docs/notes-app-masterplan.md` §9 (`core/`, `data/`, `sync/`, `features/`).
- Planned go_router routes (~22 routes) are documented in `docs/notes-app-part3-editor-routes-libraries.md` §3.
- Implemented under `lib/` (`main.dart` entry point); sync lives in `lib/sync/`.
