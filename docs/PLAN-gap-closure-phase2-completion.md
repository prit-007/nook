# Plan: Close All Gaps + Complete Phase 2

> Created: 2026-08-08
> Status: PLANNING (not executing)
> Tests: 331 passing | 0 analyzer issues | Branch: feat/phase-01

---

## Executive Summary

Audit reveals **~15 concrete gaps** across Phases 0–2. This plan organizes them into 4 work streams, ordered by priority. Each item includes: what's broken, the fix, files to touch, and how to validate.

---

## Work Stream 1: Critical Security Gaps (Phase 0 leftovers)

These are foundational issues that block Phase 4 and make the app insecure.

### 1A. Encrypted DB Bootstrap
- **Gap:** `openEncryptedDatabase()` not implemented. DB is unencrypted plaintext on disk.
- **Fix:** Add encryption key generation + SQLCipher PRAGMA setup to `database.dart`.
- **Files:** `lib/data/database.dart`
- **Details:**
  - Generate 32-byte key via `dart:math` + base64 encode
  - Store via `flutter_secure_storage` (key: `db_encryption_key`)
  - Open via `NativeDatabase.createInBackground` with `PRAGMA key` + `PRAGMA cipher_page_size = 4096`
  - Handle first-run (generate key) vs subsequent (read key)
- **Tests:** `test/data/database_test.dart` (add encryption round-trip test)
- **Depends on:** Nothing

### 1B. GoRouter Biometric Redirect
> **SUPERSEDED (2026-08-09):** not implemented as a redirect. The lock is now an
> always-mounted `FrostedShield` overlay stacked in `MaterialApp.router.builder`,
> driven by `biometricGateProvider` (see ADR 0006, `lib/features/security/frosted_shield.dart`).
> `test/core/router_test.dart` is unnecessary; coverage lives in
> `test/features/security/frosted_shield_test.dart` + `test/core/providers/biometric_provider_test.dart`.
- **Gap:** Router has no `redirect` callback. All routes accessible without biometric auth. The `biometricGateProvider` exists but is never checked.
- **Fix:** Add `redirect` to GoRouter config that checks `biometricGateProvider` and routes to `/lock` if not authenticated.
- **Files:** `lib/core/router.dart`
- **Details:**
  - Read `biometricGateProvider` state in redirect
  - If locked and path != `/lock` and path != `/onboarding`, redirect to `/lock`
  - If unlocked, allow all routes
  - Skip redirect for `/onboarding` (first run)
- **Tests:** `test/core/router_test.dart` (new file — verify redirect behavior)
- **Depends on:** 1A (needs working biometric state)

### 1C. Failure Mode Handling
- **Gap:** No handling for: no biometrics enrolled, user cancels biometric, secure storage read failure.
- **Fix:** Add error handling to `biometric_provider.dart` and `database_provider.dart`.
- **Files:** `lib/core/providers/biometric_provider.dart`, `lib/core/providers/database_provider.dart`
- **Details:**
  - `local_auth.authenticate()` returns false on cancel → show "Use PIN instead" or retry
  - `flutter_secure_storage` read failure → generate new key, re-encrypt (or fallback to unencrypted with warning)
  - No biometrics enrolled → skip biometric gate, go straight to home (with settings prompt to enable)
- **Tests:** Add to existing provider tests
- **Depends on:** 1A, 1B

### 1D. CI Pipeline
- **Gap:** `.github/workflows/ci.yml` doesn't exist. No automated format/analyze/test.
- **Fix:** Create GitHub Actions workflow.
- **Files:** `.github/workflows/ci.yml` (new file)
- **Details:**
  - Trigger on push to `main` and `feat/*` branches, and on PRs
  - Steps: `flutter pub get` → `dart format --output=none --set-exit-if-changed .` → `flutter analyze` → `flutter test`
  - Use `subosito/flutter-action@v2` with stable channel
- **Tests:** Workflow itself (validate on push)
- **Depends on:** Nothing

---

## Work Stream 2: Complete Phase 2 Remaining Items

Items that are partially done or not started within Phase 2 scope.

### 2A. Fix Router → DoodleCanvasScreen Import
- **Gap:** Router imports the stub `features/editor/doodle_canvas_screen.dart` instead of the real `features/doodle/doodle_canvas_screen.dart`.
- **Fix:** Delete the stub, update router import.
- **Files:** `lib/features/editor/doodle_canvas_screen.dart` (delete), `lib/core/router.dart` (update import)
- **Tests:** Existing `doodle_canvas_screen_test.dart` should still pass
- **Depends on:** Nothing

### 2B. Image Picker Integration
- **Gap:** `image_picker` is in pubspec but no handler exists. No way to add images to notes.
- **Fix:** Create `ImagePickerHandler` that wraps `image_picker`, saves to app Documents directory, registers in Attachments table.
- **Files:** `lib/features/editor/widgets/image_picker_handler.dart` (new)
- **Details:**
  - Wrap `ImagePicker().pickImage(source: ...)` for camera and gallery
  - Copy picked file to `getApplicationDocumentsDirectory()/attachments/`
  - Call `AttachmentRepository.addImage()` to register
  - Return attachment ID for editor embedding
