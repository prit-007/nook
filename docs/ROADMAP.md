# Nook Public Roadmap

> **Your notes. Your device. Yours.**
> Nook is an offline-first, GPL-3.0 encrypted notes app with zero cloud accounts, zero telemetry, and peer-to-peer LAN sync.

---

## Shipped (v0.9.7 — Epics #46, #57, #62 Closed)

### Trust & Security (#46, #57)
- **Encrypted local vault**: Drift + SQLCipher (`PRAGMA key`) with platform keystore protection (`flutter_secure_storage`) and biometric gate (`local_auth`).
- **Vault password & C2 DEK wrapping (`#56`, `#57`)**: Optional vault password that gates locked notes and wraps the SQLCipher Data Encryption Key (DEK) with PBKDF2-HMAC-SHA256 + AES-256-GCM (`DekManager`), gated at cold start via `VaultDbGateScreen`.
- **24-word BIP-39 recovery key**: Standardized mnemonic generation/validation with recovery-wrapped DEK fallback and mandatory 3-word verification challenge.
- **Privacy explainer (`#49`)**: Honest in-app permissions & cryptography audit (`Settings → Privacy`).
- **F-Droid compliance & Voice Gating**: 100% offline-first startup, zero proprietary Play Services / ML Kit blobs, voice dictation disabled by default with offline engine guidance, split-per-ABI reproducible builds.

### Productivity, Editor & Architecture (#62)
- **Archive feature**: Schema v10 note archiving separate from 30-day auto-purged Bin.
- **Editor polish**: Quiet "Saved" status indicator and explicit `NoteFontStyle` (sans, serif, mono).
- **Doodle engine**: Tapered stroke ends and cached layer rendering (`bakedPicture`).
- **Rich block editor**: `appflowy_editor` with headings, checklists, quotes, callouts, collapsible sections, tables, code blocks, and dividers.
- **Samsung Notes-caliber doodle & shape assist**: Cardinal/45° snapping, arrowheads, rotated rectangles/squares, triangles, 5-point stars, live eraser ring cursor, auto-extending paper.
- **Note linking & `[[wiki]]` autocomplete (`#53`, `#62`)**: Inline `[[query` suggestion bar, `nook://note/<id>` links, and incoming backlinks panel.
- **Local version history (`#52`)**: 10-minute autosave buckets, up to 200 revisions per note, one-tap restore.
- **Local reminders (`#54`)**: Offline scheduled notifications via `flutter_local_notifications`.
- **Note templates (`#58`)**: Reusable note structures + built-in templates.
- **Command palette (`#59`)**: Global `Ctrl/Cmd+K` fuzzy command launcher.
- **FTS5 grouped search (`#48`)**: Full-text search grouped by match context + quick filter chips.
- **Configurable Bin retention (`#51`, `#62`)**: 4-tab Bin with `7 / 14 / 30 / 60 / 90 days` or `Never` auto-purge setting.
- **Portable exports & imports (`#55`, `#60`, `#61`, `#62`)**: Markdown/HTML/PDF bulk `.zip` export, single-note Share as HTML & Share as PDF, and Markdown/Keep/Evernote/Notesnook import.
- **Home screen widgets (`#62`)**: Android `NookWidgetProvider` (`home_widget`) syncing pinned non-locked notes + quick-capture deep links (`nook://capture`).
- **Voice-to-text capture (`#62`)**: On-device speech dictation (`speech_to_text`) in Home quick-capture and editor slash menu (`VoiceCaptureSheet`).
- **FOSS OCR scan-to-note (`#62`)**: Offline optical character recognition (`LocalFossOcrService` + `OcrScanSheet`) via system `tesseract` on desktop or `com.nook/ocr` channel without proprietary Google Play Services.
- **Flutter Web read/export-only companion (`#62`)**: Browser-based reader (`WebCompanionApp` via conditional `main_web.dart`) for `.zip`, `.nook`, and `.md` exports.
- **Peer-to-peer LAN sync**: `dart_libp2p` (Noise + Yamux over UDX/UDP), mDNS discovery, Wi-Fi Direct cross-network discovery, 6-digit mutual pairing confirmation, and conflict resolution UI.

---

## Closed Epics Summary

- **Issue #46 (Notesnook-inspired trust & productivity campaign)**: CLOSED. All child issues (#47-#61) verified, implemented, and covered by automated tests.
- **Issue #57 (Vault password DB-key wrapping C2)**: CLOSED. Atomic DEK wrapping via PBKDF2-HMAC-SHA256 + AES-256-GCM, cold-boot unwrap via `VaultDbGateScreen`, 3-word verified 24-word recovery key, and crash recovery.
- **Issue #62 (Phase 7.4 deferred launch track)**: CLOSED. All post-launch items (widgets, voice gating, templates, web companion, FOSS OCR, PDF exports, wiki link autocomplete, configurable bin) completed.

---

## Explicit Non-Goals

- Cloud accounts, subscriptions, or paid feature tiers
- Third-party servers or telemetry/analytics
- Realtime multi-user cloud collaboration
- Browser web clipper extensions
