# Nook Sync Protocol v2 Specification

## Wire Envelope (`SyncMessage`)
`[4-byte big-endian length N][32-byte SHA-256 checksum][CBOR payload]`
- `protocolVersion`: `1` (`SyncMessage.currentProtocolVersion`)
- `schemaVersion`: `7` (`SyncMessage.currentSchemaVersion`)
- `SyncCapabilityNegotiator.negotiateMessage` enforces compatibility and refuses unknown future versions without mutating local state.

## Field Matrix (`MergeResolver.syncFieldMatrix`)

| Column / Entity | Synced? | Rationale |
|---|---|---|
| `Notes.id`, `title`, `type`, `deltaContent`, `plainText` | Synced | Core note content |
| `Notes.colorSeed`, `fontStyle`, `pinned`, `archived` | Synced | User presentation & organization |
| `Notes.deleted`, `deletedAt`, `syncVersion`, `deviceOriginId`, `hlc`, `updatedAt` | Synced | Deterministic merge & tombstone propagation |
| `Notes.locked` | Synced (opt-in only; `includeLocked = false` by default) | Locked notes excluded from default bundles |
| `Notebooks.id`, `name`, `colorSeed`, `icon`, `parentId`, `hlc` | Synced | Collection hierarchy |
| `NoteTags.noteId`, `tagId`, `deleted`, `deletedAt` | Synced | Tag associations & delete tombstones |
| `NoteRevisions` | Local-only | Per-device autosave history |
| `TrustedDevices`, `SyncLog` | Local-only | Device-local trust & audit state |
| `db_encryption_key`, `vault_wrapped_dek` | Never synced | Device-local cryptographic keys |

## Chunked Resumable Transfers
Large payloads/attachments are split into 64 KB `PayloadChunk`s with per-chunk SHA-256 integrity (`SyncBundlePacker.chunkPayload` / `reassembleChunks`).

## Key-Bound Pairing
`SyncCipher.deriveKeyBoundPairingCode` binds the 6-digit visual pairing code to both peers' public keys and session nonce via SHA-256 so a MITM key substitution changes the code.
