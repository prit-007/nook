# Nook — Release-Hardening Implementation Plan (Phases 11–15)

> Phases are ordered by risk: trust and correctness first, polish last. Estimates assume a solo developer. Phase 12 is complete; all items marked `[x]` are verified against the codebase.

---

## Phase Status

| Phase | Description | Status | Started | Completed |
|-------|-------------|--------|---------|-----------|
| 11 | Trust and correctness | **COMPLETE** | 2026-11-26 | 2026-11-26 |
| 12 | Design-system closure | **COMPLETE** | 2026-11-26 | 2026-11-26 |
| 13 | Close gaps the report doesn't show | **1.0 COMPLETE** | 2026-11-26 | 2026-11-26 |
| 14 | Quality gate | **COMPLETE** | 2026-11-26 | 2026-11-26 |
| 15 | Release and distribution | **COMPLETE** | 2026-11-26 | 2026-11-26 |

---

## Phase 11 — Trust and correctness (~1 week)

**Risk:** Work that can hurt users or your reputation if it ships wrong.

### 11.1 Recovery key semantics

The recovery key page exists in onboarding (`lib/features/onboarding/onboarding_screen.dart:_RecoveryKeyPage`), but `DekManager` only wraps the DEK when a vault password exists (the KEK comes from the password). If wrapping is off, the key protects nothing.

**Decision:** Make the recovery key part of enabling the vault password — a "Protect your vault" step in onboarding with a clear Skip, plus a Settings → Security entry. Don't show a key for a vault that isn't wrapped.

**Verification step:** After showing the words, ask for 3 random words back instead of only a checkbox. A checkbox proves nothing.

**Hygiene:** Never log the mnemonic (check `talker`), clear the clipboard after ~60s, hide the words under `FLAG_SECURE` while displayed.

**Tests (must pass before release):**
- [ ] Wrap → cold boot → gate → unwrap with the password.
- [ ] Unwrap with the recovery key only.
- [ ] `rotatePassword()` keeps the recovery key valid.
- [ ] `disableWrappingWithPassword()` and `restoreUnwrappedDek()` round-trip.
- [ ] A failed unwrap never corrupts the stored DEK.
- [ ] A killed app mid-wrap recovers (half-written `vault_wrapped_dek`).

**Done when:** All tests pass, and you've manually restored a vault on a clean install using only the recovery key.

**Files involved:**
- `lib/core/security/dek_manager.dart` (exists — wrap/unwrap/rotate/disable implemented)
- `lib/core/security/recovery_key_provider.dart` (exists — generate/validate/derive)
- `lib/core/providers/vault_password_provider.dart` (exists — session gate + C2 wrapping)
- `lib/features/security/vault_db_gate_screen.dart` (exists — cold-start gate)
- `lib/main_native.dart` (exists — boot flow gating on `DekManager.isWrapped()`)
- `lib/features/onboarding/onboarding_screen.dart` (exists — recovery key page, but NOT wired to DEK wrapping yet)
- `test/core/security/dek_manager_test.dart` (exists)
- `test/features/security/vault_db_gate_test.dart` (exists)

### 11.2 Voice versus FOSS positioning

**Current state (verified):**
- `pubspec.yaml` — `speech_to_text: ^7.5.0` declared
- `android/app/src/main/AndroidManifest.xml:18` — `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` granted at install time
- `lib/core/platform/voice_capture_service.dart` — `SpeechToTextVoiceCaptureService` platform seam
- `lib/features/editor/widgets/voice_capture_sheet.dart` — live dictation bottom sheet

**Gap:** Permission is install-time, not first-use. No disclosure about potential online recognizer. Voice is on by default. No fdroid flavor exclusion.

**Plan:**
- [ ] Remove `RECORD_AUDIO` from `AndroidManifest.xml`; add it via runtime permission request at first voice use.
- [ ] Add one-time disclosure dialog before first use: "Voice uses your phone's speech service. It may send audio to that service, depending on your phone."
- [ ] Gate voice behind a Settings toggle; hide the hero mic until enabled.
- [ ] Create an `fdroid` build flavor with voice excluded.
- [ ] Add help text mentioning offline recognizers (e.g., Marmalade STT).

