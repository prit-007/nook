# Nook — Full Implementation Checklist

> **How to use:** Check off tasks as you complete them. Each task lists the files to create/modify and the validation command to run. Move the `[ ]` → `[x]` when done. Update the status table at the top of each phase when a phase is fully complete.
>
> **Project state:** v0.9.7+19, single-package Flutter app (Dart >=3.6.0, Flutter 3.44.8).
> **CI gates:** `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` → `dart format --output=none --set-exit-if-changed .` → `flutter analyze` → `flutter test --coverage -x network`

---

## TDD Methodology (mandatory for every task)

**Every task follows the red-green-refactor loop. No implementation code is written before its failing test.**

### The loop for each task

1. **Red — Write the failing test first.** Create or edit the test file. The test must define the expected behavior, fail to compile or fail at runtime, and clearly describe what "done" looks like.
   - If the task modifies existing behavior, first write a test that captures the current (broken) behavior, then write the test for the new (correct) behavior.
   - For UI/widget tasks: use ASCII layout snapshots (`test/helpers/ascii_layout.dart`) for visual checks, `expectLayoutSnap()` for baseline snapshots, and `flutter_test` for interaction assertions.
   - For data layer tasks: use in-memory Drift `NativeDatabase.memory()`.
   - For sync layer tasks: use loopback UDX hosts (`test/sync/libp2p_test_host.dart`).
2. **Green — Write the minimum implementation code to make the test pass.** No gold-plating, no speculative features. Just enough to satisfy the test.
3. **Refactor — Clean up while keeping tests green.** Run `dart format`, `flutter analyze`, and the full test suite (`flutter test --coverage -x network`).
4. **Commit.** Small PR per task, own git worktree and branch.

### Rules

- **Test file first, implementation file second.** If a task says "create `X.dart`", the corresponding `X_test.dart` (or placement in an existing test file) is created/edited first.
- **No task is complete until its test passes.** A `[x]` checkbox means the test was written, failed, then passed after implementation.
- **Regenerated goldens:** Only the QA lane regenerates goldens. Other lanes must not commit `*.g.dart` conflicts — rebuild after merge.
- **Schema migrations:** DATA lane allocates migration numbers centrally; other lanes request changes through DATA.

---

## Status Overview

| Phase | Description | Status | Started | Completed |
|-------|-------------|--------|---------|-----------|
| 0 | Truth and baseline | COMPLETE | 2026-11-27 | 2026-11-27 |
| 1 | Security hardening | COMPLETE | 2026-11-27 | 2026-11-27 |
| 2 | Sync correctness | IN_PROGRESS | 2026-11-27 | — |
| 3 | UX consolidation | COMPLETE | 2026-11-27 | 2026-11-27 |
| 4 | Portability and backup | COMPLETE | 2026-11-27 | 2026-11-27 |
| 5 | Offline capture and search | NOT STARTED | — | — |
| 6 | Editor depth | NOT STARTED | — | — |
| 7 | Distribution | NOT STARTED | — | — |
| 8 | Beta readiness | NOT STARTED | — | — |

---

## Phase 0 — Truth and baseline (~1 week, mostly serial)

**Goal:** Reconcile the report with the actual codebase, fix contradictions, establish interface contracts and fakes that other lanes build against.

**Depends on:** Nothing (start here first).

### 0.0 Report-to-code reconciliation

- [x] Fix contradiction: `schemaVersion` — report §6 says 11, §8 says 7. Actual value is **11** (`lib/data/database.dart:48`). Confirm correct value and update all references.
  - Files: `docs/NOOK_DESIGN_SYSTEM_UI_UX_REPORT.md`, `docs/IMPLEMENTATION-CHECKLIST.md`, `lib/data/database.dart`, `test/data/database_test.dart`
  - Validation: `grep -rn "schemaVersion" lib/data/database.dart` → must show `11`
