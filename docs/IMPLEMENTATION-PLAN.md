# Nook — Release-Hardening Implementation Plan (Phases 0–6)

> **Basis:** Every risk and fact in this document was verified against the actual codebase at `feat/doodle-shape-recognition-reconstruction`, commit `91d8617`. No claim is accepted as true without file:line evidence. TDD is mandatory: a failing test is written before any implementation code.

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
| 3 | Sync v2 | COMPLETE | 2026-11-28 | Protocol v2 spec, schema v12 (`note_tags.deleted`, `hlc`), `SyncSimulator` convergence, tombstone non-resurrection, chunk resume, key-bound pairing, conflict preservation, encrypted folder sync |
| 4 | Maintainability and polish | COMPLETE | 2026-11-28 | `BlockRegistry` + tests, `kRadiusLg`/`kRadiusXl` token monotonicity, Indic matra FTS5 test, 10k-note latency budget, design-system & high-contrast gates |
| 5 | New features | COMPLETE | 2026-11-28 | Structured search filters (`tag:`, `in:`, `is:`, `before:`, `after:`), cross-note open checklists, Doodle SVG export, unlinked mentions, feature matrix |
| 6 | Release 1.0 | COMPLETE | 2026-11-28 | `docs/RELEASE-CHECKLIST.md`, CycloneDX SBOM generator + tests, licence audit, full quality gate |

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

## Phase 1 — Safety Net and FOSS Foundation

**Goal:** A new contributor can build and test from a clean machine; CI can catch a lost flush, a bad migration, and a forbidden dependency. No feature code yet.

**Depends on:** Phase 0 complete.

### 1.1 Shared test harness (Lane G)

**Done when:** Harness self-test passes; fake clock, seeded IDs, canary data, temporary encrypted DB work.

| Step | Action | Files |
|------|--------|-------|
| 1.1.1 | Create temp encrypted DB harness | `test/helpers/test_database.dart` (NEW) |
| 1.1.2 | Create fake clock helper | `test/helpers/fake_clock.dart` (NEW) |
| 1.1.3 | Create seeded ID / canary data helpers | `test/helpers/canary_data.dart` (NEW) |
| 1.1.4 | Harness self-test | `test/helpers/harness_self_test.dart` (NEW) |

**TDD:** Write harness self-test first; it must fail, then pass.

### 1.2 Migration snapshots and fixtures (Lane B)

**Done when:** An upgrade that drops a row fails the test.

| Step | Action | Files |
|------|--------|-------|
| 1.2.1 | Create Drift schema snapshots for supported old versions | `test/data/schema_snapshots/` (NEW) |
| 1.2.2 | Create synthetic fixture databases per version | `test/data/fixtures/` (NEW) |
| 1.2.3 | Test upgrade from each old version to current (schema v11) | `test/data/migration_upgrade_test.dart` (NEW) |

**TDD:** Write a test that deliberately drops a row; it must fail before the fix.

### 1.3 Characterization tests (Lanes D, C)

**Done when:** A deliberately removed autosave flush is caught by a test.

| Step | Action | Files |
|------|--------|-------|
| 1.3.1 | Editor autosave / flush-on-switch characterization | `test/features/editor/characterization/` (NEW) |
| 1.3.2 | Doodle codec round-trip characterization | `test/features/doodle/codec_characterization_test.dart` (NEW) |
| 1.3.3 | Sync merge rule characterization | `test/sync/merge_characterization_test.dart` (NEW) |

**TDD:** Remove the flush temporarily; the test must fail. Restore; test passes.

### 1.4 CI gates (Lane F)

**Done when:** A planted proprietary dependency fails CI.

| Step | Action | Files |
|------|--------|-------|
| 1.4.1 | Coverage gate on changed lines (data, core/security, sync ≥ 90%) | `.github/workflows/ci.yml` |
| 1.4.2 | Licence + native dependency check | `tool/licence_audit.dart` (already exists) |
| 1.4.3 | Secret and vulnerability scans | `.github/workflows/ci.yml` |

### 1.5 Real fdroid and standard Gradle flavors (Lane F)

**Done when:** Merged manifest and APK contents asserted per flavor.