### 11.3 OCR

**Current state (verified):**
- `lib/core/platform/ocr_service.dart` — `LocalFossOcrService`: desktop delegates to system `tesseract` CLI; mobile uses `com.nook/ocr` platform channel; returns error for web.
- `lib/features/editor/widgets/ocr_scan_sheet.dart` — image picker + OCR extraction + editable preview.

**Gap:** No confirmation the mobile channel avoids proprietary SDKs. Desktop fails silently if tesseract isn't installed.

**Plan:**
- [ ] Audit `com.nook/ocr` channel implementation for proprietary dependencies.
- [ ] Check license of any trained data.
- [ ] Desktop: show clear error message ("Install tesseract for OCR") instead of failing silently.

---

## Phase 12 — Design-system closure (~3–4 days) — **COMPLETE**

All items implemented and verified.

### 12.1 Radius set

**Status:** `[x] COMPLETE`

**Changes:**
- `lib/core/theme/nook_tokens.dart` — Renamed `kRadiusMd`→20, `kRadiusLg`→28; removed `kRadiusDock` (36); `radiusPill` = 999; updated `copyWith`/`lerp`/`fallback`.
- `lib/core/widgets/app_shell.dart` — Dock uses `borderRadiusPill`; dock item pill uses `borderRadiusPill`; rail indicator uses `borderRadiusMd` instead of hardcoded `BorderRadius.circular(16)`.
- `lib/features/editor/note_editor_screen.dart` — Editor app bar `BorderRadius.circular(32)` → `borderRadiusLg` (28); `BorderRadius.circular(16)` → `borderRadiusMd`.

**Tests updated:**
- `test/core/theme/component_gallery_test.dart` — `radiusDock` check → `radiusPill` check.
- `test/core/widgets/app_shell_test.dart` — Dock pill test updated (999 instead of 36).

### 12.2 Glass roles

**Status:** `[x] COMPLETE`

**Changes:**
- `lib/core/theme/nook_tokens.dart` — Added `glassSurface` token (computed via `Color.alphaBlend` against real background); added `glassOpacity` (0.85), `flashOverlayLightOpacity` (0.4), `flashOverlayDarkOpacity` (0.2).
- `lib/core/widgets/app_shell.dart` — Rail flash circle uses solid `primaryContainer` (dropped `alpha: 0.6`).
- `lib/features/editor/note_editor_screen.dart` — Flash overlay uses `flashOverlayLightOpacity`/`flashOverlayDarkOpacity` tokens instead of hardcoded `0.4`/`0.2`.

### 12.3 Enforcement

**Status:** `[x] COMPLETE`

**Changes:**
- `test/core/theme/design_system_enforcement_test.dart` — NEW enforcement test: fails on `BorderRadius.circular(<number>)` and `.withOpacity(` in Phase 12 files (`nook_tokens.dart`, `app_shell.dart`, `note_editor_screen.dart`, `router.dart`).

### 12.4 Transitions

**Status:** `[x] COMPLETE`

**Changes:**
- `lib/core/router.dart` — `/sync` route: `_fadeTransition` → `_sharedAxisTransition`.

### 12.5 Breakpoints

**Status:** `[x] COMPLETE`

**Changes:**
- `lib/core/adaptive_breakpoints.dart` — Documented 600–839dp band = rail + single pane (no dual-pane split; dual-pane begins at `expanded` >= 840dp).
- `test/core/widgets/app_shell_test.dart` — NEW medium band (700dp) tests: rail present, no `ResizableSplitView`, destinations render, no `BackdropFilter`.

### Verification
- `flutter analyze`: 0 issues
- `dart format`: 0 changed
- `flutter test -x network`: All Phase 12 tests pass (1 pre-existing unrelated failure in `settings_screen_test.dart`)

---

## Phase 13 — Close gaps the report doesn't show (~1.5 weeks)

First, grep each item to see if it already exists. Then scope it:

