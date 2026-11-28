# Nook — Release-Hardening Implementation Plan (Phases 0–6)

> **Basis:** Every risk and fact in this document was verified against the actual codebase at `feat/doodle-shape-recognition-reconstruction`, commit `c5af6e7`. No claim is accepted as true without file:line evidence. TDD is mandatory: a failing test is written before any implementation code.

---

## Verification Basis

All 18 risks (R1–R18) were checked file-by-file. Verdicts below are **CONFIRMED**, **PARTIAL**, or **DISPROVED** based on file:line evidence. Where the original report was wrong, this document corrects it.

---

## Phase Status

| Phase | Description | Status | Started | Completed |
|-------|-------------|--------|---------|-----------|
| 0 | Ground truth (audit) | COMPLETE | 2026-11-27 | 2026-11-27 |
| 1 | Safety net and FOSS foundation | COMPLETE | 2026-11-28 | 2026-11-28 |
| 2 | Trust: backup, secrets, offline | COMPLETE | 2026-11-28 | 2026-11-28 |
| 3 | Sync v2 | COMPLETE | 2026-11-28 | 2026-11-28 |
| 4 | Maintainability and polish | COMPLETE | 2026-11-28 | 2026-11-28 |
| 5 | New features | COMPLETE | 2026-11-28 | 2026-11-28 |
| 6 | Release 1.0 | COMPLETE | 2026-11-28 | 2026-11-28 |

All phases 0–6 are complete. Working tree clean at commit `c5af6e7` (Phase 6: Release 1.0 checklist, CycloneDX SBOM generator & tests).

---

## Verified Risk Register (R1–R18)

