# 1. Record architecture decisions

Date: (fill in on day one)

## Status
Accepted

## Context
We need to record the architectural decisions made on this project so that
future-us (or contributors) understand *why*, not just *what*, months later.

## Decision
We will use lightweight Architecture Decision Records, one Markdown file per
decision, numbered sequentially in `docs/adr/`.

## Notes for the first real entries to write once coding starts
- `0002-local-database-drift-over-isar-hive.md` — Hive and Isar are effectively
  unmaintained by their original author as of 2026; Drift is the actively
  maintained, type-safe, reactive, cross-platform default.
- `0003-editor-appflowy-editor-over-flutter-quill.md` — flutter_quill is a
  linear Delta model; our notes mix text, checklists, doodles, and images as
  first-class blocks, which needs a node-tree document model. AppFlowy itself
  migrated away from Quill for the same reason.
- `0004-sync-transport-nearby-service.md` — direct P2P over Wi-Fi
  Direct/Nearby Connections, no relay server, explicit user-initiated pairing
  only (numeric code confirmation), no silent background sync in v1.
- `0005-encryption-sqlcipher-plus-secure-storage.md` — DB encrypted at rest via
  SQLCipher; encryption key generated once and held in platform
  keystore/keychain via flutter_secure_storage, never hardcoded.
