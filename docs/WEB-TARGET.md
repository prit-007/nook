# Web Target Scope Decision — Phase 7.2

## Decision
Keep Web strictly as a **read-only / companion preview target** (`lib/features/web/web_companion_app.dart`), not a primary encrypted vault target.

## Rationale
1. **No libp2p UDX / mDNS P2P Sync**: Browsers cannot open raw UDP/UDX sockets or bind mDNS multicast listeners, so serverless LAN/Wi-Fi Direct sync is unavailable on Web.
2. **Weaker Storage Encryption**: Browsers lack hardware-backed OS keystores (`Android Keystore`, `iOS/macOS Keychain`, `libsecret`) and native SQLCipher (`PRAGMA key`).
3. **Clear Scope**: Mobile (Android/iOS) and Desktop (Linux/macOS/Windows) remain the full-featured encrypted vault targets; `WebCompanionApp` documents the companion/read-only boundary cleanly.
