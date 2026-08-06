# Phase 0 — Foundation Implementation Plan

## Current state
- Single-package Flutter app, barebones `lib/main.dart`, default `widget_test.dart`.
- Pre-alpha, Phase 0: no Drift schema, no Riverpod providers, no routes, no encrypted DB, no editor integration.
- Docs: `notes-app-masterplan.md`, `notes-app-detailed-plan.md`, `notes-app-part3-editor-routes-libraries.md`, `docs/adr/0001`.

## Goal
Deliver a working, testable, encrypted foundation that the rest of the app builds on:
1. Repo hygiene (lint, format, CI)
2. Encrypted local database (Drift + SQLCipher + biometric gate)
3. Riverpod provider skeleton
4. go_router shell with ~22 routes stubbed
5. Design tokens / theme system (Material You 3, per-note seed ready)

## Task order (do not reorder)

### 1. Repo scaffold + CI
- Verify `analysis_options.yaml` rules (single quotes, `avoid_print: true`, generated files excluded).
- CI already mirrors local commands: `dart format` → `flutter analyze` → `flutter test`.
- Add `flutter test --coverage` to CI if not present (it is present in ci.yml).
- Ensure `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` run before analysis/tests in CI (already present).

### 2. Drift schema + migrations + FTS
- Create `lib/data/tables/`: `notebooks.dart`, `notes.dart`, `checklist_items.dart`, `attachments.dart`, `tags.dart`, `note_tags.dart`, `sync_log.dart`.
- Create `lib/data/database.dart` with `AppDatabase extends _$AppDatabase`, schemaVersion 1.
- Add FTS5 virtual table `notes_fts` in `MigrationStrategy.onCreate` (index `title` + `plain_text`).
- Add `plain_text` denormalized column to `Notes` (regenerated from document JSON on save).
- Run `dart run build_runner build --delete-conflicting-outputs` to generate `*.g.dart` / `*.drift.dart`.
- Verify with in-memory unit test: `NativeDatabase.memory()`, create each table, insert row, read back.

### 3. Encrypted DB bootstrap
- Implement `openEncryptedDatabase()` per `notes-app-detailed-plan.md` §3:
  - Generate random 32-byte key, store via `flutter_secure_storage` (`db_encryption_key`).
  - Open via `NativeDatabase.createInBackground` with `PRAGMA key` + `PRAGMA cipher_page_size = 4096`.
- Wrap DB open in `databaseProvider` Riverpod provider (singleton).
- Add biometric gate (`local_auth`) provider: authenticate before exposing `databaseProvider` value.
- Failure modes to handle: no biometric enrolled, biometric cancelled, secure storage read failure.

### 4. Riverpod provider skeleton
- `databaseProvider` → encrypted `AppDatabase`.
- Repository providers: `notebookRepositoryProvider`, `noteRepositoryProvider`, `tagRepositoryProvider`, `attachmentRepositoryProvider`.
- `notesListProvider(filter)` → `StreamProvider` from Drift reactive query.
- `themeProvider` → derives `ColorScheme` from system dynamic color / manual seed / per-note seed.
- `biometricGateProvider` → app-level lock state machine.

### 5. go_router routes stubbed
- Wire ~22 routes per `notes-app-part3-editor-routes-libraries.md` §3.3.
- Implement `redirect` based on `biometricGateProvider` (lock screen intercept).
- Use `ShellRoute` for bottom-nav shell (Home, Notebooks, Tags, Trash, Settings).
- Stub every screen as an empty `Scaffold`; no business logic yet.
- Ensure `AppFlowyEditorLocalizations.delegate` is in `MaterialApp.localizationsDelegates` now, to avoid runtime crash later.

### 6. Design tokens / theme system
- Curated seed palette: 12–16 M3-friendly colors (violet, teal, coral, sage, amber, rose, sky, slate, etc.).
- `buildSchemeForSeed(seed, brightness)` helper per detailed plan §5.
- `DynamicColorBuilder` at app root with fallback to manual seed.
- Persist user preference: dynamic color on/off, manual seed, dark/light/system mode.

## Out of scope (do not start in Phase 0)
- AppFlowy Editor wiring, custom node types, slash menu.
- Doodle canvas, perfect_freehand integration.
- `nearby_service` transport, sync protocol, merge resolver.
- Home grid, NoteCard widgets, golden tests.
- Image picker, export, gallery save.
- Settings screens beyond theme toggles.
- `home_widget`, `flutter_local_notifications`, OCR, voice-to-text.

## Decisions needed before starting
1. **Minimum Android API level**: biometric + dynamic color prefer API 31+, but lower is possible with graceful degradation. Pick floor now; affects `local_auth` config and Play Store target.
2. **Web build scope**: Drift supports WASM, but `nearby_service`, `local_auth`, `sqlcipher` won't work on web. Decide Web = read/export-only companion vs. deferred. Recommendation: deferred for v1.
3. **License**: GPL-3.0 vs AGPL-3.0. Recommendation: GPL-3.0 (no server component planned).

## Validation
- `flutter analyze` passes with zero warnings.
- `flutter test` passes (at minimum: in-memory Drift round-trip test, biometric gate provider test, route redirect test).
- `dart format --set-exit-if-changed .` passes.
- App launches on host platform, biometric gate shows, DB opens after auth.
- FTS search returns results on in-memory DB.
