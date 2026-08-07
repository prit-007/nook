# Nook

> Your notes. Your device. Yours.

A private, local-first, FOSS note-taking app built with Flutter. No account, no
cloud, no telemetry. Notes are encrypted at rest and can be synced directly
device-to-device over Wi-Fi — never through a server.

Nook is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

## Status

🚧 Pre-alpha — Phase 1 (core notes) complete, Phase 2 (checklists + doodles) next.

## Core principles

1. Local-first, not local-only-as-an-afterthought — the app works fully
   offline forever, no account required.
2. Sync is a feature you opt into, not infrastructure you depend on — direct
   device-to-device only, always user-initiated.
3. Every note can look different; the app chrome stays consistent.
4. Delight lives in the small interactions, not just the big features.
5. Security is default-on but invisible until needed.

See `docs/` for the full architecture and product plan.

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Tech stack (short version — see docs/adr for the reasoning)

- Flutter + Riverpod + go_router
- Drift (SQLite) + SQLCipher for encrypted local storage
- AppFlowy Editor for the block-based note editor
- Material You 3 dynamic + per-note theming
- `nearby_service` for device-to-device sync (no server, ever)

## License

GPL-3.0. See `LICENSE`.
