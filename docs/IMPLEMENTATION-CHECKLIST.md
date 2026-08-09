# Nook — Full Implementation Checklist

> **How to use:** Check off tasks as you complete them. Each task lists the files to create/modify and the validation command to run. Move the `[ ]` → `[x]` when done. Update the status table at the top of each phase when a phase is fully complete.

**Current project state:** Default Flutter counter template (`lib/main.dart`). Dependencies pinned in `pubspec.yaml`. No app code, no Drift schema, no Riverpod providers, no routes, no CI.

---

## Status Overview

| Phase | Description | Status | Started | Completed |
|-------|-------------|--------|---------|-----------|
| 0 | Foundation (scaffold, DB, routing, theme) | **~85% COMPLETE** | 2026-08-05 | — |
| 1 | Core Notes (home grid, editor, notebooks, tags, search) | **~95% COMPLETE** | 2026-08-05 | 2026-08-07 |
| 2 | Checklists + Doodles + Images | **~60% COMPLETE** | 2026-08-07 | — |
| 3 | Theming & Polish (dynamic color, animations, dark mode) | NOT STARTED | — | — |
| 4 | Security (SQLCipher, biometric lock, screenshot blocking) | NOT STARTED | — | — |
| 5 | Nearby Sync (transport, pairing, merge resolver) | NOT STARTED | — | — |
| 6 | Hardening for Play Store (accessibility, export, privacy) | NOT STARTED | — | — |
| 7 | Launch + Iterate (testing track, widgets, voice-to-text) | NOT STARTED | — | — |

---

## Phase 0 — Foundation

**Goal:** Working, testable, encrypted foundation that the rest of the app builds on.
**Duration estimate:** 1–2 weeks

### 0.1 Repo Hygiene & CI

- [x] Verify `analysis_options.yaml` rules are correct (single quotes, `avoid_print: true`, generated files excluded)
  - File: `analysis_options.yaml` (already configured)
- [ ] Create `.github/workflows/ci.yml` — format → analyze → test on push/PR
  - File: `.github/workflows/ci.yml` (does not exist yet)
- [x] Verify `dart format --output=none --set-exit-if-changed .` passes locally
- [x] Verify `flutter analyze` passes locally with zero warnings
- [x] Verify `flutter test` passes locally

### 0.2 Directory Structure

- [x] Create `lib/core/` — theming, constants, extensions, design tokens
  - File: `lib/core/theme/` (directory)
  - File: `lib/core/constants.dart`
  - File: `lib/core/extensions.dart`
- [x] Create `lib/data/` — drift tables, daos, repositories
  - File: `lib/data/tables/` (directory)
  - File: `lib/data/database.dart`
  - File: `lib/data/repositories/` (directory)
- [x] Create `lib/sync/` — transport interface, protocol, conflict resolver
  - File: `lib/sync/` (directory, empty for now)
- [x] Create `lib/features/` — feature screens
  - File: `lib/features/home/` (directory)
  - File: `lib/features/editor/` (directory)
  - File: `lib/features/notebooks/` (directory)
  - File: `lib/features/tags/` (directory)
  - File: `lib/features/search/` (directory)
  - File: `lib/features/sync_ui/` (directory)
  - File: `lib/features/settings/` (directory)
  - File: `lib/features/security/` (directory)
  - File: `lib/features/trash/` (directory)
  - File: `lib/features/onboarding/` (directory)
- [x] Create `lib/app.dart` — MaterialApp.router setup with Riverpod + go_router
  - File: `lib/app.dart`

### 0.3 Drift Schema (7 tables + FTS5)

- [x] Create `lib/data/tables/notebooks.dart` — Notebooks table
  - Columns: id (text, PK, uuid), name (text, 1-100), colorSeed (text), icon (text, default 'notebook'), sortOrder (int, default 0), createdAt (dateTime)
- [x] Create `lib/data/tables/notes.dart` — Notes table
  - Columns: id (text, PK, uuid), notebookId (text, nullable, FK→Notebooks), type (textEnum: text|checklist|doodle|mixed), title (text, default ''), deltaContent (text, nullable — AppFlowy Editor JSON), plainText (text, nullable — denormalized for FTS), colorSeed (text, nullable), coverImagePath (text, nullable), pinned (bool, default false), locked (bool, default false), deleted (bool, default false), deletedAt (dateTime, nullable), createdAt (dateTime), updatedAt (dateTime), deviceOriginId (text), syncVersion (int, default 0)
- [x] Create `lib/data/tables/checklist_items.dart` — ChecklistItems table
  - Columns: id (text, PK, uuid), noteId (text, FK→Notes), text (text), checked (bool, default false), sortOrder (int, default 0)
- [x] Create `lib/data/tables/attachments.dart` — Attachments table
  - Columns: id (text, PK, uuid), noteId (text, FK→Notes), type (textEnum: image|doodleLayer), filePath (text), thumbnailPath (text, nullable), sortOrder (int, default 0)
- [x] Create `lib/data/tables/tags.dart` — Tags table
  - Columns: id (text, PK, uuid), name (text, 1-50), colorSeed (text)
