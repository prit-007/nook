# Nook Threat Model — What Nook Protects, and What It Doesn't

Last updated: 2026-11-27

## 1. Security Philosophy
Nook is an offline-first, local-first notes application. There are **no cloud servers, no user accounts, no telemetry, and no analytics**. Every security guarantee is designed around protecting data stored on the user's own devices and transmitted directly between user-owned devices on a local network.

---

## 2. Assets to Protect
1. **Note contents** (rich-text JSON, titles, checklists, doodle strokes, image/file attachments).
2. **Metadata** (notebooks/collections, tags, reminders, backlinks, revision history).
3. **Cryptographic keys** (SQLCipher 32-byte DEK, vault password KEK, 24-word recovery key, libp2p Ed25519 device identity).
4. **Locked notes** (`isLocked == true`), which carry an extra authentication boundary even when the app is open.

---

## 3. What Nook Protects Against

### 3.1 Physical Device Theft / Offline Disk Forensics
- **Encrypted local database**: All notes, notebooks, tags, attachments metadata, revisions, and reminders live in an encrypted SQLCipher database (`lib/data/database.dart`).
- **Key storage**: When no vault password is set, the 32-byte SQLCipher DEK is stored in the platform keystore/keychain via `flutter_secure_storage` (`lib/core/security/secure_kv_store.dart`).
- **Vault password wrapping (C2)**: When a vault password is set (`DekManager`), the plaintext DEK is deleted from secure storage and replaced with an AES-256-GCM wrapped envelope (`vault_wrapped_dek`) keyed by PBKDF2-HMAC-SHA256 (100,000 iterations; Argon2id planned in Phase 1). Without the vault password (or 24-word recovery key), offline extraction of the `.db` file and keystore preferences cannot decrypt the database.
- **Cold-start gate**: `VaultDbGateScreen` blocks database opening until the DEK is unwrapped.

### 3.2 Shoulder Surfing & Screen Capture
- **App lock**: Biometric (`local_auth`) and PIN gates protect app entry.
- **Screenshot protection**: `WindowManager.flagSecure` is enabled on sensitive dialogs (`RecoveryKeyDialog`) and is being extended to an app-wide toggle + background auto-lock in Phase 1.5.

### 3.3 Network Eavesdropping & Rogue Peers (Peer Sync)
- **No cloud exposure**: Notes never touch third-party servers.
- **Authenticated encrypted transport**: Peer sync uses `dart_libp2p` over UDX with Noise encryption and Yamux multiplexing, plus per-message SHA-256 integrity checks (`lib/sync/protocol/sync_message.dart`).
- **Explicit pairing**: Transfers require manual user initiation and mutual verification of a pairing code (`SyncPairingScreen`). Unsolicited dials are rejected, and AutoNAT public probing is disabled (`Reachability.private`).

### 3.4 Recovery Key & Clipboard Exposure
- **Recovery key storage**: Nook does not store the 24-word recovery phrase in plaintext. It stores only an AES-256-GCM wrapped copy of the DEK (`vault_recovery_wrapped_dek`) derived from the phrase.
- **3-word verification**: Onboarding/setup verifies 3 random words so users actually record the phrase.
- **Clipboard hygiene**: Copying the recovery key triggers a 60-second automatic clipboard clear (`RecoveryKeyDialog`). Phase 1.5 extends clipboard clearing to copied locked-note text and passwords.

### 3.5 Locked-Note Information Leakage (Phase 1.2 Hardening Target)
Locked notes must not leak plaintext or visual previews through secondary surfaces:
- **FTS5 search index (`notes_fts`)** and **Search results screen**
- **Card previews** (`NoteCard`, `NoteBannerCard`, `NoteDoodleCard`)
- **Doodle thumbnails**
- **Home-screen widgets** (`HomeWidgetService.syncPinnedNotes`)
- **Reminder notification text** (`LocalReminderScheduler`)
- **Revision history** (`note_revisions`)
- **Bulk export** (Markdown / HTML / PDF)
- **Sync bundle payload** (`SyncBundlePacker`)

*(Phase 1.2 audits and enforces locked-note exclusion across all 9 surfaces with dedicated regression tests.)*

### 3.6 Deleted Data Forensics (Phase 1.4 Hardening Target)
- Soft-deleted notes remain in the Bin for 30 days (`TrashAutoPurger`).
- Phase 1.4 enables SQLite `PRAGMA secure_delete = ON` and runs `VACUUM` after trash purge so deleted pages do not linger in SQLite freelist pages.

---

## 4. What Nook Does NOT Protect Against

1. **Compromised OS / Rooted or Jailbroken Device at Runtime**:
   If malware has root privileges or memory-inspection access while the vault is unlocked in RAM, it can read the in-memory DEK or decrypted note content.
2. **Weak User Passwords / PINs**:
   A short 4-digit PIN or weak dictionary vault password can be brute-forced offline if an attacker obtains both the wrapped DEK blob and the salt. Use a strong passphrase and enable Argon2id once Phase 1.1 lands.
3. **Biometric Bypass on Unbound Keystores**:
   Until Phase 1.3 enforces hardware-backed `UserAuthenticationRequired` / `LAPolicy.deviceOwnerAuthentication` binding on the keystore key itself, a rooted attacker who patches the UI biometric gate could read an unwrapped DEK from keystore storage if no vault password is set.
4. **Unencrypted User Exports**:
   Exporting notes to Markdown, HTML, PDF, or plaintext `.zip` files writes unencrypted files to user-chosen storage.
5. **Physical Loss of Both Device and Written Recovery Key**:
   Anyone possessing the 24-word recovery key and the device's `vault_recovery_wrapped_dek` blob can unwrap the DEK and decrypt the database.
6. **System Speech Recognition Services (Non-F-Droid Builds)**:
   On standard builds where the user opts in to voice capture (`VoicePreference`), `speech_to_text` delegates to the OS-configured speech service, which may be cloud-backed depending on the user's device settings. F-Droid builds compile with `--dart-define=NOOK_FDROID=true` and strip `RECORD_AUDIO`.