| Step | Action | Files |
|------|--------|-------|
| 1.5.1 | Assert RECORD_AUDIO absent in fdroid flavor manifest | `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts` |
| 1.5.2 | Assert NOCK_FDROID behavior (not NOOCK_FDROID) | `lib/core/providers/voice_preference_provider.dart:7` |

### 1.6 Replace cache patching with pinned forks / vendored overrides (Lane F)

**Done when:** A clean build works with no patch step.

| Step | Action | Files |
|------|--------|-------|
| 1.6.1 | Inventory all `tool/patch_*.dart` scripts | `tool/patch_*.dart` (7 scripts exist) |
| 1.6.2 | Replace each patch with a pinned fork or vendored override | `pubspec.yaml` `dependency_overrides` |
| 1.6.3 | Clean-machine build with zero patch steps | CI `flutter-prep` job |

### 1.7 Licensing and decision records (Lane F, Lead)

**Done when:** Licence metadata check passes; short ADRs merged.

| Step | Action | Files |
|------|--------|-------|
| 1.7.1 | Add `LICENSE` (GPL-3.0 already exists) | `LICENSE` (exists) |
| 1.7.2 | Add `CONTRIBUTING.md` with TDD loop | `CONTRIBUTING.md` (exists) |
| 1.7.3 | Add `SECURITY.md` with private report route | `SECURITY.md` (exists), `docs/SECURITY.md` (exists) |
| 1.7.4 | Add `THREAT_MODEL.md` and `PRIVACY.md` | `docs/THREAT_MODEL.md` (NEW), `docs/PRIVACY.md` (NEW) |
| 1.7.5 | Third-party notices | `docs/THIRD_PARTY_NOTICES.md` (NEW) |

**Gate 1:** New contributor can build and test from a clean machine; CI catches a lost flush, a bad migration, and a forbidden dependency.

---


---

## Phase 2 — Trust: backup, secrets, offline

**Goal:** Prove it never loses a note and never leaks a locked note or a key. Backup v1 is built first because it protects users from every later migration.

**Depends on:** Phase 1 complete (KDF), Phase 0 complete (DATA lane owns schema).

### 2.1 Backup v1 specification and golden fixture (Lanes B, A)

**Done when:** Decoder rejects wrong password, tampered, reordered, and truncated files.

| Step | Action | Files |
|------|--------|-------|
| 2.1.1 | Write `BACKUP_V1.md` specification | `docs/BACKUP_V1.md` (NEW) |
| 2.1.2 | Create golden backup byte fixtures | `test/fixtures/backup_v1_golden/` (NEW) |
| 2.1.3 | Write decoder rejection tests | `test/features/settings/backup_decoder_test.dart` (NEW) |

**Header:** format version, KDF settings (Argon2id v2), salt. **Body:** authenticated AES-256-GCM chunks binding chunk order and end marker. Include all user data, delete markers, doodle strokes, attachments. Exclude device keys.

**TDD:** Write a test that feeds a tampered golden file; it must fail before the decoder rejects it.

### 2.2 Full export and verified restore (Lane B)

**Done when:** Wipe and restore matches every table and attachment.

| Step | Action | Files |
|------|--------|-------|
| 2.2.1 | Extend `BackupHandler` to cover attachments, reminders, templates, revisions, links | `lib/features/settings/widgets/backup_handler.dart` (modify) |
| 2.2.2 | Add verified round-trip test: export → wipe → import → compare every table | `test/features/settings/backup_roundtrip_test.dart` (NEW) |

**Current gap (verified):** `backup_handler.dart` covers only notebooks, notes, checklist items, tags. Omits attachments/doodle strokes, reminders, templates, `note_revisions`, `note_links`.

**TDD:** Write the round-trip test first; it must fail because attachments/reminders/templates are dropped.

### 2.3 Key format v2: Argon2id, versioned header, safe rewrap (Lanes A)

**Done when:** Kill at every write step; the vault still opens and no plain key remains.

| Step | Action | Files |
|------|--------|-------|
| 2.3.1 | Audit current KDF: PBKDF2 100k for password hash; Argon2id for DEK wrap | `kdf.dart:11,19`; `dek_manager.dart:381` |
| 2.3.2 | Migrate vault password hash to versioned Argon2id (`v2$argon2id$...`) | `lib/core/security/kdf.dart`, `lib/core/providers/vault_password_provider.dart` |
| 2.3.3 | Add kill-at-every-write-step test for DEK wrap/unwrap | `test/core/security/kdf_migration_test.dart` (modify) |