- [x] Create `lib/data/tables/note_tags.dart` — NoteTags junction table
  - Columns: noteId (text, FK→Notes), tagId (text, FK→Tags), PK: (noteId, tagId)
- [x] Create `lib/data/tables/sync_log.dart` — SyncLog table
  - Columns: id (int, autoIncrement), deviceId (text), deviceName (text), noteId (text), action (textEnum: sent|received|conflict), timestamp (dateTime)
- [x] Create `lib/data/database.dart` — AppDatabase class
  - `AppDatabase extends _$AppDatabase`, schemaVersion 1
  - `MigrationStrategy.onCreate`: create all tables + FTS5 virtual table `notes_fts` (fts5, columns: id UNINDEXED, title, plainText)
  - Run `dart run build_runner build --delete-conflicting-outputs`
- [x] Write in-memory Drift round-trip test
  - File: `test/data/database_test.dart`
  - Test: `NativeDatabase.memory()`, create each table, insert row, read back, FTS query returns results

### 0.4 Encrypted DB Bootstrap

- [ ] Implement `openEncryptedDatabase()` per detailed plan §3
  - File: `lib/data/database.dart` (add function)
  - Generate random 32-byte key via `dart:math` + `dart:convert` (base64)
  - Store key via `flutter_secure_storage` (key: `db_encryption_key`)
  - Open via `NativeDatabase.createInBackground` with `PRAGMA key` + `PRAGMA cipher_page_size = 4096`
- [x] Create `databaseProvider` — Riverpod provider (singleton, encrypted DB)
  - File: `lib/core/providers/database_provider.dart`
- [ ] Handle failure modes: no biometric enrolled, biometric cancelled, secure storage read failure
- [ ] Write provider test for databaseProvider (in-memory fallback)
  - File: `test/core/providers/database_provider_test.dart`

### 0.5 Riverpod Provider Skeleton

- [x] Create `lib/core/providers/database_provider.dart` — `databaseProvider`
- [x] Create `lib/data/repositories/notebook_repository.dart` — Notebooks DAO wrapper
  - File: `lib/data/repositories/notebook_repository.dart`
- [x] Create `lib/data/repositories/note_repository.dart` — Notes/ChecklistItems/Attachments DAO wrapper
  - File: `lib/data/repositories/note_repository.dart`
- [x] Create `lib/data/repositories/tag_repository.dart` — Tags DAO wrapper
  - File: `lib/data/repositories/tag_repository.dart`
- [ ] Create `lib/data/repositories/attachment_repository.dart` — Attachments DAO wrapper
  - File: `lib/data/repositories/attachment_repository.dart`
- [ ] Create repository providers (Riverpod)
  - File: `lib/core/providers/repository_providers.dart`
- [ ] Create `notesListProvider(filter)` — StreamProvider from Drift reactive query
  - File: `lib/core/providers/notes_provider.dart`
- [x] Create `themeProvider` — derives ColorScheme from dynamic/manual/per-note seed
  - File: `lib/core/providers/theme_provider.dart`
- [x] Create `biometricGateProvider` — app-level lock state machine
  - File: `lib/core/providers/biometric_provider.dart`
- [x] Wire `ProviderScope` + `app.dart` in `main.dart` (replace default Flutter template)
  - File: `lib/main.dart`

### 0.6 go_router Routes (~22 routes)

- [x] Create `lib/core/router.dart` — GoRouter config with ~22 routes
  - File: `lib/core/router.dart`
- [ ] Implement `redirect` based on `biometricGateProvider` (lock screen intercept)
- [x] Use `ShellRoute` for bottom-nav shell (Home, Notebooks, Tags, Trash, Settings)
- [x] Stub every screen as an empty `Scaffold` — no business logic yet:
  - [x] `lib/features/home/home_screen.dart`
  - [x] `lib/features/home/search_screen.dart`
  - [x] `lib/features/notebooks/notebooks_screen.dart`
  - [x] `lib/features/notebooks/notebook_detail_screen.dart`
  - [x] `lib/features/tags/tags_screen.dart`
  - [x] `lib/features/tags/tag_detail_screen.dart`
  - [x] `lib/features/editor/note_editor_screen.dart`
  - [x] `lib/features/editor/doodle_canvas_screen.dart`
  - [x] `lib/features/trash/trash_screen.dart`
  - [x] `lib/features/security/lock_screen.dart`
  - [x] `lib/features/security/locked_notes_screen.dart`
  - [ ] `lib/features/sync_ui/sync_screen.dart`
  - [x] `lib/features/sync_ui/sync_send_screen.dart`
  - [x] `lib/features/sync_ui/sync_receive_screen.dart`
  - [x] `lib/features/sync_ui/sync_pairing_screen.dart`
  - [x] `lib/features/sync_ui/sync_transfer_screen.dart`
  - [x] `lib/features/sync_ui/sync_history_screen.dart`
  - [x] `lib/features/settings/settings_screen.dart`
  - [x] `lib/features/settings/settings_appearance_screen.dart`
  - [x] `lib/features/settings/settings_security_screen.dart`
  - [x] `lib/features/settings/settings_storage_screen.dart`
  - [x] `lib/features/settings/settings_sync_devices_screen.dart`
  - [x] `lib/features/settings/settings_about_screen.dart`
  - [x] `lib/features/onboarding/onboarding_screen.dart`
