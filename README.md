# Nook

> Your notes. Your device. Yours.

A private, local-first, FOSS note-taking app built with Flutter. No account, no
cloud, no telemetry. Notes are encrypted at rest and can be synced directly
device-to-device over Wi-Fi — never through a server.

Nook is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

## Status

🚧 Pre-alpha — **v0.6.2** — Phases 0–4 complete (foundation, core notes, checklists + doodles, theming, security). Phase 5 (nearby sync) implemented; physical-device validation remaining.

## Core principles

1. Local-first, not local-only-as-an-afterthought — the app works fully
   offline forever, no account required.
2. Sync is a feature you opt into, not infrastructure you depend on — direct
   device-to-device only, always user-initiated.
3. Every note can look different; the app chrome stays consistent.
4. Delight lives in the small interactions, not just the big features.
5. Security is default-on but invisible until needed.

See `docs/` for the full architecture and product plan.

## What's built

- **Core notes** — create, edit, delete, pin, lock, color, cover images
- **Notebooks & tags** — organize notes with notebooks and multi-tag filtering
- **Search** — full-text search via FTS5
- **Checklists** — toggle items, drag-to-reorder
- **Doodles** — freehand drawing with perfect_freehand, saved as attachments
- **Theming** — Material You 3 dynamic color + per-note color overrides, light/dark
- **Security** — SQLCipher encryption, biometric gate, screenshot blocking
- **Trash** — soft-delete with 30-day auto-expiry
- **Sync UI** — pairing, send/receive, transfer progress, conflict resolution, sync history
- **CI** — GitHub Actions: format, analyze, test, build APK artifact + release

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Tech stack

- Flutter 3.44.8 + Dart >=3.6.0
- Riverpod + go_router for state/navigation
- Drift (SQLite) + SQLCipher for encrypted local storage
- AppFlowy Editor for block-based note editing
- Material You 3 dynamic + per-note theming
- Bonsoir/TCP for device-to-device sync (no server, ever)
- `perfect_freehand` for doodle input
- `archive` for `.nook` export bundles
- Custom MethodChannel for Android permissions (no `permission_handler`)

## License

GPL-3.0. See `LICENSE`.
