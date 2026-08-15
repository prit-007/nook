# Changelog

All notable changes to Nook are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.2.3] - 2026-08-15

### F-Droid compatibility
- Disabled the `Dependency metadata` APK signing block AGP adds by default
  (`dependenciesInfo { includeInApk = false; includeInBundle = false }`). The
  block is encrypted with a Google Play key, so F-Droid's APK scanner rejects
  any APK that carries it.
- Version bumped to `0.8.2+4` so the fixed APK is built and published.

## [0.8.2.2] - 2026-08-15

### Reproducible F-Droid builds
- Committed `pubspec.lock` (previously gitignored) so F-Droid resolves the
  exact dependency set from the manifest instead of the latest compatible
  versions.

## [0.8.2.1] - 2026-08-15

### CI
- The signing step now reads its secrets from job-level `env` so the real
  keystore password is never interpolated into the workflow file.

## [0.8.2] - 2026-08-15

### Store-ready builds
- Restored the monotonic version scheme (`version: 0.8.2+3`), so every release
  carries a strictly increasing `versionCode` for F-Droid and IzzyOnDroid.
- Release APKs are now signed with a real release keystore (stored as CI
  secrets, never committed), and CI publishes a **universal** signed APK in
  addition to the split-per-ABI ones — ready for store distribution.
- Added `fastlane/metadata` (title, short/full descriptions, per-version
  changelogs) used by both IzzyOnDroid and F-Droid to list the app.

## [0.8.1] - 2026-08-15

### In-app update notifications
- Nook now checks the GitHub releases feed and lets you know when a new version
  is published — no more guessing whether the build you have is current.
- A glass **"Update available"** banner appears on Home when a newer release
  exists, with one-tap **Update** (opens the release page) and **Later** to
  dismiss it.
- **Settings → About → "Check for Updates"** runs a manual check and shows the
  release notes; the tile reports *Checking…* / *vX.Y.Z* / *Up to date*.
- Checks are throttled (once per 6 hours) and re-run on app resume; your
  dismissal is remembered per version and clears when a newer release appears.
- Tagged with the new `updates` domain in the in-app log viewer.

## [0.8.0] - 2026-08-15

### Lossless media sync, export & import
- Notes now travel with **no data loss**: images and doodle strokes (sidecar +
  thumbnail bytes) are bundled, restored byte-for-byte, and re-pointed onto the
  target device.
- Media paths baked into a note's document are rewritten **structurally**
  (`lib/sync/media_path_rewriter.dart`), so a Windows-sourced vault
  (`C:\Users\...` paths, JSON-escaped backslashes) imports and syncs correctly
  onto Android and other devices.
- Doodles are restored in the canonical `DoodleStorage` layout after sync, so
  strokes stay editable on the receiving device; thumbnails are shipped as
  bytes because they cannot be regenerated offline.
- Imported/synced notes keep their notebooks via `notebooks.json`; a missing
  notebook reference falls back to a placeholder instead of a foreign-key error.

### mDNS discovery reliability
- Android `MulticastLock` acquired for the sync session (pure-Dart wrapper +
  Kotlin channel) so discovery survives Wi-Fi/LAN.
- Unsolicited mDNS announcements (every 4s) in addition to PTR responses, so a
  discoverer whose query lands in a gap still finds the device.
- Patched `mdns_dart` 2.2.1's socket leak (closed on query done **and**
  cancellation); applied by CI's `flutter-prep` action.
- Real failure reasons are now logged instead of a stuck "Searching for
  devices..." state.

### Step-by-step logging
- Every step of sync and export/import is logged through the in-app log viewer
  (`Settings → Developer → App Logs`), tagged `sync` / `database` — from device
  found, pairing, dial, transfer and ack, to per-note attachment restore and
  delta re-pointing.

### End-to-end sync tests
- New `test/sync/libp2p_sync_e2e_test.dart`: two real libp2p hosts on loopback
  (no multicast) run the full flow — device finding, pairing confirm/reject,
  media note sync with byte-identical bytes + canonical doodle layout, and
  re-sync overwrite without duplicates.
- New transport knobs (`discoveryNetworkEnabled`, `debugInjectDiscoveredPeer`)
  keep discovery hermetic in tests while exercising real dials.

### Trash & storage polish
- Trash now shows archived attachment thumbnails with a "+N" badge.
- Import summary reports notebooks created; export report warns about
  attachments missing on disk.

## [0.7.9.2] - 2026-08-14

### Alpha status + release pipeline
- Declared **alpha** status in the README; sync is explicitly marked as still
  in testing/development (loopback tests green, physical-device validation
  pending).