- [x] Fix contradiction: dock items — report says Home/Notebooks/Tags/Settings; earlier draft said Sync. Actual is Home/Notebooks/Tags/Settings (`lib/core/widgets/app_shell.dart`).
  - Files: `docs/NOOK_DESIGN_SYSTEM_UI_UX_REPORT.md`
  - Validation: Confirm dock lists Home/Notebooks/Tags/Settings (no Sync)
- [x] Fix contradiction: onboarding page count — report says "4 pages" but lists 5. Actual onboarding PageView has 5 pages (`lib/features/onboarding/onboarding_screen.dart`).
  - Files: `docs/NOOK_DESIGN_SYSTEM_UI_UX_REPORT.md`
  - Validation: Confirm onboarding PageView has exactly 5 pages
- [x] Fix contradiction: editor line count — report says 1,215 here and 2,593 earlier. Actual is **1,215** (`lib/features/editor/note_editor_screen.dart`).
  - Files: `docs/NOOK_DESIGN_SYSTEM_UI_UX_REPORT.md`
- [x] Fix contradiction: doodle canvas line count — report says 860 here and 879 earlier. Actual is **879** (`lib/features/doodle/doodle_canvas_screen.dart`).
  - Files: `docs/NOOK_DESIGN_SYSTEM_UI_UX_REPORT.md`
- [x] Fix F-Droid flag typo: §6.6 says `NOOK_FDROID`, §12.3 says `NOOCK_FDROID`. Actual code uses `NOOK_FDROID` (`lib/core/providers/voice_preference_provider.dart:7`).
  - Files: `docs/NOOK_DESIGN_SYSTEM_UI_UX_REPORT.md`
- [x] Fix contradiction: design rules broken by tokens — `kFontFloor` is 12 but "YOUR VAULT" is 9px and dock labels are 11px.
  - Files: `lib/features/home/home_screen.dart`, `lib/core/widgets/app_shell.dart`, `lib/core/theme/nook_tokens.dart`
  - Decision: either raise "YOUR VAULT" and dock labels to 12+px or lower `kFontFloor`. Pick one and update both code and rule.

### 0.1 F-Droid flag test

- [x] Add a test asserting a build with `--dart-define=NOOK_FDROID=true` must not have `RECORD_AUDIO` in the merged manifest.
  - File: `test/core/platform/fdroid_manifest_test.dart` (NEW)
  - Validation: `flutter test test/core/platform/fdroid_manifest_test.dart` → passes
  - Check: `android/app/src/main/AndroidManifest.xml` must not contain `RECORD_AUDIO` when flag is set

### 0.2 ADRs and threat model

- [x] Write ADR for trust/security decisions (recovery key, KDF choice, locked-note protection).
  - File: `docs/adr/0012-trust-and-security.md` (NEW)
- [x] Write comprehensive threat model: "What Nook protects, and what it doesn't".
  - File: `docs/THREAT-MODEL.md` (NEW)
  - Must cover: device theft, keystore binding, locked-note leaks (FTS, previews, thumbnails, widgets, reminders, revisions, export, sync), recovery key storage, clipboard hygiene

### 0.3 CI gates

- [x] Add coverage floor gate to CI (65% baseline floor enforced; raise to 80% as Phases 1-6 add coverage).
  - File: `.github/workflows/ci.yml`
- [x] Add `golden` tag split to CI (golden tests run separately).
  - File: `.github/workflows/ci.yml`
- [x] Add licence audit of dependencies to CI (no proprietary/tracking libraries).
  - File: `.github/workflows/ci.yml`, `tool/licence_audit.dart` (NEW)

### 0.4 Interface contracts and fakes (for parallel lanes)

- [x] Define and export `SyncTransport` interface.
  - File: `lib/sync/transport/sync_transport.dart` (verify current state)
- [x] Define fake `SyncTransport` for tests.
  - File: `test/sync/fakes/fake_sync_transport.dart` (NEW)
- [x] Define `NotebookRepository` interface contract (parentId, maxCollectionDepth).
  - File: `lib/data/repositories/notebook_repository.dart` (verify current state)