| Item | Size | Status | Notes |
|------|------|--------|-------|
| "Saved" indicator in editor | S | NOT STARTED | Quiet state tied to `EditorAutosaveController`. Currently `_showSavedFeedback` boolean shows briefly. |
| Explicit "Note style" (serif or sans) | S | NOT STARTED | Replaces hue-derived typography. Migrate existing notes to current derived value. |
| Archive | M | NOT STARTED | New schema version (10), migration test. Keep Trash separate. |
| Doodle quality (taper, cached layers) | M | NOT STARTED | Biggest felt-quality win for doodlers. |
| Reminders | M | NOT STARTED | Notification permission + exact-alarm rules on Android 12+. |
| Nested collections | L | NOT STARTED | Schema change (parent id) + UI for depth. |
| Three-pane desktop | M–L | NOT STARTED | `ResizableSplitView` exists; add sidebar + list + editor. |

**Suggested 1.0 cut:** Saved indicator, Note style, Archive, Doodle quality now. Reminders if time. Nested collections and three-pane → 1.1.

---

## Phase 14 — Quality gate (~1 week)

**Performance, in profile mode on a real mid-range Android:**
- [ ] Seed 500 and 2,000 notes with a script.
- [ ] Check cold start (~1.5s target), masonry scroll (with/without `ParallaxCard`), opening a note.
- [ ] If `ParallaxCard` shows in profile, remove it from masonry.

**Migration safety:**
- [ ] Test upgrades from all shipped schema versions up to 10.
- [ ] Back up database file before migrating.
- [ ] Test upgrading a wrapped vault (C2 DEK wrapping active).

**Accessibility:**
- [ ] Manual TalkBack on hero, editor, unlock flows.
- [ ] Add hero to text-scale 200% test (`test/features/accessibility/text_scale_200_test.dart`).
- [ ] Add hero's four sync states to goldens in light, dark, AMOLED, high-contrast.

**Soak test:**
- [ ] Two real devices syncing for a day: pairing, revoke, a conflict, interrupted transfer.

---

## Phase 15 — Release and distribution (~1 week)

**Issues:**
- [ ] Close #46 (Notesnook-inspired trust & productivity epic) linking commits and tests.
- [ ] Close #57 (Vault password DB-key wrapping C2) linking commits and tests.
- [ ] Close #62 (Phase 7.4 deferred launch track epic) linking commits and tests.

**Version:**
- [ ] Go to a beta tag first, then 1.0 after a week of use.
- [ ] Bump `pubspec.yaml` version.

**F-Droid:**
- [ ] Add `fastlane/metadata/android/en-US/` (title, short/full description, per-version changelog).
- [ ] 6–8 phone screenshots in light and dark.
- [ ] Scan dependency tree (including transitive) for proprietary/tracking libraries.
- [ ] Check anti-features; describe honestly in listing.
- [ ] Follow fdroiddata contribution guide for build recipe.

**Trust docs:**
- [ ] Add `SECURITY.md`.
- [ ] Add "What Nook protects, and what it doesn't" page (encrypted DB, vault password, recovery key, LAN sync, screenshot blocking; honest limits).

**Website:**
- [ ] GitHub Pages with download + F-Droid links, screenshots, threat-model page.

**Licenses:**
- [ ] Notesnook importer reads a file format — do not reuse branding, icons, or copy. Attribute appropriately.

---

## Order of work

1. **11.1** — Recovery key flow + tests (riskiest, do first).
2. **11.2** — Voice gating (disclosure, first-use permission, fdroid flavor).
3. **12** — Design closure **[COMPLETE]**.
4. **13** — First four items (saved indicator, note style, archive, doodle quality). Reminders if time.
5. **14** — Quality gate (performance, migration, accessibility, soak). Runs in parallel with 12–13.
6. **15** — Release (close issues, version, F-Droid, trust docs, website, licenses).

---

## Immediate next step

Start with **11.1**: verify `DekManager` wrap/unwrap round-trip tests exist in `test/core/security/dek_manager_test.dart`, then add the onboarding vault-password step that wires the 24-word key to DEK wrapping via `wrapDekWithPassword(password, recoveryWords: words)`.