- CI (`CI & Release`) is now industry-grade: `workflow_dispatch` trigger,
  concurrency cancel-in-progress, per-job timeouts, and a shared composite
  `flutter-prep` action (pub get + patches + codegen) used by every job.
- **New artifacts shipped per release:** macOS (`nook-macos-*.zip`, unsigned
  `.app`) and Linux (`nook-linux-*.tar.gz`) join Android APKs, the Windows zip
  + Inno Setup `.exe`, and the iOS zip in the GitHub release.
- `tool/build_installer.dart` now fails loudly (non-zero exit) when a real
  build cannot produce the `.exe` because `iscc` is missing; `--dry-run` still
  validates the `.iss` on any host. CI verifies the installer was produced
  before uploading.
- Fixed the placeholder installer home URL (`prit-007/nook`).

## [0.7.9] - 2026-08-14

### Version single source of truth
- Added `package_info_plus`; app version now loads at runtime from the built
  binary (generated from `version:` in `pubspec.yaml`), so there is exactly
  one place to bump it. `AppInfo` became a `FutureProvider`; the Settings
  "Version" tile and About "EDITION" line read from it automatically.
- Updated `settings_screen_test.dart` to mock `PackageInfo`.

### Bug fixes
- Fixed a 4px `RenderFlex` overflow in the editor's auto-hiding glass app bar
  on narrow (landscape-phone) widths. Date and notebook/tag metadata are now
  merged into a single ellipsized subtitle line (`Aug 14, 2026 · Notebook |
  #tag`), so metadata renders on narrow screens too without overflowing.

### Logs screen polish
- Rewrote the diagnostic logs tour overlay: walkthrough cards are constrained
  to `420px` so they never stretch into unreadable rectangles on desktop.
- Moved the Help affordance from a bottom-floating FAB to a frosted pill pinned
  to the top-right safe area.
- Elevated the tour typography (tight tracking, heavy weights) and switched to
  HugeIcons throughout; frosted surface mask replaces the black overlay.

## [0.7.8] - 2026-08-14

### Icon system — Hugeicons stroke-rounded migration
- Replaced **all** Material Icons (`Icons.xxx`) and Lucide Icons
  (`LucideIcons.xxx`) with `HugeIcons` stroke-rounded variants
  (`hugeicons ^1.1.7`) across the entire codebase (50+ lib files, 20+ test
  files).
- Removed `lucide_flutter` and unused `cupertino_icons` dependencies.
- Design language: stroke-rounded for inactive states, solid/duotone for
  active states; rounded shape language for editorial luxury aesthetic.
- `empty_state.dart` icon field widened from `IconData` to
  `List<List<dynamic>>` to accept HugeIcon data; all call sites updated.
- Test files migrated from `find.byIcon(...)` to
  `find.byWidgetPredicate((w) => w is HugeIcon && w.icon == HugeIcons.xxx)`.
- All `prefer_const_constructors` lint issues resolved; `flutter analyze`
  reports zero issues.

### About screen — editorial "About Us" page
- `SettingsAboutScreen` rewritten as a full editorial "About Us" page with
  luxury editorial copy: vision statement, zero-telemetry philosophy, flow
  design principles, and developer's paradise credits.
- Glassmorphic section cards, Playfair Display serif headers, Inter body
  text, and frosted pill badges for license/technology tags.
- Fixed `AppInfo.version` mismatch: the in-app constant was stale at `0.7.1`
  while `pubspec.yaml` read `0.7.7+1`. Both are now `0.7.8+1`.

### App icon & branding — all platforms
- Launcher icons generated with `flutter_launcher_icons ^0.14.4`
  (config at the bottom of `pubspec.yaml`). Sources live in `assets/icons/`:
  `favicon_fg.png` (transparent foreground) + `favicon_full.png` (full logo).
- Android adaptive icon: transparent foreground over a `#FBFBFB` background
  (color resource in `android/app/src/main/res/values/colors.xml`), safe-zone
  inset for launcher shape masking, plus regenerated legacy `mipmap-*` icons.
- iOS, macOS (`AppIcon.appiconset`), and Windows (`app_icon.ico`, 256px)
  app icons regenerated from the same art.
- **Linux window icon**: `linux/runner/icon.png` is bundled into
  `bundle/data/` by the install rule in `linux/CMakeLists.txt` and applied in
  `linux/runner/my_application.cc` via `gtk_window_set_icon_from_file`
  (resolved off `fl_dart_project_get_assets_path`). The runner previously set
  no window icon.

