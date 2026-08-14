<div align="center">

# 🕊️ Nook

> **Your notes. Your device. Yours.**

A private, local-first, free-and-open-source note-taking app built with Flutter.

**No account. No cloud. No telemetry. Ever.**

Notes are encrypted at rest on your device, and when you want them on another
one of your devices, they travel **directly over your Wi-Fi** — never through a
server, never through us.

<br />

![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows%20%7C%20Web-lightgrey.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.44%20stable-02569B.svg)
![Status](https://img.shields.io/badge/status-pre--alpha-important.svg)

</div>

---

## What is Nook?

Nook is a note-taking app built around one simple belief:

> **Your notes belong to you — not to a service.**

Every big note app makes you trade data ownership for good design. Google Keep
and Apple Notes are lovely but cloud-tied and closed. Nook refuses that
tradeoff:

- **Local-first, not local-only-as-an-afterthought.** It works fully offline
  forever. There is no sign-in screen, no account, no "continue to use in a
  browser."
- **Sync is a feature you opt into** — direct, peer-to-peer, over nearby Wi-Fi.
  Your notes beam from one of *your* devices to another, byte-for-byte, with no
  relay in between.
- **Free software with teeth.** Nook is GPL-3.0. Anyone can read it, change it,
  and build on it. Nobody can take it closed.

## The motto

> **_Your notes. Your device. Yours._**

Three clauses, three promises:

1. **Your notes** — the content is yours: full-text search, checklists, doodles,
   per-note theming. We help you make more of them, not lock them away.
2. **Your device** — the home is yours: encrypted SQLite on-device, keys in the
   platform keystore, biometric gate. Nothing leaves unless you say so.
3. **Yours** — the future is yours: GPL-3.0, every byte of source readable,
   every path open to fork, extend, and reuse.

## Status

🚧 **Pre-alpha — v0.7.5** — Phases 0–4 complete (foundation, core notes,
checklists + doodles, theming, security). Phase 5 (nearby sync) is implemented:
the transport was rebuilt on **libp2p over UDX** with a stable keystore identity,
an own mDNS discovery fork, and categorized failure outcomes. Legacy TCP remains
as a fallback. Loopback transport + orchestrator tests are green; physical-device
validation remains. See [`docs/IMPLEMENTATION-CHECKLIST.md`](docs/IMPLEMENTATION-CHECKLIST.md).

## Features

| Area | What you get |
|---|---|
| **Notes** | Create, edit, delete, pin, lock, color, cover images |
| **Organization** | Notebooks, tags, multi-tag filtering, FTS5 full-text search |
| **Checklists** | Toggle items, drag-to-reorder, progress bar |
| **Doodles** | Freehand drawing via `perfect_freehand`, saved as attachments |
| **Editor** | Block-based rich editing with the AppFlowy editor |
| **Theming** | Material You 3 dynamic color + per-note color overrides, light/dark |
| **Security** | SQLCipher encryption, biometric gate, per-note lock, screenshot blocking |
| **Trash** | Soft-delete with 30-day auto-expiry |
| **Sync** | libp2p over UDX device-to-device sync: discovery, pairing, transfer, conflict resolution, history |
| **Export** | `.nook` bundle export via `archive` |
| **CI** | GitHub Actions: format, analyze, test, APK build + GitHub releases |

## Privacy & security model

- **Encrypted at rest.** The DB is SQLCipher, keyed from the platform keystore
  (`flutter_secure_storage`). The key is never hardcoded and never sent anywhere.
- **Biometric gate.** The database is opened only after fingerprint/Face unlock.
- **Peer-to-peer sync.** A short pairing code is verified *on both devices*
  before any note crosses the wire. Transfers are framed with a SHA-256 checksum
  verified before deserialization, over a Noise-encrypted libp2p link.
- **No analytics. No crash reporters. No ads.** Nook phones nothing home.

## Getting started as a user

### System requirements

- Flutter **3.44.x** (stable channel) and Dart `>=3.6.0 <4.0.0`
- A device or emulator (Android, iOS, macOS, Linux, Windows, or Web)

### Run it

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

> **Note for library users:** upstream gaps are patched by this repo —
> `appflowy_editor 6.2.0` (`keyboard_height_plugin` SDK,
> `TextInputClient.onFocusReceived`, and the mobile `/` slash command) and
> `talker_flutter` (ListTile ink-splash background). The patches are applied
> automatically by `android/settings.gradle.kts`, `tool/patch_appflowy_editor.dart`
> and `tool/patch_talker_flutter.dart` — **do not skip the two
> `dart run tool/patch_*.dart` steps** after `flutter pub get`.
> Details in [`CONTRIBUTING.md`](CONTRIBUTING.md).

### Build a release APK

```bash
flutter build apk --release
# artifact: build/app/outputs/flutter-apk/app-release.apk
```

## Developing Nook

New here? Read [`CONTRIBUTING.md`](CONTRIBUTING.md) first — it covers the dev
loop, code generation, test commands, and contribution workflow.

Quick orientation while you're here:

```text
lib/
├── core/       app shell, router, theme, providers, platform bridges
├── data/       Drift schema + repositories (notes, tags, attachments, sync log)
├── features/   feature UIs: home, editor, doodle, sync_ui, security, settings…
├── sync/       libp2p/UDX transport, mDNS discovery, protocol, orchestrator
└── main.dart   entry point
```

A full walkthrough of every layer and the sync wire protocol lives in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### Test

```bash
flutter test                              # everything (CI skips the `network` tag)
flutter test -x network                   # hermetic suite, no multicast
flutter test test/sync                    # sync protocol, resolver, orchestrator, transports
flutter test test/sync/libp2p_transport_test.dart   # loopback UDX transport (no mDNS)
flutter test test/sync/tcp_transport_integration_test.dart   # legacy loopback TCP
```

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter (stable) + Dart | one codebase → all platforms |
| State / routing | Riverpod + go_router | reactive, standard, deep-link ready |
| Storage | Drift + SQLCipher | type-safe relational ORM, encrypted at rest |
| Editor | AppFlowy Editor | block node-tree document model |
| Doodle | `perfect_freehand` | smooth freehand strokes |
| Discovery/sync | libp2p over UDX (`dart_libp2p`) + own `_syncnotenet._udp` mDNS fork | zero-server, LAN-only, Noise-encrypted transfer |
| Serialization | CBOR + SHA-256 | compact, portable, checksummed |
| Security | `local_auth`, `flutter_secure_storage` | biometric gate + keystore keys |
| Icons | Hugeicons (stroke-rounded) | luxury editorial iconography, 5,100+ free icons |
| License | GPL-3.0 | freedom from downstream enclosure |

## Documentation

Everything lives in `docs/` and `ADR`/decision records in `docs/adr/`.

| Doc | What it is |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | **Start here.** Current codebase map: layers, sync protocol, editor patches |
| [`docs/SYNC-LIBP2P-TRANSPORT.md`](docs/SYNC-LIBP2P-TRANSPORT.md) | The libp2p/UDX sync transport: wire envelope, lifecycle, discovery, identity, outcomes |
| [`docs/notes-app-masterplan.md`](docs/notes-app-masterplan.md) | Product vision, positioning, roadmap |
| [`docs/notes-app-detailed-plan.md`](docs/notes-app-detailed-plan.md) | Schema, architecture, protocol races, testing strategy |
| [`docs/notes-app-part3-editor-routes-libraries.md`](docs/notes-app-part3-editor-routes-libraries.md) | Editor internals + full route map |
| [`docs/IMPLEMENTATION-CHECKLIST.md`](docs/IMPLEMENTATION-CHECKLIST.md) | Task-by-task build tracker across all phases |
| [`docs/adr/`](docs/adr/) | Architecture decision records |
| [`CHANGELOG.md`](CHANGELOG.md) | Keep-a-Changelog release history |

## Contributing

Nook is free software — the whole point is that people like you can help build
it or use it for your own good. Contributions of every size are welcome: docs,
bug reports, UI polish, tests, features.

Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) and our
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) first.

Quick links:

- [Report a bug](https://github.com/prit-007/nook/issues) · [Submit a PR](https://github.com/prit-007/nook/pulls)
- **Good first issues:** anything tagged with sync, docs, or polish.

## License

Nook is free software: you can redistribute it and/or modify it under the terms
of the **GNU General Public License, version 3** (or, at your option, any later
version), as published by the Free Software Foundation. See [`LICENSE`](LICENSE)
for the full text.

> Your notes. Your device. Yours.