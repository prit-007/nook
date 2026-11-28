# Nook Security Policy & Threat Model

> **Your notes. Your device. Yours.**
> Nook is built on the principle that your private notes should never leave your physical control without your explicit, authenticated consent. There are no user accounts, no cloud servers, and no telemetry services.

---

## 1. What Nook Protects, and What It Doesn't

### What Nook Protects

| Attack Vector | Defense Mechanism | Details |
|---|---|---|
| **Stolen or discarded storage media** | SQLCipher Database Encryption (AES-256-CBC) | All tables, plain text, and FTS5 search indexes are stored in a SQLCipher encrypted database file with 4096-byte page size and HMAC integrity checks. |
| **Extraction of DB key via platform backups or root access** | Vault Password DB-Key Wrapping (C2) | When a vault password is set, the Data Encryption Key (DEK) is wrapped using an AES-256-GCM Key Encryption Key (KEK) derived via PBKDF2-HMAC-SHA256 (100,000 iterations). Plaintext keys are wiped from platform storage. |
| **Lost vault password** | 24-Word BIP-39 Recovery Key | A standardized 24-word mnemonic can unwrap the DEK independently of the password. Setup enforces a 3-word verification challenge. |
| **Shoulder surfing & casual snooping** | Biometric Gate & 6-Digit PIN | App startup and resume require biometric authentication or salted PBKDF2 PIN verification. Background blur (`FrostedShield`) hides content. |
| **Sensitive notes in public environments** | Per-Note Locking | Individual notes can be locked behind re-authentication; content and thumbnails are obscured in home grids and widgets. |
| **Screen recording, screencasts, and app switchers** | `FLAG_SECURE` Protection | Screenshot blocking prevents recents snapshots, third-party screen recorders, and accidental captures. Enabled automatically on recovery key display. |
| **Network eavesdropping / coffee shop Wi-Fi** | libp2p Peer-to-Peer Noise Protocol | LAN sync uses Noise protocol encryption (`XX` handshake) and Yamux stream multiplexing over UDX (UDP). Payloads are CBOR-encoded with SHA-256 integrity verification. |
| **Unsolicited sync transfers** | Mutual 6-Digit Pairing Code | Devices verify a 6-digit numeric code on both screens before any payload transfer begins. Incoming requests can be rejected or timed out. |
| **Data lock-in & vendor hostage** | FOSS Portable Exports | 100% offline bulk zip export (Markdown, HTML, PDF) with relative media assets and zero proprietary formats. |

---

### What Nook Does NOT Protect (Honest Limits)

Security systems must be transparent about their threat model boundaries:

1. **Root / Jailbreak Compromise**: If an attacker has root or kernel access to your operating system, they can inspect memory or hook system calls during an active session while the database is unlocked.
2. **Compromised Keyboards / Input Method Editors**: If a user uses a malicious third-party keyboard that logs keystrokes, the keyboard can capture text as you type. Always use trusted or open-source keyboards (e.g. OpenBoard, FUTO).
3. **Physical Coercion / Shoulder Surfing While Unlocked**: Nook offers configurable auto-lock timers, but if the device is snatched while actively unlocked with a note open, the on-screen content is visible.
4. **Total Credential Loss**: If you enable vault password wrapping and lose **both** your vault password and your 24-word recovery key, **your notes cannot be recovered**. Nook has no backdoors and no password reset servers.

---

## 2. Cryptographic Architecture

### SQLCipher Storage
- **Algorithm**: AES-256-CBC
- **Key Derivation**: PBKDF2 with HMAC-SHA512
- **Page Size**: 4096 bytes
- **Integrity**: Per-page HMAC validation

### Vault Password & Key Wrapping (C2)
- **KDF**: PBKDF2-HMAC-SHA256 with 100,000 rounds and a 16-byte cryptographically secure random salt (`dart:math` `Random.secure`).
- **Key Wrap**: AES-256-GCM with a unique 12-byte initialization vector (IV) per wrap operation.
- **Atomic Operations**: New wrapped envelopes are written and verified before the unwrapped plaintext DEK is purged from `flutter_secure_storage`. Interrupted operations automatically recover on the next boot (`recoverInterruptedWrap`).

### Peer-to-Peer Sync Transport
- **Handshake**: Noise Protocol Framework (`Noise_XX_25519_ChaChaPoly_SHA256`)
- **Transport**: UDX (Micro Transport Protocol over UDP)
- **Multiplexing**: Yamux
- **Discovery**: Local multicast DNS (`_syncnotenet._udp`) and Android Wi-Fi Direct P2P. Public STUN/TURN/relay servers are never queried.

---

## 3. Reporting a Vulnerability

If you discover a security vulnerability in Nook:
1. **Do not open a public issue.**
2. Send an encrypted email to the maintainer or submit a report via GitHub Security Advisories.
3. Include a description of the issue, affected versions, and proof-of-concept steps.
4. We commit to acknowledging receipt within 48 hours and providing a remediation timeline.