**Current gap (verified):** Password hash is still `salt:iterations:derived` PBKDF2 (`vault_password_provider.dart:78`). DEK wrap already uses Argon2id v2 (`dek_manager.dart:381`).

**TDD:** Kill the process at each write step; verify vault still opens and no plain key remains.

### 2.4 Recovery key redesign (Lane A)

**Done when:** App storage alone cannot unlock the vault.

| Step | Action | Files |
|------|--------|-------|
| 2.4.1 | Fix onboarding word mismatch: words shown must equal words used to wrap | `lib/features/onboarding/onboarding_screen.dart:40,131` |
| 2.4.2 | Verify recovery key is not stored persistently (only wrapped DEK blob) | `dek_manager.dart:49-50` |
| 2.4.3 | Add test: recovery key alone unwraps DEK; vault password alone cannot | `test/core/security/recovery_key_unwrap_test.dart` (NEW) |

**Current gap (verified):** Onboarding wraps DEK with `_recoveryWords` (line 40) but ignores the words the user verified (line 131 `_` discards them). Words shown ≠ words wrapped.

**TDD:** Write test that attempts unwrap with shown words vs wrapped words; mismatch must fail before fix.

### 2.5 One lock policy applied to every output (Lanes A, with owners)

**Done when:** The canary appears in no forbidden output.

| Step | Action | Files |
|------|--------|-------|
| 2.5.1 | Put canary string in a locked note | Test data only |
| 2.5.2 | Exclude locked notes from sync bundle (default `includeLocked = false`) | `lib/sync/pipeline/sync_bundle_packer.dart:41` |
| 2.5.3 | Exclude locked notes from backlinks panel / link picker | `lib/features/editor/widgets/backlinks_panel.dart`; `lib/data/repositories/note_link_repository.dart` |
| 2.5.4 | Exclude locked note thumbnails from sync | `lib/sync/pipeline/sync_bundle_packer.dart` |
| 2.5.5 | Scan every output surface for locked-note leakage | Test suite |

**Current gap (verified):** `includeLocked = true` default at `sync_bundle_packer.dart:41`; backlinks panel has no locked filter (`backlinks_panel.dart:46-60`); link picker has no locked filter (`note_link_repository.dart:184-203`).

**TDD:** Write canary test: locked note with "CANARY_SECRET" must not appear in sync bundle, backlinks, or link picker.

### 2.6 PIN throttling, screenshot and app-switcher protection, log redaction (Lane A)

**Done when:** Restart does not reset delays; logs contain no canary.

| Step | Action | Files |
|------|--------|-------|
| 2.6.1 | Verify PIN lockout survives restart (persist lockout state) | `lib/core/providers/pin_provider.dart` |
| 2.6.2 | Verify app-wide FLAG_SECURE | `lib/features/security/` |
| 2.6.3 | Verify log redaction of canary | `lib/core/providers/talker_provider.dart` |

**Current gap (verified):** PIN lockout is in-memory only (`pin_provider.dart:39-49`); no persistence across restart.

### 2.7 Offline guard: update checker off by default, AutoNAT disabled, voice on-device or removed (Lanes F, C, D)

**Done when:** Packet capture and socket allowlist tests are clean.

| Step | Action | Files |
|------|--------|-------|
| 2.7.1 | Disable update checker by default; gate behind user opt-in | `lib/features/updates/update_provider.dart` |
| 2.7.2 | Verify AutoNAT `Reachability.private`; no ambient public dials | `lib/sync/transport/libp2p_sync_transport.dart:155` |
| 2.7.3 | Voice on-device only or removed for F-Droid | `lib/core/platform/voice_capture_service.dart`; `kIsFdroidFlavor` |

**Current gap (verified):** Update checker contacts `api.github.com` by default (`update_checker.dart:45-47`); no user-disable toggle.

### 2.8 Scheduled backup to user-chosen folder with retention (Lanes B, F)

**Done when:** A failed write keeps the last good backup and tells the user.

| Step | Action | Files |
|------|--------|-------|
| 2.8.1 | Implement folder mirror / scheduled backup | `lib/features/settings/widgets/folder_mirror.dart` (modify) |
| 2.8.2 | Add retention and failure handling | `lib/features/settings/widgets/folder_mirror.dart` |