- [x] Define `DekManager` interface contract (wrap/unwrap/rotate/disable/restore).
  - File: `lib/core/security/dek_manager.dart` (verify current state)
- [x] Define `VoiceCaptureService` interface contract.
  - File: `lib/core/platform/voice_capture_service.dart` (verify current state)

### 0.5 Design system rule fix

- [x] Reconcile `kFontFloor` (12) vs "YOUR VAULT" (9px) and dock labels (11px).
  - Files: `lib/features/home/home_screen.dart`, `lib/core/widgets/app_shell.dart`, `lib/core/theme/nook_tokens.dart`
  - Action: Raise text to >=12px OR lower `kFontFloor`. Update `nook_tokens.dart` and all usages.
  - Validation: `design_system_enforcement_test.dart` must fail on any text < 12px if `kFontFloor` stays at 12

---

## Phase 1 — Security hardening (starts after Phase 0)

**Goal:** Make privacy claims true in every corner. Locked notes must not leak through any surface.

**Depends on:** Phase 0 complete.

### 1.1 KDF migration (PBKDF2 → Argon2id)

- [x] Research current OWASP guidance for PBKDF2-HMAC-SHA256 iterations **(verify)** — Argon2id OWASP interactive profile (`m=19456, t=2, p=1`) adopted as primary v2 KDF with PBKDF2-HMAC-SHA256 legacy fallback.
- [x] Add versioned KDF format: `v2$argon2id$...` with migration path.
  - File: `lib/core/security/kdf.dart` (modify)
  - File: `lib/core/security/dek_manager.dart` (modify: `wrapDekWithPassword`, `unwrapDekWithPassword`)
- [x] Add migration test: old-to-new format, wrong password, kill mid-migration.
  - File: `test/core/security/kdf_migration_test.dart` (NEW)
  - Validation: `flutter test test/core/security/kdf_migration_test.dart` → passes
- [x] Test: failed unwrap never corrupts stored DEK.
  - File: `test/core/security/dek_manager_test.dart` (already exists — verify)

### 1.2 Locked-note leak sweep

- [x] Write one failing test per surface where locked notes might leak:
  1. FTS search index (`notes_fts`)
  2. Card previews (NoteCard, NoteBannerCard, NoteDoodleCard)
  3. Doodle thumbnails
  4. Home-screen widget (`syncPinnedNotes`)
  5. Reminder notification text
  6. Revision history (`note_revisions`)
  7. Bulk export (Markdown/HTML/PDF)
  8. Sync bundle payload
  9. Search results screen
- [x] Fix each leak: exclude locked notes from all surfaces above.
  - Files: `lib/data/repositories/note_repository.dart`, `lib/data/repositories/search_repository.dart`, `lib/core/platform/home_widget_service.dart`, `lib/features/home/widgets/note_banner_card.dart`, `lib/features/home/widgets/note_doodle_card.dart`, `lib/features/settings/widgets/bulk_export.dart`, `lib/sync/pipeline/sync_bundle_packer.dart`, `lib/data/repositories/reminder_repository.dart`, `lib/data/repositories/revision_repository.dart`
- [x] Validation: `flutter test` → 0 failed; every leak test passes after fix (`test/core/security/locked_note_leak_sweep_test.dart`)

### 1.3 Biometric-bound keystore key

- [x] Confirm keystore key is bound to authentication (not UI-only gate).
  - Files: `lib/features/security/vault_db_gate_screen.dart`, `lib/core/security/secure_kv_store.dart`, `lib/data/database.dart`
- [x] Test: app cannot decrypt DB without biometric/vault unlock even if UI is bypassed.
  - File: `test/features/security/vault_db_gate_test.dart`, `test/core/security/secure_kv_store_test.dart`

### 1.4 Secure delete

- [x] Enable `secure_delete` pragma on SQLCipher DB.
  - File: `lib/data/database.dart`