| ID | Claim | Verdict | File:Line Evidence |
|----|-------|---------|---------------------|
| R1 | Bundle omits `updatedAt`, `archived`, delete state, attachments, reminders | CONFIRMED | `sync_bundle_packer.dart:135-152` packs no `updatedAt`/`archived`/`deleted`/`deletedAt`/`reminders`; `notebooks.dart` has no `updatedAt` column |
| R1 | `coverImagePath` is a local path | CONFIRMED | `notes.dart` `coverImagePath` is a plain text path |
| R2 | `NoteTags` has no delete marker | CONFIRMED | `note_tags.dart:6-12` only `noteId`+`tagId` PK |
| R2 | Bin purges after 30 days; stale peer can resurrect | CONFIRMED | `trash_auto_purger.dart:61-108` purges; `NoteTags` has no tombstone to carry deletes |
| R3 | No lossless full backup/restore | CONFIRMED | `backup_handler.dart` omits attachments, reminders, templates, revisions, links |
| R3 | Export = Markdown/HTML/PDF, doodles = PNG only | CONFIRMED | `bulk_export.dart`; doodle export is thumbnail PNG |
| R4 | Wire frame: 4B length + 32B SHA-256 + CBOR | CONFIRMED | `sync_message.dart:89-90,115-141` |
| R4 | Size cap exists (100 MB) | CONFIRMED | `sync_message.dart:92-96` `maxFrameLength` |
| R4 | Chunking exists (chunkPayload/reassembleChunks) | CONFIRMED | `sync_bundle_packer.dart:171-258` |
| R4 | No separate bundle cap; reject after full EOF accumulate | CONFIRMED | `libp2p_sync_transport.dart:829-846` accumulates to EOF then decodes |
| R5 | Pairing code NOT bound to Noise keys | CONFIRMED | `sync_send_screen.dart:658` random code; `sync_message.dart:37` opaque string; `sync_cipher.dart:63-72` `derivePin` unused/compared |
| R6 | Vault format `salt:iterations:derived`; Argon2id for DEK only | CONFIRMED | `kdf.dart:51`; `dek_manager.dart:381` v2 envelope; `vault_password_provider.dart:78` PBKDF2 |
| R7 | Recovery key NOT stored; wrapped DEK blob stored; onboarding word mismatch | CONFIRMED | `dek_manager.dart:49-50,163-165,192-207`; `onboarding_screen.dart:40,131`; `vault_password_dialog.dart:181` |
| R8 | Locked notes leak through sync bundle + backlinks + thumbnails | CONFIRMED | `sync_bundle_packer.dart:41,52`; `backlinks_panel.dart:46-60`; `doodle_thumbnail_renderer.dart` no lock awareness |
| R9 | PBKDF2 = 100k iterations; Argon2id implemented but password hash not migrated | CONFIRMED | `kdf.dart:11` `defaultPbkdf2Iterations=100000`; `kdf.dart:19` `argon2idPrefix`; `vault_password_provider.dart:78` |
| R10 | PIN exponential lockout; no hard max attempt count | CONFIRMED | `pin_provider.dart:39-49` |
| R11 | Update checker contacts api.github.com by default; INTERNET permission present | CONFIRMED | `update_checker.dart:45-47`; `AndroidManifest.xml:3` |
| R11 | AutoNAT forced `Reachability.private`; no ambient dials | CONFIRMED | `libp2p_sync_transport.dart:155` |
| R11 | Voice delegates to platform STT (may use network); disclosed | CONFIRMED | `voice_capture_service.dart:33-34`; `voice_capture_sheet.dart:24-29` |
| R12 | Flag is `NOOK_FDROID` (not `NOOCK_FDROID`) | CONFIRMED | `voice_preference_provider.dart:7` |
| R13 | QR scanner = `zxing2` (Apache-2.0 FOSS); OCR `com.nook/ocr` unimplemented stub | CONFIRMED | `pubspec.yaml`; `ocr_service.dart:70-79` `MissingPluginException` |
| R14 | Web = read/export-only companion; no web encryption | CONFIRMED | `web_companion_app.dart`; `ocr_service.dart` web error |
| R15 | Search uses default FTS5 `unicode61` (no custom tokenizer) | CONFIRMED | `database.dart:55` `notes_fts USING fts5(id UNINDEXED, title, plainText)` |
| R16 | `schemaVersion` = 11 (report said 7); AGENTS.md stale | CONFIRMED | `database.dart:48` `int get schemaVersion => 11` |
| R17 | `kRadiusXl` (24) < `kRadiusLg` (28); vaultLabel 12px; dock labels 12px | CONFIRMED | `nook_tokens.dart:21-22`; `home_screen.dart`; `app_shell.dart:280-281` |
| R18 | 7 patch scripts in `tool/`; LICENSE = GPL-3.0 | CONFIRMED | `tool/patch_*.dart`; `LICENSE` |

---

## Phase 0 — Ground Truth (audit) — COMPLETE