- [x] Add `AppFlowyEditorLocalizations.delegate` to `MaterialApp.localizationsDelegates`
  - File: `lib/app.dart`
- [ ] Write route redirect test (lock screen blocks access)
  - File: `test/core/router_test.dart`

### 0.7 Design Tokens / Theme System

- [x] Create `lib/core/theme/design_tokens.dart` — curated seed palette (12–16 M3-friendly colors)
  - Colors: violet, teal, coral, sage, amber, rose, sky, slate, indigo, mint, peach, lavender
- [x] Create `lib/core/theme/app_theme.dart` — `buildSchemeForSeed(seed, brightness)` helper
- [x] Create `lib/core/theme/app_theme.dart` — light theme and dark theme `ThemeData`
- [x] Create `DynamicColorBuilder` at app root with fallback to manual seed
  - File: `lib/app.dart`
- [x] Persist user preference: dynamic color on/off, manual seed, dark/light/system mode
  - File: `lib/core/providers/theme_provider.dart` (use SharedPreferences or Drift)
  - Add `shared_preferences` to `pubspec.yaml` if using that
- [x] Create `lib/core/theme/note_theme_scope.dart` — InheritedWidget for per-note seed color
  - File: `lib/core/theme/note_theme_scope.dart`

### 0.8 Replace Default Template

- [x] Delete default `MyHomePage` counter code from `lib/main.dart`
- [x] Replace with `ProviderScope` → `NookApp` using `MaterialApp.router`
- [x] Delete default counter test from `test/widget_test.dart`
- [x] Replace with smoke test: app builds, shows lock screen or home screen

### Phase 0 Validation

- [x] `dart format --output=none --set-exit-if-changed .` passes
- [x] `flutter analyze` passes with zero warnings
- [x] `flutter test` passes (database round-trip test, provider test, route redirect test)
- [ ] App launches on host platform, shows lock screen or home screen
- [ ] `dart run build_runner build --delete-conflicting-outputs` generates all `*.g.dart`, `*.freezed.dart`, `*.drift.dart`

---

## Phase 1 — Core Notes

**Goal:** Home grid, create/edit/delete text note, AppFlowy Editor integration, notebooks, tags, local search. First internal build that feels good to use.
**Duration estimate:** 2–3 weeks
**Depends on:** Phase 0 complete

### 1.1 Home Grid

- [x] Build `NotesMasonryGrid` — native 2-column responsive fallback (Row + Column, no flutter_staggered_grid_view — incompatible with Flutter 3.44.8)
  - File: `lib/features/home/home_screen.dart` (inline responsive grid)
- [x] Build `NoteCard` — tonal background from note.colorSeed, cover image/thumb, title, preview text, pin badge, lock badge
  - File: `lib/features/home/widgets/note_card.dart`
- [x] Build `HomeScreen` — search bar, view toggle (grid/list), filter chips (All/Pinned/Checklists/Doodles), FAB
  - File: `lib/features/home/home_screen.dart` (replace stub)
- [x] Build `MorphingEditorialFab` — AnimatedScale/Opacity, pill-shaped extended FAB with menu
  - File: `lib/features/home/widgets/morphing_editorial_fab.dart`
- [x] Build `EmptyHome` widget
  - File: `lib/features/home/widgets/empty_home.dart`
- [x] Wire `notesListProvider` to grid — reactive updates from Drift via StreamProvider
  - File: `lib/features/home/providers/notes_list_provider.dart`
- [x] Write `NoteCard` tests (banner, minimal, doodle variants — 23 tests)
  - File: `test/features/home/widgets/note_*_card_test.dart`

### 1.2 Note Editor (Text/Mixed)

- [x] Build `NoteEditorScreen` — immersive app bar, title field, body
  - File: `lib/features/editor/note_editor_screen.dart` (replace stub)
- [x] Integrate AppFlowy Editor (`appflowy_editor ^6.2.0`)
  - Wire `EditorState`, `AppFlowyEditor` widget, `blockComponentBuilders`
  - Register `standardBlockComponentBuilderMap`
- [x] Build autosave: listen to `editorState.transactionStream`, debounce ~600ms, serialize `document.toJson()`, write to Drift
  - File: `lib/features/editor/note_editor_screen.dart`
- [x] Build contextual toolbar (built-in AppFlowy toolbar sufficient; custom overlay not required for Phase 1)
  - File: `lib/features/editor/widgets/contextual_toolbar.dart`
- [x] Build color/theme picker (swatch in app bar → ThemePickerSheet)
  - File: `lib/features/editor/widgets/note_options_sheet.dart`
  - File: `lib/features/editor/widgets/theme_picker_sheet.dart`
- [x] Create new note flow (type param: text/checklist/doodle/mixed)
- [x] Edit existing note flow (load from Drift, populate EditorState)
- [x] Delete note flow (soft delete → move to trash) — editor delete button + TrashScreen with restore/permanent-delete
- [x] Pin/unpin note flow
- [x] Write note editor integration test (create, edit, autosave persists to Drift)
  - File: `test/features/editor/note_editor_test.dart`