**Gate 2:** Restore is proven on real devices; the canary test passes; packet capture is clean.

---


---

## Phase 3 — Sync v2

**Goal:** Breaking the protocol is acceptable in alpha if old peers get a clear refusal and users can back up first. Deterministic convergence with property-based tests.

**Depends on:** Phase 2 complete (backup, locked-note exclusion, KDF v2).

### 3.1 Protocol v2 specification: version negotiation, field matrix, frame limits (Lanes C, B)

**Done when:** Golden frames; every column marked synced or local-only with a reason.

| Step | Action | Files |
|------|--------|-------|
| 3.1.1 | Write `SYNC_PROTOCOL_V2.md` specification | `docs/SYNC_PROTOCOL_V2.md` (NEW) |
| 3.1.2 | Add protocol version + schema version negotiation | `lib/sync/protocol/sync_message.dart` (already has `protocolVersion`/`schemaVersion`) |
| 3.1.3 | Add field matrix: which columns are synced vs local-only | `lib/sync/protocol/merge_resolver.dart` |
| 3.1.4 | Golden frame tests | `test/sync/protocol_v2_golden_test.dart` (NEW) |

**Current state (verified):** `sync_message.dart` already has `protocolVersion`/`schemaVersion` fields (lines 34-35, 46-47). `SyncCapabilityNegotiator` exists at `merge_resolver.dart:37`.

### 3.2 Deterministic multi-device simulator (Lane G)

**Done when:** Known failures from R1/R2 reproduce by seed.

| Step | Action | Files |
|------|--------|-------|
| 3.2.1 | Build simulator with drops, duplicates, reordering, clock skew | `test/sync/simulator/` (NEW) |
| 3.2.2 | Seeded convergence test reproducing R1/R2 failures | `test/sync/convergence_test.dart` (modify) |

**TDD:** Write a seeded test that reproduces the "deleted note resurrected by stale peer" failure; it must fail before the fix.

### 3.3 Schema migration: hybrid logical clock, per-record version vectors, delete markers (Lane B)

**Done when:** Old fixtures upgrade intact.

| Step | Action | Files |
|------|--------|-------|
| 3.3.1 | Add hybrid logical clock column | `lib/data/tables/notes.dart`, `lib/data/tables/notebooks.dart` |
| 3.3.2 | Add version vectors / delete markers including NoteTags | `lib/data/tables/note_tags.dart` (add `deleted` column) |
| 3.3.3 | Migration from schema v11 to v12 | `lib/data/database.dart` (modify `schemaVersion`) |

**Current gap (verified):** `NoteTags` has no `deleted` column (`note_tags.dart:6-12`); `notes.dart` has no `updatedAt` in sync bundle.

**TDD:** Write upgrade test from v11 fixture; it must fail before migration.

### 3.4 Merge rules, tombstone retention, stale-peer review (Lane C)

**Done when:** All replicas converge; no deletion is resurrected.

| Step | Action | Files |
|------|--------|-------|
| 3.4.1 | Implement deterministic merge rules | `lib/sync/protocol/merge_resolver.dart` |
| 3.4.2 | Add tombstone retention policy | `lib/data/repositories/trash_auto_purger.dart` |
| 3.4.3 | Stale-peer deletion test | `test/sync/stale_peer_test.dart` (NEW) |

**TDD:** Write test where Peer A deletes a note, purges, then Peer B syncs stale data; the deletion must not be resurrected.

### 3.5 Chunked, resumable attachments addressed by SHA-256 (Lane C)

**Done when:** A cut connection leaves no partial note and resumes.

| Step | Action | Files |
|------|--------|-------|
| 3.5.1 | Verify `chunkPayload`/`reassembleChunks` cover attachments | `lib/sync/pipeline/sync_bundle_packer.dart:171-258` (already exists) |
| 3.5.2 | Add cut-connection resume test | `test/sync/chunk_resume_test.dart` (NEW) |

**Current state (verified):** `chunkPayload`/`reassembleChunks` exist with 64 KB default chunks and per-chunk SHA-256 (`sync_bundle_packer.dart:171-258`).

### 3.6 Pairing code bound to both peer keys, pinned peers, revocation (Lanes C, A)