- **Tests:** `test/features/editor/widgets/image_picker_handler_test.dart` (new)
- **Depends on:** Nothing

### 2C. Image Node in Editor
- **Gap:** AppFlowy Editor has built-in `image` block type but it's not registered in `note_editor_screen.dart`.
- **Fix:** Register the built-in `ImageBlockComponentBuilder` in the editor's `blockComponentBuilders`.
- **Files:** `lib/features/editor/note_editor_screen.dart`
- **Details:**
  - Import `ImageBlockComponentBuilder` from appflowy_editor
  - Add `'image': ImageBlockComponentBuilder(...)` to `blockComponentBuilders` map
  - Wire `onTap` to open image in full-screen viewer
- **Tests:** Add to existing `note_editor_test.dart`
- **Depends on:** 2B

### 2D. NoteExporter → RepaintBoundary Integration
- **Gap:** `NoteExporter` has `imageToPng()` and `saveImageToFile()` but no way to capture from the editor widget.
- **Fix:** Add a `RepaintBoundary` wrapper to `NoteEditorScreen` and wire the export button.
- **Files:** `lib/features/editor/note_editor_screen.dart`, `lib/features/editor/note_exporter.dart`
- **Details:**
  - Wrap `AppFlowyEditor` in a `RepaintBoundary` with a `GlobalKey`
  - Add "Export as Image" to the overflow menu
  - Call `boundary.toImage()` → `NoteExporter.imageToPng()` → save/share
- **Tests:** Add export integration test
- **Depends on:** Nothing

### 2E. Share via share_plus
- **Gap:** `share_plus` is in pubspec but not used. Export should offer sharing.
- **Fix:** Add share option to export flow.
- **Files:** `lib/features/editor/note_exporter.dart`
- **Details:**
  - Add `shareImage(Uint8List bytes)` method using `Share.shareXFiles()`
  - Offer "Save to gallery" (via `gal`) and "Share" in export bottom sheet
- **Tests:** Add share test
- **Depends on:** 2D

### 2F. Thumbnail Generation for Images
- **Gap:** Images stored in Attachments have no thumbnail generation. Grid can't show image previews.
- **Fix:** Use `image` package to generate thumbnails on save.
- **Files:** `lib/data/repositories/attachment_repository.dart`
- **Details:**
  - After saving original image, decode with `image` package
  - Resize to 200x200 thumbnail
  - Save thumbnail to `thumbnails/` subdirectory
  - Update `thumbnailPath` in Attachments table
- **Tests:** Add to `attachment_repository_test.dart`
- **Depends on:** 2B

### 2G. Stroke Data Persistence (Doodle → Attachments)
- **Gap:** Doodle strokes exist in memory only. Closing the doodle editor loses everything.
- **Fix:** Serialize strokes to JSON, save as doodleLayer attachment.
- **Files:** `lib/features/doodle/doodle_controller.dart`, `lib/features/doodle/doodle_canvas_screen.dart`
- **Details:**
  - Add `toJson()` / `fromJson()` to `Stroke` class
  - On "Done" tap in DoodleCanvasScreen, serialize strokes → save file → register as `doodleLayer` attachment
  - On open, load attachment file → deserialize → populate controller
- **Tests:** Add serialization tests to `doodle_controller_test.dart`
- **Depends on:** Nothing

### 2H. Background Templates for Doodles
- **Gap:** Doodle canvas has no background options (blank, dotted grid, ruled lines, graph).
- **Fix:** Create `BackgroundTemplates` widget that renders behind the strokes.
- **Files:** `lib/features/doodle/background_templates.dart` (new), `lib/features/doodle/doodle_canvas.dart`
- **Details:**
  - Enum: `blank`, `dottedGrid`, `ruledLines`, `graphPaper`
  - CustomPainter that draws the grid/lines behind strokes
  - Toolbar button to cycle templates
- **Tests:** `test/features/doodle/background_templates_test.dart` (new)
- **Depends on:** Nothing

---

## Work Stream 3: Phase 1 Leftovers

Minor items marked incomplete in Phase 1.

### 3A. Search Results Grouping
- **Gap:** Search results not grouped by note vs checklist-item matches.
- **Fix:** Add result type badges and section headers in `SearchScreen`.
- **Files:** `lib/features/home/search_screen.dart`
- **Tests:** Add to existing search tests
- **Depends on:** Nothing

### 3B. Nav Chrome Persistence
- **Gap:** Bottom nav chrome should disappear during focused editing (note editor, doodle canvas).
- **Fix:** Hide bottom nav when route is `/note/:noteId` or `/note/:noteId/doodle/:attachmentId`.
- **Files:** `lib/core/widgets/app_shell.dart`
- **Tests:** Add to `app_shell_test.dart`
- **Depends on:** Nothing

### 3C. Sync Screen Stub
- **Gap:** `sync_screen.dart` exists but is not wired to any route. Dead file.
- **Fix:** Either wire it as parent route for sync sub-screens, or delete it.
- **Files:** `lib/features/sync_ui/sync_screen.dart`, `lib/core/router.dart`
- **Depends on:** Nothing (low priority — Phase 5 territory)