### 1.3 Notebooks

- [x] Build `NotebooksScreen` — folder-card grid
  - File: `lib/features/notebooks/notebooks_screen.dart` (replace stub)
- [x] Build `NotebookCard` — color, icon, name, note count
  - File: `lib/features/notebooks/widgets/notebook_card.dart`
- [x] Build notebook CRUD (create, rename, delete, assign color/icon)
  - File: `lib/features/notebooks/widgets/notebook_form_sheet.dart`
- [x] Build `NotebookDetailScreen` — filtered notes grid (reuse Home grid widget)
  - File: `lib/features/notebooks/notebook_detail_screen.dart` (replace stub)
- [x] Wire assign note to notebook (from editor overflow menu → NoteOptionsSheet)
- [x] Write notebook CRUD unit test
  - File: `test/features/notebooks/notebook_test.dart`

### 1.4 Tags

- [x] Build `TagsScreen` — tag chips with tonal color
  - File: `lib/features/tags/tags_screen.dart` (replace stub)
- [x] Build tag CRUD (create, rename, delete, assign color)
  - File: `lib/features/tags/widgets/tag_form_sheet.dart`
- [x] Build `TagDetailScreen` — filtered notes grid
  - File: `lib/features/tags/tag_detail_screen.dart` (replace stub)
- [x] Wire assign note to tags (chip picker in editor overflow menu → NoteOptionsSheet)
- [x] Write tag CRUD unit test
  - File: `test/features/tags/tag_test.dart`

### 1.5 Search

- [x] Build `SearchScreen` — instant-as-you-type, local FTS via Drift
  - File: `lib/features/home/search_screen.dart` (replace stub)
- [x] Wire FTS query to `notes_fts` virtual table
- [ ] Show results grouped by note vs. checklist-item matches
- [x] Write search integration test (FTS returns correct results)
  - File: `test/features/home/search_test.dart`

### 1.6 Bottom Navigation Shell

- [x] Build `AppShell` — bottom nav bar (Home, Notebooks, Tags, Trash, Settings)
  - File: `lib/core/widgets/app_shell.dart`
- [x] Wire ShellRoute in router
- [ ] Ensure nav chrome persists for browsing, disappears for focused editing

### Phase 1 Validation

- [x] `flutter analyze` passes
- [x] `flutter test` passes
- [x] Home grid renders notes with correct tonal colors
- [x] Create text note → appears in grid → edit → autosaves
- [x] Create notebook → assign note → filter by notebook
- [x] Create tag → assign note → filter by tag
- [x] Search returns instant FTS results
- [x] Bottom nav switches between screens correctly

---

## Phase 2 — Checklists + Doodles + Images

**Goal:** Checklist note type, doodle canvas, image attach, note→image export/share.
**Duration estimate:** 3–4 weeks
**Depends on:** Phase 1 complete

### 2.1 Checklist Note Type

- [x] Build checklist-only editor path (`ChecklistEditor` — ReorderableListView + swipe actions)
  - File: `lib/features/editor/checklist_editor.dart`
- [x] Drag-to-reorder checklist items
- [ ] Swipe-to-check with strikethrough animation
- [ ] Re-skin built-in `todo_list` node in AppFlowy Editor (for mixed notes)
  - File: `lib/features/editor/widgets/custom_todo_list_block.dart`
- [ ] Register custom `todo_list` builder in `_buildComponentMap()`
- [x] Write checklist unit test (create, check, reorder, persist)
  - File: `test/features/editor/checklist/checklist_editor_test.dart`

### 2.2 Doodle Canvas

- [x] Build `DoodleController` (ChangeNotifier) — strokes, undo/redo, tool, color/width
  - File: `lib/features/doodle/doodle_controller.dart`
- [x] Build `DoodleCanvas` widget — `CustomPainter` rendering, smooth bezier strokes
  - File: `lib/features/doodle/doodle_canvas.dart`
- [x] Build `DoodleToolbar` — pen/eraser/highlighter, color swatches, width slider
  - File: `lib/features/doodle/doodle_toolbar.dart`
- [x] Build `DoodleCanvasScreen` — full-screen canvas, undo/redo, Done/close
  - File: `lib/features/doodle/doodle_canvas_screen.dart`
- [ ] Support pressure input via `Listener.onPointerDown/Move` (stylus fallback to constant)
- [ ] Background templates: blank / dotted grid / ruled lines / graph
  - File: `lib/features/doodle/background_templates.dart`
- [ ] Export: `RepaintBoundary` → `toImage()` → PNG bytes
- [ ] Optional: layer support (2–3 layers: sketch/ink/highlight)
- [x] Write doodle unit test (create strokes, undo, export)
  - File: `test/features/doodle/doodle_controller_test.dart`

### 2.3 Doodle Custom Node (AppFlowy Editor)

- [x] Build `DoodleBlockWidget` — inline thumbnail, tap to expand
  - File: `lib/features/editor/doodle/doodle_block.dart`