### Windows installer — Inno Setup
- New `tool/build_installer.dart` (pure `dart:io`, no new deps): reads the
  version from `pubspec.yaml`, writes `build/installers/nook_setup_<ver>.iss`,
  and compiles it with the Inno Setup compiler (`iscc`; `--dry-run` validates
  ISS generation on any host, `--iscc <path>` points at the compiler).
- Installer features: stable `AppId` (clean upgrades), `PrivilegesRequired=lowest`
  + `DefaultDirName={localappdata}\nook` (**no admin**), `WizardStyle=modern`,
  LZMA2 solid compression, 64-bit install, GPL license page, Start Menu folder
  + **opt-in** desktop shortcut, launch-after-install.
- CI (`build-windows` job) installs Inno Setup via Chocolatey, runs the
  installer build, and ships `nook_setup_*.exe` in the Windows artifact;
  tag releases now attach the `.exe` alongside the zip and APKs.
- Note: `flutter build windows` + `iscc` only run on a Windows host; the script
  fails fast with a clear message otherwise.

## [0.7.7] - 2026-08-13

### Developer tooling — in-app log viewer
- `talker_flutter` powers an in-app log viewer at `Settings → Developer → App
  Logs` (`lib/features/settings/settings_logs_screen.dart`): a `TalkerScreen`
  themed to the app (custom colors for errors, warnings, info, debug, verbose,
  plus distinct `sync`, `database`, `editor`, `security` domain keys), newest
  first and expanded by default, with a pure-Flutter first-visit help tour.
- Global `talker` instance in `lib/core/providers/talker_provider.dart`;
  `FlutterError.onError` and `PlatformDispatcher.instance.onError` feed into it
  from `main.dart`, so uncaught framework/async errors are visible in-app.
- Logging calls added across repositories, sync, editor, security, and settings
  (`nookLog` with domain keys).
- `tool/patch_talker_flutter.dart` wraps the package's `ListTile`s in a
  `Material` to silence the "ink splashes may be invisible" framework warning.

### Desktop & tablet layout polish
- The wide-shell `NavigationRail` is pinned to a fixed 80px rail
  (`lib/core/widgets/app_shell.dart`); dual-pane Home/Notebooks/Tags tint their
  left list pane with `scheme.surfaceContainerLow`.

### Global keyboard shortcuts
- `lib/core/widgets/keyboard_shortcuts.dart` binds `/` and Ctrl/Cmd+K → search,
  Ctrl/Cmd+N → new note on desktop/web. A focus guard suppresses them while a
  text input is focused (`EditableText` ancestry or the editor's nested
  `FocusScope`), so `/` still opens AppFlowy's slash menu while editing.
  Covered by `test/core/widgets/keyboard_shortcuts_test.dart`.

### Mobile editor — slash menu + toolbar
- `tool/patch_appflowy_editor.dart` now also patches `slash_command.dart`: on
  mobile, `/` inserts the slash character and consumes the event instead of
  doing nothing (the SelectionMenu overlay is unusable on touch — it closes the
  soft keyboard and needs hardware-keyboard navigation).
- The editor is wrapped in `MobileToolbarV2` (translucent, note-themed) with a
  custom blocks menu (H1/H2/H3, bulleted/numbered lists, checkbox, quote), a
  Doodle action that opens the doodle canvas, and text-decoration. The old
  `_FloatingFormatBar` pill was removed.
- New ADR: `docs/adr/0008-mobile-editor-toolbar-and-global-shortcuts.md`.

### Fixes
- Logs screen now shows a back button (help moved to a floating frosted chip).
- `ListTile` ink-splash warnings fixed in the trash screen and the security
  screen's frosted glass cards.

## [0.7.5] - 2026-08-13

The sync transport is rebuilt on **libp2p over UDX** — a server-less, account-free
peer-to-peer link with Noise encryption and Yamux multiplexing. The legacy TCP
transport stays behind a fallback flag.

### Sync — libp2p UDX transport (default)
- Default transport is now `dart_libp2p` over UDX (UDP-based reliable transport):
  Noise encryption + Yamux stream multiplexing, loopback-testable in CI.
  (`lib/sync/transport/libp2p_sync_transport.dart`)
- **Stable device identity.** A 32-byte Ed25519 seed is sealed in the platform
  keystore on first run and derived into a permanent libp2p peer id afterwards —
  no more random UUID per launch. (`lib/sync/crypto/identity_store.dart`)
- New wire envelope: `[4-byte big-endian length][32-byte SHA-256][CBOR]` with the
  checksum verified *before* deserialization, and one `SyncMessage`
  (`pairingRequest/pairingAccepted/pairingRejected/dataBundle/ack`) per stream
  using half-close request/response. (`lib/sync/protocol/sync_message.dart`)
