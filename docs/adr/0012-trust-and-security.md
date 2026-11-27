# 12. Trust and Security Architecture (Recovery Key, KDF, Locked-Note Protection)

Date: 2026-11-27

## Status
Accepted (with Phase 1 hardening roadmap)

## Context
Nook is an offline-first, end-to-end encrypted local-first notes application. Users store sensitive personal notes, checklists, doodles, and attachments on their devices and synchronize them peer-to-peer over a LAN/Wi-Fi Direct link without any cloud server or user account.

Three foundational trust decisions govern how Nook protects data at rest and during user interaction:
1. **Key Derivation Function (KDF)** for PINs and vault passwords.
2. **Data Encryption Key (DEK) wrapping and 24-word recovery key** so users can gate database decryption behind a memorable secret without losing their vault if they forget it.
3. **Locked-note isolation** so individually locked notes never leak through secondary surfaces (search indexes, previews, home widgets, reminders, exports, or sync).

## Decision

### 1. KDF Choice & Migration Path
- **Current implementation (`lib/core/security/kdf.dart`)**: PBKDF2-HMAC-SHA256 with `defaultPbkdf2Iterations = 100000`, 16-byte random base64url salt, and 32-byte derived output.
  - Stored PIN format: `salt:iterations:derived` (where `derived` is `List<int>.toString()` for backward compatibility).
  - Vault DEK wrapping (`DekManager`): derives a 256-bit Key Encryption Key (KEK) via PBKDF2-HMAC-SHA256 and wraps the 32-byte SQLCipher DEK with AES-256-GCM (`salt`, `iterations`, `nonce`, `ciphertext`, `mac` JSON envelope).
- **Planned Phase 1 upgrade**: Migrate to versioned KDF envelopes (`v2$argon2id$...`) using memory-hard Argon2id (and higher PBKDF2 fallback where needed) with atomic migration and rollback safety (`DekManager.recoverInterruptedWrap`).

### 2. Recovery Key Design
- **24-word BIP-39 mnemonic** (`lib/core/security/recovery_key_provider.dart`): generated using `Random.secure()` during onboarding or vault setup.
- **Verification challenge**: `RecoveryKeyDialog` (`lib/features/security/recovery_key_dialog.dart`) requires the user to verify 3 randomly chosen word indices before continuing, and enables `WindowManager.flagSecure` to block screenshots/screen recording while the key is displayed.
- **DEK backup**: When a vault password is set with recovery words, `DekManager.wrapDekWithPassword` stores a second AES-256-GCM wrapped copy of the DEK under `vault_recovery_wrapped_dek` derived from the normalized recovery phrase.
- **Clipboard hygiene**: Copying the recovery key starts a 60-second timer (`_clipboardClearTimer`) that overwrites the system clipboard with an empty string.

### 3. Locked-Note Protection
- Locked notes (`Note.isLocked == true`) require biometric/PIN/vault unlock before viewing or editing.
- Locked notes must be excluded from:
  - Full-text search indexing (`notes_fts`) and search results.
  - Unauthenticated card previews (`NoteCard`, `NoteBannerCard`, `NoteDoodleCard`).
  - Doodle thumbnails cached on disk.
  - Home-screen pinned widgets (`HomeWidgetService.syncPinnedNotes`).
  - Lock-screen notification bodies (`LocalReminderScheduler`).
  - Unprotected local revision history, bulk exports, and unverified sync surfaces.

## Consequences
- **Zero-server recovery**: Users can recover their encrypted SQLCipher database with the 24-word mnemonic without any account or escrow server.
- **Atomic wrap safety**: Interrupted wraps are detected and either completed or rolled back on next startup (`DekManager.recoverInterruptedWrap`).
- **Clear hardening backlog**: Phase 1 tracks the Argon2id upgrade, full locked-note leak sweep, `secure_delete` pragma + post-purge `VACUUM`, and biometric-bound keystore verification.
