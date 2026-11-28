# Nook Backup v1 Specification (`.nookbackup`)

## Envelope Format (JSON)
```json
{
  "v": 2,
  "kdf": "v2$argon2id$m=19456,t=2,p=1",
  "salt": "<base64url 16B random salt>",
  "nonce": "<base64url 12B AES-GCM nonce>",
  "ciphertext": "<base64url AES-256-GCM ciphertext>",
  "mac": "<base64url 16B AES-GCM authentication tag>"
}
```

## Key Derivation & Encryption
- **KDF**: Argon2id (`OWASP` interactive profile: `m=19456` KiB, `t=2`, `p=1`), 32-byte key output.
- **Cipher**: AES-256-GCM (`AesGcm.with256bits()`).
- **Tamper rejection**: Any wrong password, modified `ciphertext`, modified `mac`, truncated envelope, or unsupported `kdf` header throws `BackupAuthenticationException` without mutating the database.

## Lossless Payload Contents
- `notebooks` (including `parentId`, `colorSeed`, `icon`, `sortOrder`)
- `notes` (including `deltaContent`, `plainText`, `colorSeed`, `fontStyle`, `pinned`, `locked`, `archived`, `deleted`, `syncVersion`, `deviceOriginId`)
- `checklistItems`
- `tags`
- `attachments` (metadata + base64-encoded file bytes / doodle stroke JSON)
- `reminders`
- `templates`
- `noteRevisions`
- `noteLinks`
- Device-local cryptographic keys (`db_encryption_key`, `vault_wrapped_dek`, libp2p Ed25519 identity) are **never** included.