- [x] Build `DoodleBlockComponentBuilder` — register custom `doodle` node type
  - File: `lib/features/editor/doodle/doodle_block.dart`
- [ ] Store stroke data in Attachments table (sidecar file), node only holds attachmentId reference
- [ ] Wire thumbnail regeneration on save
- [x] Register `doodle` builder in `_buildComponentMap()`
- [x] Write doodle node integration test
  - File: `test/features/editor/doodle/doodle_block_test.dart`

### 2.4 Image Attachments

- [ ] Build image picker integration (`image_picker` package)
  - File: `lib/features/editor/widgets/image_picker_handler.dart`
- [x] Store image in Attachments table + filesystem
  - File: `lib/data/repositories/attachment_repository.dart`
- [ ] Generate thumbnail for grid preview
- [ ] Image node in AppFlowy Editor (built-in `image` block type)
- [ ] Pinch-zoom on images in editor
- [x] Write image attachment unit test
  - File: `test/data/attachment_repository_test.dart`

### 2.5 Note → Image Export

- [ ] Build `NoteRenderWidget` — dedicated export layout (not the editor widget)
  - File: `lib/features/editor/widgets/note_render_widget.dart`
- [x] `RepaintBoundary` → `toImage(pixelRatio: 3.0)` → PNG bytes
  - File: `lib/features/editor/note_exporter.dart`
- [ ] Save to gallery via `gal` package
- [ ] Share via `share_plus`
- [x] Write export test
  - File: `test/features/editor/note_exporter_test.dart`

### Phase 2 Validation

- [ ] Create checklist note → check items → swipe to check → reorder → persists
- [ ] Create doodle note → draw → save → thumbnail appears in grid
- [ ] Tap doodle thumbnail → full editor opens → edit → save → thumbnail updates
- [ ] Attach image → appears in editor → thumbnail in grid
- [ ] Export note as image → saves to gallery / shares
- [ ] Mixed note (text + checklist + doodle + image) renders correctly in AppFlowy Editor

---

## Phase 3 — Theming & Polish

**Goal:** Dynamic color integration, per-note theming, animations/transitions, empty states, dark mode pass.
**Duration estimate:** 1–2 weeks
**Depends on:** Phase 2 complete

### 3.1 Dynamic Color

- [ ] Integrate `dynamic_color` package at app root
  - File: `lib/app.dart` (update `DynamicColorBuilder`)
- [ ] Android 12+ wallpaper-based palette extraction
- [ ] Graceful fallback for older Android (manual seed)
- [ ] Toggle in settings: "Match my wallpaper" on/off

### 3.2 Per-Note Theming

- [ ] Seed color sources priority: user pick → palette from cover image → notebook color → global seed
- [ ] Derive seed from image via `palette_generator`
  - File: `lib/core/theme/note_theme_scope.dart`
- [ ] Editor chrome (toolbar, background tint) uses note's own seed
- [ ] App chrome (nav bars, FAB, settings) always uses global seed
- [ ] NoteCard in grid reflects per-note seed
- [ ] Color picker: 12–16 curated M3-friendly swatches (not raw wheel)
  - File: `lib/features/editor/widgets/theme_picker_sheet.dart`

### 3.3 Animations & Transitions

- [ ] Note card entrance animations (`flutter_animate` — `.fadeIn().scale()`)
- [ ] Checklist strikethrough animation
- [ ] FAB speed-dial open/close animation
- [ ] Page transitions (shared axis or fade-through between nav screens)
- [ ] Skeleton loading placeholders (`shimmer` package) for cold start
  - Add `shimmer` to `pubspec.yaml` if not present

### 3.4 Empty States

- [ ] Home: "No notes yet" with illustration + CTA
- [ ] Notebooks: "No notebooks" empty state
- [ ] Tags: "No tags" empty state
- [ ] Search: "No results" empty state
- [ ] Trash: "Nothing in trash" empty state
- [ ] Locked notes: "No locked notes" empty state

### 3.5 Dark Mode Pass

- [ ] Verify all screens in dark mode (ThemeData.dark)
- [ ] Check contrast ratios on NoteCard tonal backgrounds
- [ ] Verify editor readability in dark mode
- [ ] Verify doodle canvas toolbar colors in dark mode

### Phase 3 Validation

- [ ] Dynamic color changes app palette on Android 12+ device
- [ ] Per-note color changes editor chrome, not app chrome
- [ ] Animations run smoothly (60fps on low-end device)
- [ ] Empty states render correctly for every screen
- [ ] Dark mode looks correct everywhere

---

## Phase 4 — Security

**Goal:** SQLCipher encryption at rest, biometric lock (app + per-note), auto-lock, screenshot blocking.
**Duration estimate:** 1–2 weeks
**Depends on:** Phase 0 complete (DB encryption already done there)

> Note: Core DB encryption (0.4) and biometric gate (0.5) are done in Phase 0. This phase adds per-note lock, auto-lock timer, and screenshot blocking.

### 4.1 Per-Note Lock

- [ ] Lock/unlock individual notes (biometric re-prompt)
- [ ] Locked note preview: blurred/obscured content in grid
- [ ] Lock icon badge on locked notes
- [ ] Write per-note lock test
  - File: `test/features/security/per_note_lock_test.dart`

