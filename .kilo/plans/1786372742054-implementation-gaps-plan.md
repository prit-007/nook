# Nook Implementation Gap Analysis

Cross-checked against: `notes-app-detailed-plan.md`, `notes-app-masterplan.md`, `notes-app-plan-v2-updates.md`, `notes-app-part3-editor-routes-libraries.md`, `PLAN-gap-closure-phase2-completion.md`, `docs/adr/0006-frosted-shield-lock-overlay.md`

---

## Foundation: What the docs specify vs. what exists

### Deliberate design decisions (NOT gaps)
- **FrostedShield overlay** replaces redirect-based router lock (ADR 0006). The always-mounted overlay in `MaterialApp.router.builder` is the accepted pattern — do not add a redirect callback.
- **AppFlowy Editor v6** is the chosen editor (not flutter_quill). The node-tree document model is correct. Custom `doodle` and re-skinned `todo_list` block types are the right approach.
- **Per-note theming scope**: app chrome always uses global seed; only editor chrome uses per-note seed. `NoteThemeScope` exists for this purpose.

---

## Phase 0 — Foundation (Gaps)

### 0.4 Encrypted DB Bootstrap — NOT IMPLEMENTED
- `lib/data/database.dart`: only `createTestDatabase()` (in-memory). No `openEncryptedDatabase()`.
- `lib/core/providers/database_provider.dart`: still uses `NativeDatabase.memory()` with a placeholder comment.
- **Docs spec** (`notes-app-detailed-plan.md §3`): generate 32-byte key via `dart:math` + base64, store in `flutter_secure_storage` (`db_encryption_key`), open via `NativeDatabase.createInBackground` with `PRAGMA key` + `PRAGMA cipher_page_size = 4096`.
- **⚠️ Version risk** (`notes-app-plan-v2-updates.md §3`): `sqlite3_flutter_libs: ^0.6.0+eol` and `sqlcipher_flutter_libs: ^0.7.0+eol` both have `+eol` markers. Before writing encryption code, verify whether a successor package exists. The PRAGMA calls themselves are standard SQLCipher and will still work.
- **Missing:** failure mode handling (no biometric enrolled, biometric cancelled, secure storage read failure).
- **Migration concern** (`PLAN-gap-closure-phase2-completion.md`): pre-alpha app with no users — unencrypted→encrypted migration can be a simple data wipe for now.

### 0.5 Missing Provider Files
- `lib/core/providers/repository_providers.dart` — **does not exist**. Repositories are instantiated ad-hoc in screens (`NoteRepository(_db!)` in `note_editor_screen.dart`). This bypasses Riverpod's scoping.
- `lib/core/providers/notes_provider.dart` — **does not exist**. `notesListProvider` lives in `lib/features/home/providers/notes_list_provider.dart` (non-standard path per checklist).
- **⚠️ Riverpod v3 pattern** (`notes-app-plan-v2-updates.md §2`): `flutter_riverpod: ^3.3.2` + `riverpod_annotation: ^4.0.3` are installed. `ChangeNotifierProvider` (used for `biometricGateProvider`) still works via legacy export but `StateNotifier` is deprecated. New providers should use `@riverpod` codegen `Notifier` pattern. Audit existing providers before adding new ones.

### 0.1 CI — MISSING
- `.github/workflows/ci.yml` — **does not exist**.

### 0.2 Missing core files
- `lib/core/constants.dart` — **does not exist**
- `lib/core/extensions.dart` — **does not exist**

---

## Phase 1 — Core Notes (Gaps)

### 1.5 Search — Grouping NOT Implemented
- **Docs spec** (`notes-app-masterplan.md §5.5`): "results grouped by note vs. checklist-item matches."
- Actual: `search_screen.dart` returns flat `List<Note>` from `SearchRepository.searchNotes()`. The repository only queries `notes_fts` against note title/plainText. No grouping, no match-type metadata.