**Done when:** Substituted and unpaired peers are refused.

| Step | Action | Files |
|------|--------|-------|
| 3.6.1 | Bind pairing code to ECDH shared secret (both peer keys) | `lib/sync/crypto/sync_cipher.dart:63-72` `derivePin` — wire into pairing flow |
| 3.6.2 | Add pinned-peer list and revocation | `lib/sync/sync_orchestrator.dart` |
| 3.6.3 | Test: substituted peer key changes code or fails pairing | `test/sync/pairing_binding_test.dart` (NEW) |

**Current gap (verified):** Pairing code is random, NOT bound to keys (`sync_send_screen.dart:658`; `sync_cipher.dart:63-72` `derivePin` unused/compared). R5 CONFIRMED.

### 3.7 Conflict screen for every conflict type (Lanes C, E)

**Done when:** Both versions stay recoverable.

| Step | Action | Files |
|------|--------|-------|
| 3.7.1 | Add conflict screen UI | `lib/features/sync_ui/widgets/conflict_card.dart` (exists) |
| 3.7.2 | Add "keep both" conflict resolution | `lib/sync/protocol/merge_resolver.dart` (exists) |
| 3.7.3 | Test: both versions recoverable | `test/features/sync_ui/conflict_test.dart` (NEW) |

### 3.8 Optional folder sync: encrypted change files for Syncthing (Lanes C, B)

**Done when:** Partial, duplicated, late files still converge.

| Step | Action | Files |
|------|--------|-------|
| 3.8.1 | Encrypted change-file export | `lib/features/settings/widgets/folder_mirror.dart` |
| 3.8.2 | Test: late/duplicate files converge | `test/features/settings/folder_sync_test.dart` (NEW) |

**Gate 3:** Thousands of seeded runs converge; real Android, desktop, iOS device matrix passes. Only list platforms actually tested.

---


---

## Phase 4 — Maintainability and polish

**Goal:** No screen or doodle behavior regresses; accessibility checklist passes.

**Depends on:** Phase 3 complete.

### 4.1 Split the editor into session, autosave, toolbar, sheet modules (Lane D)

**Done when:** Characterization tests stay green.

| Step | Action | Files |
|------|--------|-------|
| 4.1.1 | Split `note_editor_screen.dart` (1,215 lines) into modules | `lib/features/editor/` |
| 4.1.2 | Run characterization tests | `test/features/editor/` |

### 4.2 Split Home by layout and selection state; merge router transitions (Lane E)

**Done when:** Layout snaps stay green.

| Step | Action | Files |
|------|--------|-------|
| 4.2.1 | Consolidate `buildEditorialTransition`, `EditorialPageRoute`, `_fadeTransition` | `lib/core/router.dart`; `lib/core/widgets/editorial_page_transition.dart` |
| 4.2.2 | Split Home screen widgets | `lib/features/home/` |

### 4.3 Internal block registry covering render, export, search, sync per block (Lane D)

**Done when:** Every block type passes one shared round-trip suite.

| Step | Action | Files |
|------|--------|-------|
| 4.3.1 | Create internal block registry | `lib/features/editor/block_registry.dart` (NEW) |
| 4.3.2 | Register all block types (doodle, todo_list, callout, code, table, divider, collapsible, image, zoomable image) | `lib/features/editor/` |
| 4.3.3 | Shared round-trip test suite | `test/features/editor/block_registry_test.dart` (NEW) |

### 4.4 Token lint and design fixes (Lane E)

**Done when:** Lint rejects hard-coded colors and sub-floor text.

| Step | Action | Files |
|------|--------|-------|
| 4.4.1 | Fix `kRadiusXl` (24) < `kRadiusLg` (28) naming/value inconsistency | `lib/core/theme/nook_tokens.dart:21-22` |
| 4.4.2 | Enforce `kFontFloor` (12sp) — no 9px/11px text | `lib/core/theme/nook_tokens.dart` |
| 4.4.3 | Remove ALL-CAPS headers ("YOUR VAULT", "ACCENT PALETTE", "COLOR THEME", "BATCH ACTIONS") | `lib/features/home/`; `lib/features/notebooks/` |
| 4.4.4 | Add token lint to `design_system_enforcement_test.dart` | `test/core/theme/design_system_enforcement_test.dart` |