- [x] Vacuum after trash purge (30-day auto-purge).
  - File: `lib/data/repositories/trash_auto_purger.dart`
- [x] Keep sensitive notification text off lock screen (reminders).
  - File: `lib/core/platform/local_reminder_scheduler.dart`
- [x] Test: secure_delete pragma active, vacuum runs after purge.
  - File: `test/core/security/secure_delete_test.dart` (NEW)

### 1.5 App-wide FLAG_SECURE toggle + clipboard hygiene

- [x] App-wide `FLAG_SECURE` toggle (already per-dialog; extend to whole app).
  - Files: `lib/core/providers/screenshot_blocker_provider.dart`, `lib/app.dart`
- [x] Auto-lock on background (app lifecycle).
  - Files: `lib/core/providers/biometric_provider.dart`, `lib/app.dart`
- [x] Clipboard hygiene: clear clipboard after copy operations (recovery key, notes, passwords).
  - Files: `lib/features/security/recovery_key_dialog.dart`, `lib/core/security/clipboard_hygiene.dart`
- [x] Test: FLAG_SECURE applied globally; clipboard cleared after 60s.
  - File: `test/core/security/clipboard_hygiene_test.dart` (NEW)

---

## Phase 2 — Sync correctness (parallel with Phase 1)

**Goal:** Make sync boringly reliable. No data loss, deterministic merge, property-based convergence.

**Depends on:** Phase 0 complete.

### 2.1 Protocol version and capability negotiation

- [x] Add protocol version field to sync envelope (`SyncMessage`).
  - File: `lib/sync/protocol/sync_message.dart`
- [x] Add capability negotiation: peers detect schema version mismatch and refuse or degrade.
  - File: `lib/sync/sync_orchestrator.dart` (verify), `lib/sync/protocol/merge_resolver.dart`
- [x] Test: mismatched schema versions → sync refused or degraded cleanly.
  - File: `test/sync/protocol_version_test.dart` (NEW)

### 2.2 Smarter merge using NoteRevisions (block-level 3-way merge)

- [x] Use `NoteRevisions` last common revision as base for 3-way merge on AppFlowy node tree.
  - File: `lib/sync/protocol/merge_resolver.dart`
  - File: `lib/data/repositories/revision_repository.dart`
- [x] Prompt only on true conflicts (not on same-lineage newer).
  - File: `lib/sync/protocol/merge_resolver.dart`
- [x] Test: same-lineage newer → auto-accept; true conflict → promptUser card.
  - File: `test/sync/merge_resolver_test.dart` (already exists — add cases)

### 2.3 CRDT spike (do not migrate yet)

- [ ] Try `crdt_lf` (Fugue algorithm, MIT) behind feature flag.
  - File: `pubspec.yaml` (add dependency)
- [ ] Try `dart_crdt` (Yjs-style, pre-1.0) behind feature flag.
  - File: `pubspec.yaml` (add dependency)
- [ ] Decision: do not migrate document model yet; keep spike isolated.
  - Validation: CRDT code behind feature flag, not imported by main sync path

### 2.4 Property-based convergence tests

- [x] Simulate N peers applying random operations in random order; assert convergence.
  - File: `test/sync/convergence_test.dart` (NEW)
  - Library: `glados` may help **(verify)** — check licence and API stability

### 2.5 Attachments and tombstones

- [x] Chunk and resume large transfers (attachments, doodles).
  - File: `lib/sync/pipeline/sync_bundle_packer.dart`
  - File: `lib/sync/transport/libp2p_sync_transport.dart` (verify exists)
- [x] Test: deletes propagate (tombstones).
  - File: `test/sync/tombstone_test.dart` (NEW)

### 2.6 Open items — physical device validation

- [ ] Fix AutoNAT stray dials (transport forces `Reachability.private` but ambient probing dials may leak).
  - File: `lib/sync/transport/libp2p_sync_transport.dart` (verify exists)