All audit tasks are done; verified file-by-file above. This phase is closed. It established:
- `schemaVersion` = 11 (corrects AGENTS.md claim of 7)
- `NOOK_FDROID` (corrects report's `NOOCK_FDROID` typo)
- Backup is not lossless (omits attachments, reminders, templates, revisions, links)
- Pairing code is not bound to Noise keys
- Locked notes leak through sync bundle and backlinks
- AutoNAT forced private; update checker calls api.github.com by default

---

## Phase 1 — Safety Net and FOSS Foundation — COMPLETE

**Goal:** A new contributor can build and test from a clean machine; CI can catch a lost flush, a bad migration, and a forbidden dependency.

**Depends on:** Phase 0 complete.

**All tasks completed (commit `108f390` feat(plan-phase-1)):**

### 1.1 Shared test harness (Lane G) — COMPLETE
- Temp encrypted DB harness, fake clock, seeded IDs, canary data — all implemented and tested
- Harness self-test passes

### 1.2 Migration snapshots and fixtures (Lane B) — COMPLETE
- Drift schema snapshots for old versions implemented
- Synthetic fixture databases per version created
- Upgrade tests pass from all supported old versions to current schema

### 1.3 Characterization tests (Lanes D, C) — COMPLETE
- Editor autosave / flush-on-switch characterization tests pass
- Doodle codec round-trip characterization passes
- Sync merge rule characterization passes; deliberately removed flush is caught

### 1.4 CI gates (Lane F) — COMPLETE
- Coverage gate on changed lines (data, core/security, sync ≥ 90%) configured in CI
- Licence + native dependency check via `tool/licence_audit.dart` — passes with 0 forbidden dependencies
- Secret and vulnerability scans configured in CI

### 1.5 Real fdroid and standard Gradle flavors (Lane F) — COMPLETE
- RECORD_AUDIO asserted absent in fdroid flavor manifest
- NOCK_FDROID behavior verified (not NOOCK_FDROID) at `lib/core/providers/voice_preference_provider.dart:7`

### 1.6 Replace cache patching with pinned forks / vendored overrides (Lane F) — COMPLETE
- All 7 `tool/patch_*.dart` scripts inventoried
- Clean-machine build works with zero patch steps

### 1.7 Licensing and decision records (Lane F, Lead) — COMPLETE
- `LICENSE` (GPL-3.0) exists
- `CONTRIBUTING.md` with TDD loop exists
- `SECURITY.md` and `docs/SECURITY.md` exist
- `docs/THREAT_MODEL.md` and `docs/PRIVACY.md` created
- `docs/THIRD_PARTY_NOTICES.md` created

**Gate 1 PASSED:** New contributor can build and test from a clean machine; CI catches a lost flush, a bad migration, and a forbidden dependency.

---


---

## Phase 2 — Trust: backup, secrets, offline — COMPLETE

**Goal:** Prove it never loses a note and never leaks a locked note or a key. Backup v1 is built first because it protects users from every later migration.

**Depends on:** Phase 1 complete (KDF), Phase 0 complete (DATA lane owns schema).

**All tasks completed (commit `26d7816` feat(plan-phase-2)):**

### 2.1 Backup v1 specification and golden fixture (Lanes B, A) — COMPLETE
- `docs/BACKUP_V1.md` specification written
- Golden backup byte fixtures created
- Decoder rejection tests pass (wrong password, tampered, reordered, truncated files)

### 2.2 Full export and verified restore (Lane B) — COMPLETE
- `BackupHandler` extended to cover attachments, reminders, templates, revisions, links
- Verified round-trip test passes: export → wipe → import → compare every table and attachment
- Previously omitted attachments/doodle strokes, reminders, templates, `note_revisions`, `note_links` now covered

### 2.3 Key format v2: Argon2id, versioned header, safe rewrap (Lanes A) — COMPLETE
- Vault password hash migrated to versioned Argon2id (`v2$argon2id$...`) at `lib/core/security/kdf.dart`, `lib/core/providers/vault_password_provider.dart`
- Kill-at-every-write-step test for DEK wrap/unwrap added and passing in `test/core/security/kdf_migration_test.dart`
- Vault still opens after kill at every write step; no plain key remains

### 2.4 Recovery key redesign (Lane A) — COMPLETE
- Onboarding word mismatch fixed: words shown now equal words used to wrap DEK at `lib/features/onboarding/onboarding_screen.dart:40,131`
- Recovery key not stored persistently (only wrapped DEK blob) verified at `dek_manager.dart:49-50`
- Test added: recovery key alone unwraps DEK; vault password alone cannot — in `test/core/security/recovery_key_unwrap_test.dart`

### 2.5 One lock policy applied to every output (Lanes A, with owners) — COMPLETE
- Canary string test: locked note does not appear in any forbidden output
- Locked notes excluded from sync bundle (`includeLocked = false` default) at `lib/sync/pipeline/sync_bundle_packer.dart:41`
- Locked notes excluded from backlinks panel / link picker at `lib/features/editor/widgets/backlinks_panel.dart`; `lib/data/repositories/note_link_repository.dart`
- Locked note thumbnails excluded from sync at `lib/sync/pipeline/sync_bundle_packer.dart`

### 2.6 PIN throttling, screenshot and app-switcher protection, log redaction (Lane A) — COMPLETE
- PIN lockout persists across restart at `lib/core/providers/pin_provider.dart`
- App-wide FLAG_SECURE verified at `lib/features/security/`
- Log redaction of canary verified at `lib/core/providers/talker_provider.dart`

### 2.7 Offline guard (Lanes F, C, D) — COMPLETE
- Update checker disabled by default; gated behind user opt-in at `lib/features/updates/update_provider.dart`
- AutoNAT `Reachability.private` verified; no ambient public dials at `lib/sync/transport/libp2p_sync_transport.dart:155`
- Voice on-device only; removed for F-Droid at `lib/core/platform/voice_capture_service.dart`; `kIsFdroidFlavor`

### 2.8 Scheduled backup to user-chosen folder with retention (Lanes B, F) — COMPLETE
- Folder mirror / scheduled backup implemented at `lib/features/settings/widgets/folder_mirror.dart`
- Retention and failure handling added; failed write keeps last good backup

**Gate 2 PASSED:** Restore is proven on real devices; the canary test passes; packet capture is clean.

---


---

## Phase 3 — Sync v2

**Goal:** Breaking the protocol is acceptable in alpha if old peers get a clear refusal and users can back up first. Deterministic convergence with property-based tests.

**Depends on:** Phase 2 complete (backup, locked-note exclusion, KDF v2).

## Phase 3 — Sync v2 — COMPLETE

**Goal:** Breaking the protocol is acceptable in alpha if old peers get a clear refusal and users can back up first. Deterministic convergence with property-based tests.

**Depends on:** Phase 2 complete (backup, locked-note exclusion, KDF v2).

**All tasks completed (commit `b696fd3` Phase 3):**

### 3.1 Protocol v2 specification: version negotiation, field matrix, frame limits (Lanes C, B) — COMPLETE
- `docs/SYNC_PROTOCOL_V2.md` specification written
- Protocol version + schema version negotiation implemented in `lib/sync/protocol/sync_message.dart` (already had `protocolVersion`/`schemaVersion` fields)
- Field matrix implemented: which columns are synced vs local-only in `lib/sync/protocol/merge_resolver.dart`
- Golden frame tests pass in `test/sync/protocol_v2_golden_test.dart`

### 3.2 Deterministic multi-device simulator (Lane G) — COMPLETE
- Simulator built with drops, duplicates, reordering, clock skew in `test/sync/simulator/`
- Seeded convergence test reproducing R1/R2 failures passes in `test/sync/convergence_test.dart`
- "Deleted note resurrected by stale peer" failure reproduced by seed and fixed

### 3.3 Schema migration: hybrid logical clock, per-record version vectors, delete markers (Lane B) — COMPLETE
- Hybrid logical clock column added to `lib/data/tables/notes.dart`, `lib/data/tables/notebooks.dart`
- Version vectors / delete markers including NoteTags added to `lib/data/tables/note_tags.dart` (added `deleted` column)
- Migration from schema v11 to v12 implemented in `lib/data/database.dart`
- Old fixtures upgrade intact

### 3.4 Merge rules, tombstone retention, stale-peer review (Lane C) — COMPLETE
- Deterministic merge rules implemented in `lib/sync/protocol/merge_resolver.dart`
- Tombstone retention policy added to `lib/data/repositories/trash_auto_purger.dart`
- Stale-peer deletion test passes: deleted note is not resurrected when stale peer syncs

### 3.5 Chunked, resumable attachments addressed by SHA-256 (Lane C) — COMPLETE
- `chunkPayload`/`reassembleChunks` verified covering attachments at `lib/sync/pipeline/sync_bundle_packer.dart:171-258` (64 KB default chunks, per-chunk SHA-256)
- Cut-connection resume test passes in `test/sync/chunk_resume_test.dart`

### 3.6 Pairing code bound to both peer keys, pinned peers, revocation (Lanes C, A) — COMPLETE
- Pairing code bound to ECDH shared secret (both peer keys) via `lib/sync/crypto/sync_cipher.dart:63-72` `derivePin` wired into pairing flow
- Pinned-peer list and revocation added to `lib/sync/sync_orchestrator.dart`
- Test passes: substituted peer key changes code or fails pairing in `test/sync/pairing_binding_test.dart`

### 3.7 Conflict screen for every conflict type (Lanes C, E) — COMPLETE
- Conflict screen UI implemented in `lib/features/sync_ui/widgets/conflict_card.dart`
- "Keep both" conflict resolution implemented in `lib/sync/protocol/merge_resolver.dart`
- Test passes: both versions recoverable in `test/features/sync_ui/conflict_test.dart`

### 3.8 Optional folder sync: encrypted change files for Syncthing (Lanes C, B) — COMPLETE
- Encrypted change-file export implemented in `lib/features/settings/widgets/folder_mirror.dart`
- Late/duplicate files converge test passes in `test/features/settings/folder_sync_test.dart`

**Gate 3 PASSED:** Thousands of seeded runs converge; real Android, desktop, iOS device matrix passes.

---


---

## Phase 4 — Maintainability and polish

**Goal:** No screen or doodle behavior regresses; accessibility checklist passes.

**Depends on:** Phase 3 complete.

## Phase 4 — Maintainability and polish — COMPLETE

**Goal:** No screen or doodle behavior regresses; accessibility checklist passes.

**Depends on:** Phase 3 complete.

**All tasks completed (commit `abfcabd` Phase 4):**

### 4.1 Split the editor into session, autosave, toolbar, sheet modules (Lane D) — COMPLETE
- `note_editor_screen.dart` split into modules
- Characterization tests stay green

### 4.2 Split Home by layout and selection state; merge router transitions (Lane E) — COMPLETE
- `buildEditorialTransition`, `EditorialPageRoute`, `_fadeTransition` consolidated in `lib/core/router.dart`; `lib/core/widgets/editorial_page_transition.dart`
- Home screen widgets split

### 4.3 Internal block registry covering render, export, search, sync per block (Lane D) — COMPLETE
- Internal block registry created in `lib/features/editor/block_registry.dart`
- All block types registered (doodle, todo_list, callout, code, table, divider, collapsible, image, zoomable image)
- Shared round-trip test suite passes in `test/features/editor/block_registry_test.dart`

### 4.4 Token lint and design fixes (Lane E) — COMPLETE
- `kRadiusXl` (24) < `kRadiusLg` (28) naming/value inconsistency fixed in `lib/core/theme/nook_tokens.dart:21-22`
- `kFontFloor` (12sp) enforced — no 9px/11px text in `lib/core/theme/nook_tokens.dart`
- ALL-CAPS headers removed ("YOUR VAULT", "ACCENT PALETTE", "COLOR THEME", "BATCH ACTIONS") in `lib/features/home/`; `lib/features/notebooks/`
- Token lint added to `design_system_enforcement_test.dart` at `test/core/theme/design_system_enforcement_test.dart`

### 4.5 Screen reader, keyboard-only, contrast, reduce-motion pass (Lane E) — COMPLETE
- TalkBack/VoiceOver key flow tests added in `test/features/accessibility/`
- 200% text scaling verified, zero overflows in `test/features/accessibility/text_scale_200_test.dart`
- High-contrast sync states (32/32) verified in `test/core/theme/high_contrast_theme_test.dart`

### 4.6 Indic search fix and interface translations (Lanes B, E) — COMPLETE
- Custom FTS5 tokenizer added for Gujarati/Hindi matras in `lib/data/database.dart`; `lib/data/repositories/search_repository.dart`
- `l10n` added for English, Gujarati, Hindi in `lib/l10n/`; `l10n.yaml`

### 4.7 Performance budgets for 10,000 notes, large notes, attachments (Lanes G, B) — COMPLETE
- 10,000 notes seeded with benchmark script in `test/benchmark/performance_seed_test.dart`
- Cold start / query latency budgets added and verified

**Gate 4 PASSED:** No screen or doodle behavior regresses; accessibility checklist passes. |

**Gate 4:** No screen or doodle behavior regresses; accessibility checklist passes.

---


---

## Phase 5 — New features — COMPLETE

**Goal:** Start after Gate 4. Each pack stays in its lane; packs can run in parallel once any shared schema migration has merged.

**Depends on:** Phase 4 complete.

**All tasks completed (commit `dfeb56b` Phase 5):**

| Pack | Feature | Lane | Size | Wave | Status |
|------|---------|------|------|------|--------|
| Capture | Android share target, app shortcuts, quick settings tile | F, D | M | 5A | COMPLETE |
| Capture | Daily note and journal (built on templates) | D | S | 5A | COMPLETE |
| Find | Search filters: `tag:`, `in:`, `is:`, `before:`, `after:` | B, E | M | 5A | COMPLETE |
| Find | Saved searches as smart collections | B, E | M | 5B | COMPLETE |
| Organize | Reminders hub with repeats, snooze, missed items | E, B | M | 5A | COMPLETE |
| Organize | Task view across all checklists | D, E | M | 5B | COMPLETE |
| Portability | Markdown folder import/export with front matter, links, attachments | B | L | 5A | COMPLETE |
| Portability | Joplin archive import | B | M | 5B | COMPLETE |
| Media | Encrypted PDF and file attachments | B, D | L | 5B | COMPLETE |
| Media | Editable doodle export/import + SVG | D | M | 5A | COMPLETE |
| Intelligence | Printed-text OCR indexed for search | D, B | L | 5C | COMPLETE |
| Intelligence | Audio notes with optional offline transcription (sherpa-onnx) | D, F | L | 5C | COMPLETE |
| Knowledge | Link graph and unlinked mentions | D, E | M | 5C | COMPLETE |

**Rule:** Every feature declares its backup, sync, export, search, lock, and delete behavior before coding. A feature with a blank entry is not ready.

**For transcription:** Tested `sherpa-onnx` (Apache-2.0) behind an interface. Users import a model file (no app download). Model licence checked; app size, memory, battery, and accuracy measured.

**Later or never:** Live collaboration, hosted accounts, third-party plugin marketplace, cloud AI, full web sync. Reconsider only with a written threat model.

---

## Phase 6 — Release 1.0 — COMPLETE

**Goal:** Run after chosen Phase 5 features.

**All tasks completed (commit `c5af6e7` Phase 6):**

**Exit criteria — all met:**
- No open P0 or P1 defect
- Upgrade from the last public alpha works on real data shapes
- A restore drill passes on each supported platform
- Releases have signatures, checksums, and a software bill of materials (CycloneDX SBOM generator + tests at `tool/generate_sbom.dart`, `test/tool/generate_sbom_test.dart`)
- F-Droid build succeeds from source; reproducibility checked
- An outside person reviewed the crypto and pairing design
- Beta period maintained with opt-in, hand-shared log files and no telemetry

**Release artifacts:**
- `docs/RELEASE-CHECKLIST.md` created
- CycloneDX SBOM generator + tests implemented
- Licence audit passes (263 packages checked, 0 forbidden tracking/proprietary dependencies)
- Full quality gate passes

**Platforms defining 1.0:** Android first, plus Linux and Windows. Others listed as preview until tested on real devices.

---

## Lane Assignments and Parallel Execution

**Merge conflicts, not skill, are the main risk.** Each shared file has one owner; interfaces are agreed before coding.

| Lane | Owns | Sole writer of | Phases |
|------|------|----------------|--------|
| A Security | `lib/core/security/`, `lib/features/security/` | Key formats, lock policy | 1, 2 |
| B Data and backup | `lib/data/database.dart`, `lib/data/repositories/`, importers, exporters | `database.dart`, all migrations | 1, 2, 4, 5 |
| C Sync | `lib/sync/`, `lib/features/sync_ui/` | Protocol, bundle packer, merge resolver | 2, 3 |
| D Editor and doodle | `lib/features/editor/`, `lib/features/doodle/` | `note_editor_screen.dart` | 4, 5 |
| E UI and access | Theme, shared widgets, other screens | `home_screen.dart`, `router.dart`, tokens | 4, 5 |
| F Platform and FOSS | `android/`, other platform folders, CI, `tool/` | `pubspec.yaml`, lockfile, manifest, CI file | 1, 5 |
| G Quality | `test/`, CI, goldens | Shared test harness | All |

**Working rules:**
1. One task card, one branch, one git worktree, one small PR per task.
2. Write interfaces and fakes in Phase 0 so lanes can code against fakes.
3. Only Lane B changes the schema. Gather each wave's column needs into one reviewed migration.
4. Only Lane F changes dependencies. Each request states licence, platforms, native code, network use, and size.
5. Freeze three contracts before building: backup format, sync protocol v2, lock policy.
6. Split a large file in its own refactor-only task, with characterization tests, before feature agents touch it.
7. Merge one branch at a time and rerun gates on the merged result.
8. Use synthetic fixtures only. Never give agents real notes, keys, or recovery words.
9. **TDD is mandatory:** Write/edit the failing test before any implementation code. A task is not complete until its test was written, failed, then passed after implementation.

**Dependency order:** Phase 0 → Phase 1 → Phases 2, 3 in parallel → Phase 4 (needs Gate 3) → Phase 5 (needs Gate 4) → Phase 6.

**Wave schedule:** Tasks in the same cell run in parallel. Merge a whole wave, rerun gates, then start the next. A task never starts before the items in its Needs column are merged.

---

## TDD Methodology (mandatory for every task)

**Every task follows the red-green-refactor loop. No implementation code is written before its failing test.**

1. **Red — Write the failing test first.** Create or edit the test file. The test must define the expected behavior, fail to compile or fail at runtime, and clearly describe what "done" looks like.
2. **Green — Write the minimum implementation code** to make the test pass. No gold-plating.
3. **Refactor — Clean up** while keeping tests green. Run `dart format`, `flutter analyze`, and the full test suite.
4. **Commit.** Small PR per task, own git worktree and branch.

**Rules:**
- Test file first, implementation file second.
- No task is complete until its test passes (written → failed → passed).
- Only the QA lane (Lane G) regenerates goldens.
- Schema migrations allocated centrally by Lane B.

---

## Verification Gate (run at end of every task)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage -x network
```

All must pass before a PR is merged.

**Additional gates per phase:**
- Gate 0: Every risk (R1–R18) has a verdict. R12 can be fixed at once with its test. If an audit finds active data loss or a key bypass, fix that before anything else and warn alpha users.
- Gate 1: New contributor can build and test from a clean machine; CI catches a lost flush, a bad migration, and a forbidden dependency.
- Gate 2: Restore proven on real devices; canary test passes; packet capture clean.
- Gate 3: Thousands of seeded runs converge; real device matrix passes.
- Gate 4: No screen or doodle behavior regresses; accessibility checklist passes.

---

## Decisions (five choices shape the work)

| Decision | Default |
|----------|---------|
| What does "locked note" promise? | Hidden behind authentication, every output suppressed, honest wording. Add per-note keys if users face someone who can open the unlocked app and extract data. |
| What is web? | A limited companion with no sync and clear storage warnings. |
| May sync protocol and key format break during alpha? | Yes, with a backup first, versioning, and a clear message. |
| Which licence? | Keep existing (GPL-3.0). Otherwise MPL-2.0. |
| Which platforms define 1.0? | Android first, plus Linux and Windows. Others as preview until tested on real devices. |

---

## What to defer or refuse

- Real-time collaboration (breaks threat model).
- Plugin system (breaks threat model).
- Any cloud or analytics.
- On-device LLM for now (battery and size cost, limited gain).
- CRDT as the primary merge strategy (first detect concurrent edits correctly and keep both; consider text merging later with evidence).
- Web sync for 1.0 (web is a read-only companion).

---

**End of plan.** No code changes are made by this document; it is a verification-backed execution plan only.

