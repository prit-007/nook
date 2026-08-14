# Contributing to Nook

First off — thank you for being here. Nook is free software: it only stays free
and alive if people like you help build it, fix it, document it, or fork it for
your own good. This file tells you everything you need to get a working dev
environment and land your first change.

## Quick links

- **Docs index:** [`README.md`](README.md) · [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- **Bug reports & ideas:** [GitHub Issues](https://github.com/prit-007/nook/issues)
- **Pull requests:** [GitHub Pulls](https://github.com/prit-007/nook/pulls)
- **Code of conduct:** [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)

## Prerequisites

- Flutter **stable** 3.44.x (CI pins `3.44.8`) with Dart `>=3.6.0`
- A working `flutter doctor` (Android toolchain for APK builds)

## Setting up the project

```bash
# 1. Clone and enter the repo
git clone https://github.com/prit-007/nook.git
cd nook

# 2. Resolve dependencies
flutter pub get

# 3. Patch appflowy_editor + talker_flutter (REQUIRED — see below)
dart run tool/patch_appflowy_editor.dart
dart run tool/patch_talker_flutter.dart

# 4. Generate Drift / Freezed / Riverpod code
dart run build_runner build --delete-conflicting-outputs

# 5. Smoke-test the app
flutter run
```

Steps 3–4 must be re-run whenever `pubspec.yaml` or the pub cache changes.

## The dev loop (what CI checks)

CI runs these in order. Mirror them locally before pushing:

```bash
dart format --output=none --set-exit-if-changed .   # 1. formatting
flutter analyze                                     # 2. static analysis
flutter test                                        # 3. all tests
```

Options that come in handy:

```bash
flutter test test/sync                             # sync subsystem only
flutter test test/sync/tcp_transport_integration_test.dart
flutter test -x slow                               # skip tagged-slow tests
flutter test test/some_test.dart:42                # single test by line
```

> **Gotcha:** `flutter test` caches compiled kernels under `build/test_cache/`.
> If you edit a pub-cache package (e.g. the patched `appflowy_editor`), delete
> `build/` first to force a fresh compile.

## Code generation

Run **before** tests, analysis, or any build:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) are gitignored
from analysis; regenerate rather than edit them by hand.

## Editor patches (why they exist)

`appflowy_editor ^6.2.0` has upstream gaps that this repo currently patches:

1. **`keyboard_height_plugin` compile-SDK mismatch** — the transitive plugin
   ships `compileSdkVersion 31`, which fails AAR metadata checks on AGP 9+.
   Fixed in `android/settings.gradle.kts` during settings evaluation. Remove
   once the plugin bumps to `>=0.3.0`.
   Track: https://github.com/AppFlowy-IO/appflowy-editor/issues/1036
2. **Missing `TextInputClient.onFocusReceived`** — Flutter 3.44 added it, but
   `appflowy_editor` doesn't implement it, so editors won't compile.
   `tool/patch_appflowy_editor.dart` adds the override idempotently. Remove
   once `appflowy_editor` publishes `>= 6.2.1`.
3. **`/` slash command dead on mobile** — the stock `_showSlashMenu` returns
   false on mobile, so typing `/` does nothing, and the `SelectionMenu`
   overlay can't be shown on touch (it closes the soft keyboard and needs
   hardware-keyboard navigation). The same `tool/patch_appflowy_editor.dart`
   instead inserts the `/` character as a visual breadcrumb and consumes the
   event; block insertion happens through the app's `MobileToolbarV2` (see
   AGENTS.md → "Mobile toolbar & global shortcuts").

All three are tracked in [`AGENTS.md`](AGENTS.md). If any upstream is fixed,
delete the corresponding patch and open a PR — a great first contribution.

## Project structure

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full walkthrough. In
short:

```text
lib/
├── core/       app shell, router, theme, providers, platform bridges
├── data/       Drift schema + repositories (notes, tags, attachments, sync log)
├── features/   feature UIs (home, editor, doodle, sync_ui, security, …)
├── sync/       CBOR protocol, merge resolver, orchestrator, TCP transport
└── main.dart
test/
├── core/ data/ features/ sync/    # mirrors lib/
docs/          # plans, ADRs, checklists
tool/          # patch scripts
```

## Code style

- Follow existing conventions in the file you touch (SDK `>=3.5.0`, stable
  Flutter idioms).
- **Single quotes** preferred; `avoid_print: true` is enforced — use a logger.
- Keep formatting to `dart format` output (check with the CI command above).
- **No comments unless they earn their place** — prefer expressive names.

## Sync: what you need to know

The sync subsystem is `lib/sync/` and is the most protocol-sensitive part of
the app:

- **Payload:** CBOR-encoded `SyncBundle` with `SyncNoteEntry` items; a SHA-256
  checksum is verified before deserialization.
- **Transports:** `TcpSyncTransport` speaks a length-prefixed JSON frame protocol
  over raw TCP (hello / pairing_confirm / sync_header / sync_chunk / sync_ack).
- **Resolve:** the merge resolver (`lib/sync/protocol/merge_resolver.dart`)
  reconciles by `deviceOriginId` + `updatedAt` + `syncVersion`.
- **Invariant:** never auto-resolve a genuine conflict silently — surface a
  conflict card ("Keep this device / Keep incoming / Keep both").
- **Testing:** the data/protocol layers are unit-tested against in-memory Drift;
  the transport has a real loopback TCP integration test.

If you change the wire protocol, bump `protocolVersion`, keep
backward-compatibility for legacy payloads, and add table-driven tests.

## Contributing workflow

1. **Fork + branch** off `main` (name it `fix/…`, `feat/…`, `docs/…`).
2. Make small, focused changes with meaningful commit messages.
   Conventional prefixes (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`,
   `style:`) are used in this repo.
3. Run the dev loop from **The dev loop** above — format must be clean,
   `flutter analyze` must pass, and your change needs test coverage.
4. Open a PR. Mention what you changed, why, and how you validated it.

Not sure where to start? Check issues tagged `good first issue`, or come polish
docs/screens/empty-states — delight-in-the-small-stuff is a core value here.

## Testing guidelines

- **Data layer:** unit tests against in-memory Drift (`NativeDatabase.memory()`).
- **Merge resolver:** table-driven tests covering every branch (new note, older
  incoming, same-lineage newer, true conflict).
- **Widgets:** `flutter_test` golden tests for cards/screens across theme states.
- **Transport:** loopback TCP integration tests — no physical devices required.
- **Real-device validation:** documented but run separately (two-emulator
  harness over virtual network for Nearby Connections).

Strategy details: `docs/notes-app-detailed-plan.md` §11.

## Licensing your contribution

Nook is GPL-3.0. By contributing you agree that your work is licensed under
these terms — the same terms everyone else used. If your contribution is not
yours to license, say so up front.