- [ ] Real-device mDNS and Wi-Fi Direct matrix on at least 3 Android vendors (Pixel, Samsung, Xiaomi).
- [ ] 24h soak test nightly.
  - File: `test/sync/soak_test.dart` (NEW, tagged `network`)

---

## Phase 3 — UX consolidation

**Goal:** Polish the UX. Remove duplication, decide Sync placement, add mobile drill-down.

**Depends on:** Phase 0 complete.

### 3.1 Merge duplicated page transitions

- [x] Consolidate `buildEditorialTransition`, `EditorialPageRoute`, `_fadeTransition` in `router.dart` into single source.
  - File: `lib/core/router.dart`
  - File: `lib/core/widgets/editorial_page_transition.dart` (verify exists)
- [x] Validation: `flutter analyze` → 0 issues; all route tests pass

### 3.2 Decide Sync placement

- [x] Decide: Sync as dock tab vs. status pill plus Settings. Write down why.
  - File: `docs/SYNC-PLACEMENT-DECISION.md` (NEW)
  - Files to modify: `lib/core/widgets/app_shell.dart`, `lib/features/home/home_screen.dart`

### 3.3 Mobile drill-down for nested collections

- [x] MobileCollectionDrillDown: breadcrumb navigation bar (‹ Parent / Current) with subcollection count chips.
  - File: `lib/features/notebooks/widgets/mobile_collection_drill_down.dart` (verify exists)
  - File: `lib/features/notebooks/notebooks_screen.dart` (wire into mobile view)
- [x] Test: 3-level hierarchy creation, note placement, child promotion, note preservation.
  - File: `test/features/notebooks/nested_collections_integration_test.dart` (already exists — verify)

### 3.4 Reminders management screen

- [x] Full reminder management screen (currently per-note sheet only).
  - File: `lib/features/editor/widgets/note_reminders_sheet.dart` (verify exists)
  - New screen: `lib/features/reminders/reminders_screen.dart` (NEW)
- [x] Test: add/delete/list reminders.

### 3.5 Fix onboarding page count

- [x] Reconcile onboarding PageView: 5 pages (Welcome, Three Ways to Capture, Pick Your Vibe, Protect Vault, Ready).
  - File: `lib/features/onboarding/onboarding_screen.dart`
- [x] Update report docs to say 5 pages, not 4.

### 3.6 Internationalisation (gen-l10n)

- [x] Add real localisation with Gujarati and Hindi.
  - File: `l10n.yaml`
  - Files: `lib/l10n/` (`app_en.arb`, `app_gu.arb`, `app_hi.arb`, `generated/`)
  - File: `pubspec.yaml` (`flutter_localizations`, `intl`)
- [x] Validation: `flutter gen-l10n` runs without error; Gujarati/Hindi strings render correctly (`test/core/l10n/localization_test.dart`)

### 3.7 Accessibility audit

- [x] TalkBack/VoiceOver audit for key flows (create note, search, sync).
  - Files: `test/features/accessibility/talkback_key_flows_test.dart`
- [x] Widgetbook gallery (licence: verified).
  - File: `lib/features/gallery/widgetbook.g.dart`

### 3.8 Alchemist goldens for remaining card types

- [x] Add golden tests for NoteBannerCard, NoteDoodleCard, NotebookCard across color seeds / locked / pinned states.
  - File: `test/features/home/widgets/note_card_golden_test.dart` (NEW)

---

## Phase 4 — Portability and backup (needs DATA lane)

**Goal:** Encrypted backup file, folder mirror, Markdown round-trip.

**Depends on:** Phase 1 complete (KDF), Phase 0 complete (DATA lane owns schema).

### 4.1 Encrypted backup file (.nookbackup)

- [x] Build `.nookbackup` format using Phase 1 KDF (versioned Argon2id).
  - File: `lib/features/settings/widgets/backup_handler.dart`
  - File: `lib/features/settings/widgets/backup_screen.dart`