### 1.6 Bottom Nav Chrome — Does NOT Disappear for Editing
- **Docs spec** (`notes-app-detailed-plan.md §4` / `PLAN-gap-closure-phase2-completion.md §3B`): nav chrome should disappear during focused editing.
- Actual: `AppShell` always shows bottom nav. No route-based visibility logic.

---

## Phase 2 — Checklists + Doodles + Images (Gaps)

### 2.3 Doodle Block — Architectural Mismatch (Sidecar NOT Wired)

**This is the most significant Phase 2 gap.** The docs (`notes-app-part3-editor-routes-libraries.md §1`) specify a precise data shape for the doodle node that the current implementation does not follow:

**Spec'd node attributes:**
```json
{
  "type": "doodle",
  "attributes": {
    "attachmentId": "a1b2c3",
    "thumbnailPath": "a1b2c3_thumb.png",   // filesystem path, NOT inline base64
    "aspectRatio": 1.4,
    "backgroundTemplate": "dotted"
  }
}
```

**Actual node attributes** (`doodle_block.dart`):
```dart
static const String attachmentId = 'attachment_id';
static const String thumbnailData = 'thumbnail_data'; // inline base64 — WRONG
```
- Missing attributes: `thumbnailPath`, `aspectRatio`, `backgroundTemplate`
- The node stores `thumbnailData` as inline base64 — this violates the sidecar architecture where the document tree holds only a reference, not binary data.

**`DoodleBlockWidget` is missing `editorState`** — Part 3 §1.2 shows the widget receiving `editorState` so it can write thumbnail updates back via a Transaction. The current `DoodleBlockComponentWidget` has no `editorState` field and no transaction-based save-back.

**Stroke data persistence:** `doodle_strokes_codec.dart` provides encode/decode, but `doodle_canvas_screen.dart` (the real one in `features/doodle/`) does not call `AttachmentRepository.addDoodle()` on save. Strokes are lost when the screen closes.

**Thumbnail regeneration:** `doodle_thumbnail_renderer.dart` exists but is not wired into any save flow.

### 2.4 Image Attachments — Mostly NOT Implemented
- `lib/features/editor/widgets/image_picker_handler.dart` — **does not exist**
- `lib/features/editor/widgets/note_render_widget.dart` — **does not exist**
- Image node in AppFlowy Editor — **not registered** in `_buildComponentMap()` (no `ImageBlockComponentBuilder`)
- Pinch-zoom on images — **not implemented**
- Thumbnail generation for grid preview — **not implemented**
- Image picker integration — `image_picker` in pubspec, no handler code

### 2.5 Note → Image Export — Partially Implemented
- `NoteExporter` has `imageToPng()`, `captureBoundaryToPng()`, `saveImageToFile()`, `generateFileName()` — good foundation.
- **Missing:** `gal` save-to-gallery wiring, `share_plus` share flow, `RepaintBoundary` integration in `NoteEditorScreen`.

### 2.1/2.2 Doodle Canvas — Background Templates NOT Wired to UI
- `DoodleBackground` enum exists in `doodle_controller.dart` (blank, dotted, ruled, graph).
- `doodle_painter.dart` renders the background.
- **Missing:** UI selector in `doodle_canvas_screen.dart` to cycle templates. The enum and painter exist but the toolbar has no button for background selection.

### Duplicate doodle_canvas_screen.dart
- `lib/features/editor/doodle_canvas_screen.dart` — **26-line STUB** ("Doodle Canvas (Phase 2)")
- `lib/features/doodle/doodle_canvas_screen.dart` — **real implementation**
- The router (`lib/core/router.dart`) imports from `features/editor/doodle_canvas_screen.dart` — the **stub**, not the real one. This is a broken route.

---

## Phase 3 — Theming & Polish (Gaps — Not Started)

### 3.1 Dynamic Color — Toggle is Dead
- `DynamicColorBuilder` exists in `app.dart` and works.
- Settings screen shows a dynamic color toggle but `onChanged: (_) {}` — no persistence, no effect.