---

## Work Stream 4: Checklist Maintenance

Update `IMPLEMENTATION-CHECKLIST.md` to reflect reality.

### 4A. Update Phase 0 Status
- Mark `openEncryptedDatabase()` as NOT DONE (currently unchecked — correct)
- Mark `failure mode handling` as NOT DONE (currently unchecked — correct)
- Mark `repository_providers.dart` as NOT DONE (currently unchecked — correct)
- Mark `notesListProvider` path note (exists at non-standard path)
- Mark `redirect` in router as **SUPERSEDED** by the `FrostedShield` overlay (see 1B note; `IMPLEMENTATION-CHECKLIST.md` §0.6 now tracks the overlay)
- Mark `route redirect test` as **SUPERSEDED** — replaced by `frosted_shield_test.dart` / `biometric_provider_test.dart`
- Mark CI workflow as NOT DONE (currently unchecked — correct)
- Mark `build_runner` verification as NOT DONE (currently unchecked — correct)

### 4B. Update Phase 1 Status
- Mark `search result grouping` as NOT DONE (currently unchecked — correct)
- Mark `nav chrome persistence` as NOT DONE (currently unchecked — correct)
- Update status to **COMPLETE with minor gaps**

### 4C. Update Phase 2 Status
- Change status from **NOT STARTED** to **~60% COMPLETE**
- Mark completed items:
  - [x] ChecklistEditor (ReorderableListView + swipe)
  - [x] Drag-to-reorder checklist items
  - [x] Checklist unit test
  - [x] DoodleController (strokes, undo/redo, tool/color/width)
  - [x] DoodleCanvas (CustomPainter, bezier strokes)
  - [x] DoodleToolbar (pen/eraser/highlighter, swatches, width)
  - [x] DoodleCanvasScreen (full-screen, undo/redo, Done)
  - [x] Doodle unit test
  - [x] DoodleBlockWidget + DoodleBlockComponentBuilder
  - [x] Doodle node integration test
  - [x] AttachmentRepository (CRUD, reorder, thumbnails)
  - [x] Image attachment unit test
  - [x] NoteExporter (imageToPng, saveToFile, generateFileName)
  - [x] Export test
- Mark remaining items as TODO:
  - [ ] Pressure input via Listener
  - [ ] Background templates
  - [ ] Layer support
  - [ ] Image picker integration
  - [ ] Image node in editor
  - [ ] Pinch-zoom on images
  - [ ] NoteRenderWidget (dedicated export layout)
  - [ ] Save to gallery via gal
  - [ ] Share via share_plus
  - [ ] Stroke data persistence (toJson/fromJson)
  - [ ] Thumbnail generation

### 4D. Update Appendix A (Files Created Per Phase)
- Move doodle/, checklist_editor.dart, attachment_repository.dart, note_exporter.dart from Phase 2 appendix into "Already Created" section
- Note actual file paths vs planned paths

### 4E. Update Status Overview Table
```
| Phase | Status |
|-------|--------|
| 0 | ~85% COMPLETE (missing: encrypted DB, redirect, CI, failure modes) |
| 1 | ~95% COMPLETE (missing: search grouping, nav persistence) |
| 2 | ~60% COMPLETE (engine done, integration & polish remaining) |
| 3 | NOT STARTED |
| 4 | NOT STARTED |
| 5 | NOT STARTED |
| 6 | NOT STARTED |
| 7 | NOT STARTED |
```

---

## Execution Order

```
Work Stream 4 (Checklist)     ← Do first, no code changes
Work Stream 1 (Security)      ← Do second, foundational
  1D (CI)                     ← Independent, can run in parallel
  1A (Encrypted DB)           ← Core foundation
  1B (Router redirect)        ← Depends on 1A
  1C (Failure modes)          ← Depends on 1A, 1B
Work Stream 2 (Phase 2)       ← Do third
  2A (Fix doodle import)      ← Quick win
  2G (Stroke persistence)     ← Core doodle feature
  2H (Background templates)   ← Polish
  2B (Image picker)           ← New feature
  2C (Image node in editor)   ← Depends on 2B
  2F (Thumbnail generation)   ← Depends on 2B
  2D (RepaintBoundary export) ← Depends on nothing
  2E (Share via share_plus)   ← Depends on 2D
Work Stream 3 (Phase 1)       ← Do last, low priority
  3A (Search grouping)
  3B (Nav persistence)
  3C (Sync screen — defer to Phase 5)
```

---

## Risk Notes

1. **Encrypted DB migration:** If the app has already been used with an unencrypted DB, we need a migration strategy (read unencrypted → encrypt → delete old). For pre-alpha this is acceptable — just delete app data.
2. **Image picker permissions:** Camera requires `CAMERA` permission on Android. Need to add to `AndroidManifest.xml` and request at runtime.
3. **`gal` package:** For saving to gallery on iOS, need `NSPhotoLibraryAddUsageDescription` in `Info.plist`.
4. **RepaintBoundary sizing:** The editor widget may be taller than the screen. Need to capture full scrollable content, not just visible viewport. May need a separate render widget for export.