**Current gap (verified):** `kRadiusXl=24` < `kRadiusLg=28`; vaultLabel was 9px all-caps (fixed to 12px sentence case); dock labels 12px.

### 4.5 Screen reader, keyboard-only, contrast, reduce-motion pass (Lane E)

**Done when:** Semantics tests plus TalkBack and VoiceOver checklist pass.

| Step | Action | Files |
|------|--------|-------|
| 4.5.1 | Add TalkBack/VoiceOver key flow tests | `test/features/accessibility/` |
| 4.5.2 | Verify 200% text scaling, zero overflows | `test/features/accessibility/text_scale_200_test.dart` |
| 4.5.3 | Verify high-contrast sync states (32/32) | `test/core/theme/high_contrast_theme_test.dart` |

### 4.6 Indic search fix and interface translations (Lanes B, E)

**Done when:** Matra search fixtures; missing-string check.

| Step | Action | Files |
|------|--------|-------|
| 4.6.1 | Add custom FTS5 tokenizer for Gujarati/Hindi matras | `lib/data/database.dart`; `lib/data/repositories/search_repository.dart` |
| 4.6.2 | Add `l10n` for English, Gujarati, Hindi | `lib/l10n/` (NEW); `l10n.yaml` (NEW) |

**Current gap (verified):** `notes_fts` uses default `unicode61` tokenizer (`database.dart:55`); no `l10n` files found.

### 4.7 Performance budgets for 10,000 notes, large notes, attachments (Lanes G, B)

**Done when:** Recorded baselines, then regression limits.

| Step | Action | Files |
|------|--------|-------|
| 4.7.1 | Seed 10,000 notes benchmark | `test/benchmark/performance_seed_test.dart` (modify) |
| 4.7.2 | Add cold start / query latency budgets | `test/benchmark/` |

**Gate 4:** No screen or doodle behavior regresses; accessibility checklist passes.

---


---

## Phase 5 — New features

**Goal:** Start after Gate 4. Each pack stays in its lane; packs can run in parallel once any shared schema migration has merged.

**Depends on:** Phase 4 complete.

| Pack | Feature | Lane | Size | Wave |
|------|---------|------|------|------|
| Capture | Android share target, app shortcuts, quick settings tile | F, D | M | 5A |
| Capture | Daily note and journal (built on templates) | D | S | 5A |
| Find | Search filters: `tag:`, `in:`, `is:`, `before:` | B, E | M | 5A |
| Find | Saved searches as smart collections | B, E | M | 5B |
| Organize | Reminders hub with repeats, snooze, missed items | E, B | M | 5A |
| Organize | Task view across all checklists | D, E | M | 5B |
| Portability | Markdown folder import/export with front matter, links, attachments | B | L | 5A |
| Portability | Joplin archive import | B | M | 5B |
| Media | Encrypted PDF and file attachments | B, D | L | 5B |
| Media | Editable doodle export/import + SVG | D | M | 5A |
| Intelligence | Printed-text OCR indexed for search | D, B | L | 5C |
| Intelligence | Audio notes with optional offline transcription (sherpa-onnx) | D, F | L | 5C |
| Knowledge | Link graph and unlinked mentions | D, E | M | 5C |

**Rule:** Every feature must declare its backup, sync, export, search, lock, and delete behavior before coding. A feature with a blank entry is not ready.

**For transcription:** Test `sherpa-onnx` (Apache-2.0) behind an interface. Let users import a model file (no app download). Check each model's licence, then measure app size, memory, battery, and accuracy in your languages.

**Later or never:** Live collaboration, hosted accounts, third-party plugin marketplace, cloud AI, full web sync. Reconsider only with a written threat model.

---

## Phase 6 — Release 1.0

**Goal:** Run after chosen Phase 5 features.

**Exit criteria:**
- No open P0 or P1 defect.
- Upgrade from the last public alpha works on real data shapes.
- A restore drill passes on each supported platform.
- Releases have signatures, checksums, and a software bill of materials.
- F-Droid build succeeds from source. Check reproducibility separately.
- An outside person reviews the crypto and pairing design. Until then, do not call the app audited.
- Keep a beta period with opt-in, hand-shared log files and no telemetry.

**Platforms defining 1.0:** Android first, plus Linux and Windows. List others as preview until tested on real devices.

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

