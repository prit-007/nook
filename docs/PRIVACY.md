# Nook Privacy Policy

Last updated: 2026-11-27

## Zero Cloud, Zero Telemetry, Zero Accounts
Nook is an offline-first, local-first notes application.
- **No servers**: Nook does not operate any cloud backend, sync relay, or account system.
- **No analytics or tracking**: Nook contains zero analytics SDKs, crash reporters, or advertising libraries (verified on every CI run via `tool/licence_audit.dart`).
- **No startup network calls**: Nook makes zero outbound network requests on cold start, during onboarding, or in the background (see ADR 0011).

## Encryption & Local Storage
- All notes, notebooks, tags, reminders, and metadata are stored locally in an encrypted SQLCipher database.
- Database keys are stored in the platform keystore/keychain (`flutter_secure_storage`) or wrapped with your vault password using Argon2id + AES-256-GCM (`DekManager`).
- Encrypted `.nookbackup` archives use Argon2id + AES-256-GCM.

## Peer-to-Peer Sync
- Network sockets are opened **only** when you explicitly start Peer Sync (Send/Receive).
- Sync runs directly between your devices over your local network (libp2p UDX + Noise encryption) or Wi-Fi Direct, requiring mutual pairing code confirmation.

## Optional Permissions (F-Droid vs Standard Builds)
- **Camera**: Used only when scanning a peer's QR pairing code.
- **Notifications**: Used only for local reminders scheduled by you (`NotificationVisibility.private` hides sensitive text on the lock screen).
- **Microphone (`RECORD_AUDIO`)**: Completely absent from F-Droid builds (`--dart-define=NOOK_FDROID=true`) and disabled by default on standard builds until explicitly opted in.