- [x] Restore tests: backup → wipe → restore → verify all notes intact.
  - File: `test/features/settings/backup_test.dart`

### 4.2 Folder mirror via Storage Access Framework

- [x] Markdown plus assets, written continuously to user-selected folder.
  - File: `lib/features/settings/widgets/folder_mirror.dart`
- [x] Users can sync with Syncthing or similar without libp2p.
  - Validation: `docs/SYNCTHING-MIRROR.md` explains Syncthing setup; `test/features/settings/folder_mirror_test.dart` passes

### 4.3 Markdown round-trip tests

- [x] Export → import → diff; verify zero data loss.
  - File: `test/features/settings/markdown_roundtrip_test.dart`
- [x] More importers: Obsidian vault, Joplin JEX.
  - Files: `lib/features/importers/obsidian_importer.dart`, `lib/features/importers/joplin_importer.dart`

---

## Phase 5 — Offline capture and search

**Goal:** Replace potentially non-FOSS speech recognition; add semantic search opt-in; keep FTS5 as default.

**Depends on:** Phase 1 complete (locked-note exclusion).

### 5.1 Speech-to-text replacement

- [ ] Replace system speech recognition (may use non-FOSS engine).
- [ ] Evaluate `whisper_cpp_flutter_plus` (MIT, Android/iOS only) **(verify licence)**.
- [ ] Evaluate `whisper_wrapper` (Windows, Linux x64) **(verify licence)**.
- [ ] Evaluate Vosk Flutter plugin (bundles Android native binaries, models from assets) **(verify licence)**.
- [ ] Decision: pin version, vendor and audit it; let users import model file with SHA-256 check.
  - Files: `lib/features/editor/widgets/voice_capture_sheet.dart` (modify)
  - File: `lib/core/platform/voice_capture_service.dart` (modify)

### 5.2 Semantic search (opt-in)

- [ ] `ai_core_codespark` (MIT, quantized MiniLM ONNX) — downloads model on first run **(verify licence)**.
  - Problem: download breaks "totally offline". Bundle ~23MB model or accept user-imported file.
- [ ] `mobile_rag_engine` (HNSW via Rust) — pub.dev licence showed as unknown **(verify)**.
- [ ] Keep FTS5 as default; never index locked notes.
  - File: `lib/data/repositories/search_repository.dart`

### 5.3 Handwriting search

- [ ] OCR doodle thumbnails into FTS index.
  - File: `lib/features/doodle/doodle_thumbnail_renderer.dart`
  - File: `lib/core/platform/ocr_service.dart`
- [ ] Verify mobile OCR engine behind `com.nook/ocr` is FOSS (Tesseract4Android usual option **(verify)**).

---

## Phase 6 — Editor depth

**Goal:** Richer editor features, mobile touch tests, better test tooling.

**Depends on:** Phase 0 complete.

### 6.1 Editor features

- [ ] Task due dates tied to local reminders.
  - Files: `lib/features/editor/widgets/note_reminders_sheet.dart`, `lib/core/platform/local_reminder_scheduler.dart`
- [ ] Daily-note template.
  - File: `lib/features/templates/template_picker_sheet.dart` (modify)
- [ ] Saved searches.
  - File: `lib/features/home/search_screen.dart` (modify)
- [ ] Backlinks graph view.
  - File: `lib/features/editor/widgets/backlinks_panel.dart` (modify)
- [ ] Quick switcher in command palette.
  - File: `lib/core/widgets/command_palette.dart` (modify)

### 6.2 Mobile touch tests

- [ ] Test touch gestures on real Android devices: selection handles, long-press menu, slash menu.
  - Files: `test/features/editor/` (add device-specific tests)

### 6.3 Test tooling

- [ ] Patrol: reaches native OS UI from Dart **(verify)**.
- [ ] Maestro: drives compiled app through semantics tree; licence needs checking **(verify)**.
  - Files: `test/` (add Maestro test directory if adopted)

---