### 4.2 Auto-Lock Timer

- [ ] Configurable auto-lock timer (immediately / 1 min / 5 min / 15 min / never)
- [ ] Persist timer preference
- [ ] Lock app on resume after timer expires
- [ ] Write auto-lock test
  - File: `test/features/security/auto_lock_test.dart`

### 4.3 Screenshot Blocking

- [ ] Toggle: block screenshots/screen recording of app
- [ ] Use `FlutterWindowManager` (Android) / `UIApplication` (iOS) APIs
- [ ] Persist preference

### 4.4 Lock Screen Polish

- [ ] Nice illustration on lock screen
- [ ] Soft blur-behind effect
- [ ] "Use PIN instead" fallback option
- [ ] Fingerprint icon with pulse animation

### Phase 4 Validation

- [ ] App-level biometric lock blocks all routes until authenticated
- [ ] Per-note lock requires biometric to view/edit
- [ ] Auto-lock triggers after configured timer
- [ ] Screenshot blocking works on Android
- [ ] Lock screen looks polished (illustration, blur, animation)

---

## Phase 5 — Nearby Sync

**Goal:** Transport integration, pairing UX, send/receive flows, conflict resolution, sync log.
**Duration estimate:** 3–4 weeks (riskiest phase)
**Depends on:** Phase 1 complete (need notes to sync)

### 5.1 Transport Layer (see `.kilo/plans/sync-transport-bake-off.md`)

- [ ] Define `SyncTransport` / `SyncSession` interfaces
  - File: `lib/sync/transport/sync_transport.dart`
- [ ] Implement chosen transport (run bake-off first)
  - File: `lib/sync/transport/nearby_service_transport.dart` (or NSD, or P2P)
- [ ] Test on physical devices (Pixel + Samsung + Xiaomi)
- [ ] Write transport integration test
  - File: `test/sync/transport_test.dart`

### 5.2 Sync Protocol

- [ ] Define `SyncBundle` / `SyncNoteEntry` data classes (CBOR-encoded)
  - File: `lib/sync/protocol/sync_bundle.dart`
- [ ] Implement SHA-256 checksum verification
- [ ] Implement chunked transfer with progress callback
- [ ] Implement ack response (`{received: [noteIds], rejected: [noteIds]}`)
- [ ] Write protocol unit test (serialize, checksum, deserialize)
  - File: `test/sync/protocol_test.dart`

### 5.3 Merge Resolver

- [ ] Implement `resolveIncoming()` per detailed plan §8.4
  - File: `lib/sync/protocol/merge_resolver.dart`
- [ ] Branches: insertAsNew, ignore, overwrite, promptUser
- [ ] Write table-driven unit tests for every branch
  - File: `test/sync/merge_resolver_test.dart`

### 5.4 Sync UI

- [ ] Build `SyncScreen` — mode toggle (Send/Receive)
  - File: `lib/features/sync_ui/sync_screen.dart` (replace stub)
- [ ] Build send mode: note selection list, discovered devices list (radar animation)
  - File: `lib/features/sync_ui/sync_send_screen.dart` (replace stub)
- [ ] Build receive mode: discoverable toggle, incoming request card
  - File: `lib/features/sync_ui/sync_receive_screen.dart` (replace stub)
- [ ] Build pairing confirmation: numeric code on both devices
  - File: `lib/features/sync_ui/sync_pairing_screen.dart` (replace stub)
- [ ] Build transfer progress sheet
  - File: `lib/features/sync_ui/sync_transfer_screen.dart` (replace stub)
- [ ] Build conflict resolution card: "Keep this device / Keep incoming / Keep both"
  - File: `lib/features/sync_ui/widgets/conflict_card.dart`
- [ ] Build sync history list
  - File: `lib/features/sync_ui/sync_history_screen.dart` (replace stub)
- [ ] Write sync UI widget test (discovery, pairing, transfer progress)
  - File: `test/features/sync_ui/sync_test.dart`

### 5.5 Sync Log

- [ ] Write `SyncLog` row on every send/receive/conflict
- [ ] Display in Settings > Sync Devices and Sync History screens

### Phase 5 Validation

- [ ] Two physical Android devices discover each other
- [ ] Pairing code matches on both devices
- [ ] Send notes → receive → notes appear on receiving device
- [ ] Conflict: same note edited on both devices → promptUser card shown
- [ ] SyncLog records all actions
- [ ] CBOR payload transfers with zero data loss (SHA-256 verified)

---

## Phase 6 — Hardening for Play Store

**Goal:** Accessibility pass, tablet/foldable layout, backup/export/import, crash reporting, privacy policy, store listing.
**Duration estimate:** 2 weeks
**Depends on:** Phases 1–5 complete

### 6.1 Accessibility

- [ ] TalkBack pass: all interactive elements have semantic labels
- [ ] Contrast ratio check (WCAG AA minimum)
- [ ] Touch target size check (minimum 48x48 dp)
- [ ] Reduce motion option (respects `MediaQuery.disableAnimations`)
- [ ] Screen reader tests for key flows (create note, search, sync)