### 3.2 Per-Note Theming — Not Wired to Editor
- `note_theme_scope.dart` exists.
- Editor chrome (toolbar, background tint) does not consume `NoteThemeScope`. No live-restyle on color change.

### 3.3 Animations — Partially Implemented
- Card entrance animations (`flutter_animate`) — implemented.
- Hero shared-element transitions — implemented.
- **Missing:** FAB speed-dial animation (morphing FAB exists but no speed-dial), page transitions, `shimmer` package not in pubspec.

### 3.4 Empty States — Mostly Missing
- `empty_home.dart` exists for Home.
- Notebooks, Tags, Search, Trash, Locked notes — **no empty state widgets**.

### 3.5 Dark Mode Pass — NOT Started
- No verification pass, contrast checks, or adjustments.

---

## Phase 4 — Security (Gaps — Not Started)

### 4.1 Per-Note Lock — NOT Implemented
- Lock/unlock individual notes with biometric re-prompt
- Blurred/obscured content in grid for locked notes
- Lock icon badge
- No test files

### 4.2 Auto-Lock Timer — NOT Implemented
- Configurable timer, persist preference, lock on resume
- Settings screen shows "1 minute" as a static value, not wired to anything

### 4.3 Screenshot Blocking — NOT Implemented
- Toggle shows `onChanged: (_) {}` — dead switch
- No `FlutterWindowManager` / platform channel implementation

---

## Phase 5 — Nearby Sync (Gaps — Not Started)

### 5.1-5.3 — Entire sync stack MISSING
- `lib/sync/` directory — **does not exist**
- `SyncTransport`, `SyncSession`, `SyncBundle`, `SyncNoteEntry`, `MergeResolver` — none implemented

### 5.4 Sync UI — Stubs Only
- `sync_screen.dart` is a dead stub not wired to any route
- `sync_send/receive/pairing/transfer/history_screen.dart` — all stubs/minimal

### 5.5 SyncLog — NOT Implemented
- `sync_log.dart` table exists in schema
- No code writes to it

### ⚠️ Critical dependency risk
- `nearby_service: ^0.2.1` is pre-1.0 (per `notes-app-plan-v2-updates.md §5`). This is the riskiest architectural piece. Read GitHub issues for Android 13/14/OEM flakiness before Phase 5 starts. Have a fallback plan.

---

## Phase 6 & 7 — Not Started (as expected)

---

## Prioritized Execution Plan

### P0 — Blocking: App cannot be secured or tested in CI
| # | Task | Files | Validation |
|---|------|-------|------------|
| 1 | Implement `openEncryptedDatabase()` | `lib/data/database.dart`, `lib/core/providers/database_provider.dart` | `test/data/database_test.dart` adds encryption round-trip |
| 2 | Verify `sqlcipher_flutter_libs` successor / confirm `+eol` status | `pubspec.yaml` | `flutter pub get` resolves cleanly |
| 3 | Create `.github/workflows/ci.yml` | `.github/workflows/ci.yml` | Push triggers format→analyze→test |
| 4 | Create `lib/core/providers/repository_providers.dart` | new file | All repos available as Riverpod providers |
| 5 | Create `lib/core/constants.dart` + `lib/core/extensions.dart` | new files | Import clean, no lint warnings |

### P0.5 — Editor Completeness: Title + All Content Types
**User requirement:** "All doodles, notes, images should be displayed, added, attached in the notes (editor) with some title too."

**Current state of `NoteEditorScreen`:**
- Text/paragraphs: displayed ✓, addable (typing) ✓
- Checklist items: displayed via custom `NookTodoListBlock` ✓, addable via slash menu ✓, format bar button is no-op
- Doodle blocks: displayed via custom `DoodleBlockComponentWidget` ✓, editable (tap opens `DoodleCanvasScreen`) ✓, **NOT insertable from within editor**
- Images: displayed via `NookImageBlockComponentBuilder` (zoomable) ✓, addable via app bar icon ✓
- Title: **NO dedicated field** — title is derived from first document line, app bar shows date instead of title