- Nook's own mDNS fork (`_syncnotenet._udp`) advertises a `devicename=` TXT
  record so peer names need no extra round-trip, and splits advertise/discover
  modes to match the one-directional sync flow.
  (`lib/sync/discovery/nook_mdns_discovery.dart`)
- **Distinct failure outcomes.** Rejections, timeouts, connection losses,
  cancellations, and protocol errors are categorized and drive separate UI
  treatments — a declined transfer shows an amber "Transfer Declined" instead of
  a generic red error; timeouts and dropped links offer a retry.
- The legacy `TcpSyncTransport` remains available via `useTcpFallback: true`.

### Testing & tooling
- Loopback UDX integration tests run between two in-process libp2p hosts with no
  multicast (`test/sync/libp2p_transport_test.dart`,
  `test/sync/libp2p_integration_test.dart`). The real-mDNS round trip is tagged
  `network` and skipped in CI.
- CI now runs `flutter test --coverage -x network`.
- Added Android (INTERNET, network state, Wi-Fi multicast, NEARBY_WIFI_DEVICES),
  iOS (NSLocalNetworkUsageDescription + NSBonjourServices), and macOS
  (network.client/server) permissions for discovery + transfer.
- Version bumped to 0.7.5+1.

## [0.7.2] - 2026-08-13

Tablet layouts, accessibility pass, and a resilient release pipeline.

### Tablet & foldable
- Adaptive single-pane to dual-pane master–detail layouts for home, notebooks,
  and tags. On larger screens (tablets, foldables) selecting a note, notebook,
  or tag fills a preview pane instead of pushing a new screen — instant
  preview with no navigation depth.
- New preview panes: note preview, notebook detail, and tag detail. Compact
  (phone) layouts still navigate the classic way.

### Accessibility
- Semantic labels, button roles, and hints added across home, notebooks, tags,
  search, sync, and the editor — every interactive element is announced by
  TalkBack/VoiceOver.
- WCAG AA contrast: the color picker and swatches pick white or near-black
  foreground from relative luminance instead of hardcoded white.
- Touch targets audited against the Material 48x48dp minimum.
- The reduce-motion preference is honored by masked reveals, the editorial
  FAB, and card entrance animations.

### Tooling
- The release step is now resilient: Android APKs always ship on a tag even if
  the Windows or iOS build is flaky — only artifacts from successful builds
  are published. APKs stay as direct per-ABI downloads, no zip wrapper.
- Version bumped to 0.7.2+1.

## [0.7.1] - 2026-08-12

Encrypted sync, editorial motion, and multi-platform release builds.

### Sync & security
- End-to-end encryption for device-to-device sync: ECDH key exchange plus
  AES-GCM session cipher (`cryptography`/`pointycastle`), integrated into the
  TCP sync transport.
- PIN pairing screens rebuilt on `pin_code_fields` — the six-digit code now
  renders in a tactile, tap-to-copy field on both the sender and receiver.
- **Vault encryption at rest is now real.** The `sqlite3` build hook bundles
  the SQLCipher library, so `PRAGMA key` actually encrypts the on-disk
  database. Previously the plain `sqlite3` build silently ignored the pragma
  and wrote plaintext; the no-op `sqlcipher_flutter_libs`/`sqlite3_flutter_libs`
  shims are removed. New installs start encrypted; existing pre-0.7.1 vault
  files are not readable and should be re-imported.

### Editor & UI
- GSAP-style masked-reveal macro-typography: titles on tags, trash, and
  notebook detail slide up from an invisible baseline mask.
- Staggered masked entrances for tag pills, trash rows, and note grids.
- Parallax card motion on home, tag, and notebook card grids — cards drift
  from their grid slot as you scroll, giving the layout physical weight.
  All animation respects the reduce-motion preference.

### Tooling
- CI publishes release artifacts per Android ABI (`--split-per-abi`), plus a
  zipped Windows build and an unsigned iOS build, assembled into a single
  GitHub release whose body is generated from this changelog.
- Version bumped to 0.7.1+1.

## [0.7.0] - 2026-08-12

Major reliability and correctness release: a deep bug sweep across the sync
protocol, data layer, editor, and UI.

### Sync
- Received bundles are now processed serially, so back-to-back frames can no
  longer interleave database writes or acknowledgments.
- Attachment restore is idempotent: stale rows are removed before overwrite,
  doodle layers upsert instead of colliding on primary keys, and image IDs are
  preserved — re-syncing a note no longer duplicates files or rows.