### 6.2 Tablet / Foldable Layout

- [ ] Adaptive layout: single pane (phone) vs. dual pane (tablet/foldable)
- [ ] Test on tablet emulator and foldable emulator
- [ ] Verify split-view on Samsung Fold / Pixel Fold

### 6.3 Backup / Export / Import

- [ ] Export all notes as zip (markdown + images)
  - File: `lib/features/settings/widgets/export_handler.dart`
- [ ] Import notes from zip
  - File: `lib/features/settings/widgets/import_handler.dart`
- [ ] "No lock-in" promise made real

### 6.4 Crash Reporting

- [ ] Opt-in local crash log (or Sentry self-hosted if desired)
- [ ] Privacy-first: no telemetry unless user opts in
- [ ] Crash-free rate monitoring before wide rollout

### 6.5 Play Store Readiness

- [ ] Privacy policy URL (declare local permissions honestly)
- [ ] Data safety form: "no data collected/shared"
- [ ] Target API level current requirement
- [ ] 64-bit compliance
- [ ] App Bundle (.aab) not APK
- [ ] Runtime permission rationale dialogs (nearby Wi-Fi, biometric, storage)
- [ ] Store listing assets (screenshots, feature graphic, description)

### Phase 6 Validation

- [ ] TalkBack navigates all key flows without errors
- [ ] App renders correctly on tablet and foldable
- [ ] Export all notes → zip file → import on fresh install → notes restored
- [ ] Privacy policy page accessible from app
- [ ] App builds as .aab for Play Store upload

---

## Phase 7 — Launch + Iterate

**Goal:** Closed → open testing → production. Post-launch: widget support, voice-to-text, note templates.
**Duration estimate:** Ongoing
**Depends on:** Phase 6 complete

### 7.1 Testing Track

- [ ] Upload to closed testing track
- [ ] Recruit 5–10 beta testers
- [ ] Collect feedback (in-app or GitHub Issues)
- [ ] Fix critical bugs

### 7.2 Open Testing

- [ ] Move to open testing track
- [ ] Monitor crash-free rate
- [ ] Respond to Play Store reviews

### 7.3 Production Launch

- [ ] Submit for production review
- [ ] Launch on Play Store

### 7.4 Post-Launch (v1.1+)

- [ ] Home screen widgets (`home_widget` package)
  - Quick capture widget
  - Pinned notes widget
- [ ] Voice-to-text note capture (`speech_to_text`)
- [ ] Note templates
- [ ] Flutter Web build polish (read/export-only companion)
- [ ] OCR via `google_mlkit_text_recognition` (scan handwritten text into notes)
- [ ] Local reminders via `flutter_local_notifications`
- [ ] PDF export via `printing` package

---

## Appendix A: Files Created Per Phase

### Phase 0 Files
```
.github/workflows/ci.yml
lib/core/constants.dart
lib/core/extensions.dart
lib/core/theme/design_tokens.dart
lib/core/theme/app_theme.dart
lib/core/theme/note_theme_scope.dart
lib/core/providers/database_provider.dart
lib/core/providers/repository_providers.dart
lib/core/providers/notes_provider.dart
lib/core/providers/theme_provider.dart
lib/core/providers/biometric_provider.dart
lib/core/router.dart
lib/core/widgets/app_shell.dart
lib/app.dart
lib/main.dart (replace)
lib/data/tables/notebooks.dart
lib/data/tables/notes.dart
lib/data/tables/checklist_items.dart
lib/data/tables/attachments.dart
lib/data/tables/tags.dart
lib/data/tables/note_tags.dart
lib/data/tables/sync_log.dart
lib/data/database.dart
lib/data/repositories/notebook_repository.dart
lib/data/repositories/note_repository.dart
lib/data/repositories/tag_repository.dart
lib/data/repositories/attachment_repository.dart
lib/features/home/home_screen.dart
lib/features/home/search_screen.dart
lib/features/notebooks/notebooks_screen.dart
lib/features/notebooks/notebook_detail_screen.dart
lib/features/tags/tags_screen.dart
lib/features/tags/tag_detail_screen.dart
lib/features/editor/note_editor_screen.dart
lib/features/editor/doodle_canvas_screen.dart
lib/features/trash/trash_screen.dart
lib/features/security/lock_screen.dart
lib/features/security/locked_notes_screen.dart
lib/features/sync_ui/sync_screen.dart
lib/features/sync_ui/sync_send_screen.dart
lib/features/sync_ui/sync_receive_screen.dart
lib/features/sync_ui/sync_pairing_screen.dart
lib/features/sync_ui/sync_transfer_screen.dart
lib/features/sync_ui/sync_history_screen.dart
lib/features/settings/settings_screen.dart
lib/features/settings/settings_appearance_screen.dart
lib/features/settings/settings_security_screen.dart
lib/features/settings/settings_storage_screen.dart
lib/features/settings/settings_sync_devices_screen.dart
lib/features/settings/settings_about_screen.dart
lib/features/onboarding/onboarding_screen.dart
test/data/database_test.dart
test/core/providers/database_provider_test.dart
test/core/router_test.dart
```