## Phase 7 — Distribution

**Goal:** Reproducible builds for F-Droid, Flatpak/AppImage for Linux, decide web scope.

**Depends on:** Phase 0 complete.

### 7.1 Reproducible F-Droid builds

- [ ] Verify F-Droid reproducible build pipeline works end-to-end.
  - Files: `.github/workflows/ci.yml` (build-android job), `tool/ci/android_build.sh`, `tool/ci/fdroid_flutter_setup.sh`
- [ ] Flatpak or AppImage for Linux.
  - Files: `linux/` (packaging), `docs/LINUX-DISTRIBUTION.md` (NEW)

### 7.2 Web target scope decision

- [ ] Decide: web as read-only companion or drop for now.
  - Reason: no sync, weaker storage-encryption story on web.
  - File: `lib/features/web/web_companion_app.dart` (verify exists)
  - Document decision in `docs/WEB-TARGET.md` (NEW)

---

## Phase 8 — Beta readiness

**Goal:** Community review, privacy page, contributor guide, issue templates.

**Depends on:** Phases 1-7 complete or near-complete.

### 8.1 Community review

- [ ] Invite community review of crypto and sync design.
  - File: `SECURITY.md` (verify exists), `docs/SECURITY.md` (verify exists)

### 8.2 Documentation

- [ ] Write privacy page.
- [ ] Write contributor guide.
- [ ] Write issue templates.
- [ ] Keep CHANGELOG current.

---

## Lane Assignments and Parallel Execution

**Merge conflicts, not skill, are the main risk.** Use these lanes, each with a single owner for its files:

| Lane | Owns | Phases | Notes |
|------|------|--------|-------|
| SEC | `lib/core/security/*`, `lib/features/security/*`, vault/PIN/recovery | 1 | Only lane touching crypto |
| SYNC | `lib/sync/*` | 2 | Transport, protocol, merge |
| DATA | `lib/data/database.dart`, `lib/data/repositories/*`, migrations | All | **Only this lane touches the schema**; other lanes request changes through it |
| UISYS | `lib/core/theme/*`, `lib/core/widgets/*`, `lib/core/router.dart` | 0, 3 | Single owner for router and tokens |
| FEAT | `lib/features/home/*`, `lib/features/notebooks/*`, `lib/features/editor/*` | 3, 6 | Split into two agents by directory |
| CAPTURE | `lib/features/doodle/*`, `lib/features/editor/widgets/voice_capture_sheet.dart`, `lib/core/platform/ocr_service.dart` | 5 | Voice, OCR, doodle |
| QA | `test/*`, CI, goldens | All | Only this lane regenerates goldens |

### Working rules

1. Each agent works in its own git worktree and branch, with a small PR per task.
2. Write interfaces and fakes in Phase 0 so lanes can code against fakes instead of waiting on each other.
3. Allocate schema migration numbers centrally and merge them in order (DATA lane owns this).
4. Don't commit regenerated `*.g.dart` conflicts. Rebuild after merge with `dart run build_runner build --delete-conflicting-outputs`.
5. **TDD is mandatory on every task.** Write/edit the failing test before any implementation code. A task is not complete until its test was written, failed, then passed after implementation. A text-only agent can use ASCII layout snapshots for visual checks (`test/helpers/ascii_layout.dart`).
6. During each phase, tests are created or edited for every task — never skipped. The test file is the first file touched for any new feature or bug fix.

### Dependency order

- Phase 0 first (serial).
- Then Phases 1, 2, 3 in parallel.
- Phase 4 needs Phase 1 KDF.
- Phase 5 needs Phase 1's locked-note exclusion.
- Phases 6 to 8 follow.

### What to defer or refuse

- Real-time collaboration (breaks threat model).
- Plugin system (breaks threat model).
- Any cloud or analytics.
- On-device LLM for now (battery and size cost, limited gain).

---

## Verification gate (run at end of every task)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage -x network
```

All must pass before a PR is merged.