- Frame writes are atomic per socket; a maximum frame size guards against
  memory-exhaustion; protocol version is validated on receive.
- Soft-deleted notes are never resurrected by sync; `syncVersion` bumps no
  longer drift `updatedAt`; clock-skew no longer causes incorrect overwrites.
- Transport cleanup now cancels all subscriptions and closes the pairing
  controller; a second device is rejected mid-transfer.

### Data layer
- Production vault now opens the encrypted on-disk database instead of
  in-memory, so data survives app restarts.
- Foreign keys are enforced; note deletion cascades to tags, checklists,
  attachments, and full-text search; multi-statement operations are
  transactional.
- `updateNote` no longer silently clears `notebookId`; `updateContent` keeps
  sync timestamps intact; `toggleChecked` is atomic; FTS5 queries are
  sanitized.
- Doodle saves write the sidecar file before creating the attachment row.

### Editor & UI
- Doodle strokes are persisted before the canvas closes, preventing data loss.
- Safe hex color parsing everywhere (no more crashes on malformed seeds).
- Editor saves no longer race disposal and keep the in-editor note fresh.
- Vault import/export, privacy screen, and live vault stats shipped.

## [0.6.2] - 2026-08-12

UI/UX redesign of the sync and settings surfaces — Lucide iconography, polished
copy, and a fixed conflict card crash.

### Sync screen
- Layout replaced with "glass mode" cards; Send and Receive actions promoted as
  prominent tappable cards.
- "Send to Device" card and a Sync History action moved into the app bar.

### Send flow
- Send screen now has a search bar for filtering the note selection list.
- Empty state copy updated to "No notes found."

### Receive flow
- Discoverable toggle with updated "Make this device visible" copy.
- Switched to a `LucideIcons.smartphone` device-name icon.

### Pairing & Transfer
- Pairing screen rewired: "Confirm Identity" trusted copy, Confirm / Cancel
  actions.
- Transfer screen reworked into distinct states — "Establishing Link...",
  "Beaming Notes..." / "Receiving Notes...", "Transfer Complete",
  and "Transfer Failed" — with the idle-state Cancel button removed.

### Conflict resolution (`ConflictCard`)
- Redesigned as an editorial split view with a tinted local panel
  ("This device") and an incoming remote panel ("Incoming"), using
  "Keep this device / Keep incoming / Keep both" actions.
- Fixed a crash where `CrossAxisAlignment.stretch` inside a min-height column
  threw an infinite-height assertion when the card rendered in a scrollable.

### Settings
- Appearance, Security, Storage, and About screens refreshed with Lucide icons
  and consistent layout.

### Other
- Swapped Material Icons for `LucideIcons` across sync UI.
- Widget tests updated for the new labels and icon assertions.

## [0.6.1] - 2026-08-12

### Fixed
- Sync conflict resolution: "Keep both" / "Keep remote" correctly preserve the
  note id and resolve the conflict; pairing screen full wiring.
- Applied `dart format` repo-wide.

## [0.6.0] - 2026-08-11

Editor UX upgrades, shape assist, checklist polish, and the CI release pipeline.

- Note editor: 300px reachability buffer, zen mode, glass app bar with dynamic
  date format, floating formatting pill.
- Checklist editor: animated progress bar, swipe-to-check, floating glass input
  pill, reorderable list with keyboard-aware padding.
- Doodle: `shapeAssistEnabled` toggle, rectangle snap detection, v2 codec with
  `isPerfectShape` field, backward-compatible deserialization.
- Doodle toolbar: shape assist as a toggle (not a tool), `activeColor` param.
- Sync: bonsoir TCP transport (replaces `nearby_service`), `_ackCompleter`
  cleanup, receive/send screen wiring, history refresh after clear.
- CI: GitHub Actions release pipeline with `softprops/action-gh-release`,
  tag-triggered APK builds, and auto-generated release notes.

[Unreleased]: https://github.com/anomalyco/nook/compare/v0.7.8...HEAD
[0.7.8]: https://github.com/anomalyco/nook/compare/v0.7.7...v0.7.8
[0.7.7]: https://github.com/anomalyco/nook/compare/v0.7.5...v0.7.7
[0.7.5]: https://github.com/anomalyco/nook/compare/v0.7.2...v0.7.5
[0.7.2]: https://github.com/anomalyco/nook/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/anomalyco/nook/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/anomalyco/nook/releases/tag/v0.7.0
[0.6.2]: https://github.com/anomalyco/nook/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/anomalyco/nook/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/anomalyco/nook/releases/tag/v0.6.0