### Phase 1 Files
```
lib/features/home/widgets/notes_masonry_grid.dart
lib/features/home/widgets/note_card.dart
lib/features/home/widgets/speed_dial_fab.dart
lib/features/home/widgets/empty_home.dart
lib/features/editor/widgets/contextual_toolbar.dart
lib/features/editor/widgets/theme_picker_sheet.dart
lib/features/notebooks/widgets/notebook_card.dart
lib/features/notebooks/widgets/notebook_form_sheet.dart
lib/features/tags/widgets/tag_form_sheet.dart
test/features/home/note_card_test.dart
test/features/editor/note_editor_test.dart
test/features/notebooks/notebook_test.dart
test/features/tags/tag_test.dart
test/features/home/search_test.dart
```

### Phase 2 Files
```
lib/features/editor/checklist_editor.dart
lib/features/editor/widgets/custom_todo_list_block.dart
lib/features/doodle/doodle_controller.dart
lib/features/doodle/doodle_canvas.dart
lib/features/doodle/doodle_toolbar.dart
lib/features/doodle/background_templates.dart
lib/features/editor/widgets/doodle_block_widget.dart
lib/features/editor/widgets/doodle_block_component.dart
lib/features/editor/widgets/image_picker_handler.dart
lib/features/editor/widgets/note_render_widget.dart
test/features/editor/checklist_test.dart
test/features/doodle/doodle_test.dart
test/features/editor/doodle_node_test.dart
test/features/editor/image_test.dart
test/features/editor/export_test.dart
```

### Phase 3 Files
```
lib/features/home/widgets/empty_states/ (multiple)
test/features/home/empty_state_test.dart
```

### Phase 4 Files
```
test/features/security/per_note_lock_test.dart
test/features/security/auto_lock_test.dart
```

### Phase 5 Files
```
lib/sync/transport/sync_transport.dart
lib/sync/transport/nearby_service_transport.dart (or chosen transport)
lib/sync/protocol/sync_bundle.dart
lib/sync/protocol/merge_resolver.dart
lib/features/sync_ui/widgets/conflict_card.dart
test/sync/transport_test.dart
test/sync/protocol_test.dart
test/sync/merge_resolver_test.dart
test/features/sync_ui/sync_test.dart
```

### Phase 6 Files
```
lib/features/settings/widgets/export_handler.dart
lib/features/settings/widgets/import_handler.dart
```

---

## Appendix B: Dependencies Already in pubspec.yaml

All required packages are already pinned in `pubspec.yaml`:

| Package | Version | Phase |
|---------|---------|-------|
| flutter_riverpod | ^3.3.2 | 0 |
| riverpod_annotation | ^4.0.3 | 0 |
| go_router | ^17.4.0 | 0 |
| drift | ^2.22.1 | 0 |
| sqlcipher_flutter_libs | ^0.7.0+eol | 0 |
| local_auth | ^3.0.2 | 0, 4 |
| flutter_secure_storage | ^10.3.1 | 0 |
| dynamic_color | ^1.7.0 | 0, 3 |
| appflowy_editor | ^6.2.0 | 1, 2 |
| perfect_freehand | ^2.4.0 | 2 |
| image_picker | ^1.1.2 | 2 |
| gal | ^2.3.1 | 2 |
| image | ^4.3.0 | 2 |
| nearby_service | ^0.2.1 | 5 |
| crypto | ^3.0.5 | 5 |
| cbor | ^6.3.4 | 5 |
| flutter_animate | ^4.5.2 | 3 |
| share_plus | ^12.0.2 | 2 |
| flutter_staggered_animations | ^1.1.1 | 3 |
| flex_color_picker | ^3.6.0 | 1, 3 |
| uuid | ^4.5.1 | 0 |
| intl | ^0.20.3 | 0 |
| freezed_annotation | ^3.1.0 | 0 |
| json_annotation | ^4.9.0 | 0 |

---

## Appendix C: Known Risks & Decisions Needed

### Open Decisions (resolve before starting)
1. **Minimum Android API level** — biometric + dynamic color prefer API 31+ (Android 12). Decide floor now.
2. **Web build scope** — recommend deferred for v1 (nearby_service, local_auth, sqlcipher don't work on web).
3. **License** — GPL-3.0 recommended (no server component planned).

### Risk Register
| Risk | Impact | Mitigation |
|------|--------|------------|
| `nearby_service` v0.2.1 is pre-1.0, flaky on some OEM skins | High | Run bake-off on physical devices early (Phase 5.1). Fallback: NSD + raw sockets. |
| `sqlcipher_flutter_libs: ^0.7.0+eol` | Medium | Check pub.dev for successor package before Phase 0.4. |
| `freezed: ^3.2.6-dev.1` is a dev build | Low | Pin to stable release before first `build_runner build`. |
| AppFlowy Editor v6 API may differ from plan docs | Medium | Run example app before integration. Verify class names against v6 source. |
| Riverpod v3 migration (StateNotifier → Notifier) | Medium | Use `@riverpod` code-gen style from the start, not deprecated StateNotifier. |