| # | Task | Files | Validation |
|---|------|-------|------------|
| 6 | Add title TextField to NoteEditorScreen | `lib/features/editor/note_editor_screen.dart` | Title input visible at top, persists to DB on change |
| 7 | Wire format bar checklist button | `lib/features/editor/note_editor_screen.dart` | Inserts `todo_list` node at cursor |
| 8 | Wire format bar bullet list button | `lib/features/editor/note_editor_screen.dart` | Inserts `bulleted_list` node at cursor |
| 9 | Add doodle insertion from editor | `lib/features/editor/note_editor_screen.dart`, `lib/features/editor/doodle/doodle_block.dart` | New doodle block insertable via slash menu or app bar button |
| 10 | Verify `ImagePickerHandler` end-to-end | `lib/features/editor/widgets/image_picker_handler.dart` | Image picked → stored → thumbnail generated → node inserted |

### P1 — Core functionality gaps
| # | Task | Files | Validation |
|---|------|-------|------------|
| 11 | Delete stub `lib/features/editor/doodle_canvas_screen.dart`, update router import | `lib/core/router.dart` | Route opens real canvas screen |
| 12 | Add background template selector to doodle toolbar | `lib/features/doodle/doodle_toolbar.dart`, `lib/features/doodle/doodle_canvas_screen.dart` | 4 templates selectable in UI |
| 13 | Implement search result grouping | `lib/features/home/search_screen.dart` | Results show note-matches and checklist-item-matches as sections |
| 14 | Implement nav chrome hide on editor routes | `lib/core/widgets/app_shell.dart` | Bottom nav absent on `/note/:noteId` and `/note/:noteId/doodle/:attachmentId` |

### P2 — Theming & Polish
| # | Task | Files |
|---|------|-------|
| 15 | Wire dynamic color toggle to persisted preference | `lib/core/providers/theme_provider.dart`, `lib/features/settings/settings_appearance_screen.dart` |
| 16 | Wire per-note `NoteThemeScope` to editor chrome | `lib/features/editor/note_editor_screen.dart` |
| 17 | Add `shimmer` to pubspec, build skeleton loaders | `pubspec.yaml`, `lib/features/home/widgets/` |
| 18 | Build empty state widgets (Notebooks, Tags, Search, Trash, Locked) | new widget files per screen |
| 19 | Implement page transitions | `lib/core/router.dart` |
| 20 | Dark mode pass | all screens |

### P3 — Security
| # | Task | Files |
|---|------|-------|
| 21 | Implement per-note lock (biometric re-prompt, blur, badge) | `lib/features/security/`, `lib/data/repositories/note_repository.dart` |
| 22 | Implement auto-lock timer | `lib/core/providers/biometric_provider.dart`, settings screens |
| 23 | Implement screenshot blocking | platform channel, settings toggle |

### P4 — Sync (Phase 5, high risk)
| # | Task | Files |
|---|------|-------|
| 24 | Run `nearby_service` bake-off on physical devices first | — |
| 25 | Implement `lib/sync/` transport interface + protocol + merge resolver | `lib/sync/` |
| 26 | Implement SyncLog writes | `lib/data/repositories/` |
| 27 | Build sync UI (send/receive/pairing/transfer/conflict) | `lib/features/sync_ui/` |

---

## Key Architectural Concerns

1. **`+eol` SQLite/SQLCipher packages** — need successor investigation before encrypted DB implementation. Do not write `openEncryptedDatabase()` until this is resolved.

2. **Riverpod v3 codegen vs. legacy** — existing `ChangeNotifierProvider` for `biometricGateProvider` compiles but is legacy. New providers should use `@riverpod` annotation style to avoid rewriting later.

3. **`nearby_service: ^0.2.1`** — pre-1.0, known flaky on OEM skins. Must prototype on physical devices before committing architecture to it. Have a fallback plan.

4. **Editor completeness** — the editor infrastructure (AppFlowy Editor, custom blocks, image handler) is mostly in place, but lacks a dedicated title field and has two no-op format bar buttons. These are small UI changes but affect the core user experience significantly.
