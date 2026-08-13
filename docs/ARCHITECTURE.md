# Nook — Architecture & Codebase Map

This is the **current-state** map of the code (not the future plan). If you want
to understand a patch, find a bug, or add a feature, start here. Product vision
lives in [`notes-app-masterplan.md`](notes-app-masterplan.md) and the schema/protocol
spec in [`notes-app-detailed-plan.md`](notes-app-detailed-plan.md).

---

## 1. The big picture

```
┌───────────────────────────── Nook app ─────────────────────────────┐
│                                                                     │
│  lib/core        app shell, router, theme, providers, platform      │
│                  bridges (window manager, nearby permissions)        │
│                                                                     │
│  lib/data        Drift DB + SQLCipher                               │
│   ├── tables/    notes, notebooks, tags, note_tags, checklist_items, │
│   │              attachments, sync_log                               │
│   └── repositories/  note, notebook, tag, checklist_item,           │
│                      attachment, doodle_storage, search, sync_log    │
│                                                                     │
│  lib/features    screens & widgets                                   │
│   ├── home/      notes grid, cards, search, filters                 │
│   ├── editor/    AppFlowy editor, checklist editor, doodle block    │
│   ├── doodle/    canvas, painter, strokes codec, thumbnail renderer │
│   ├── sync_ui/   pair/send/receive/transfer/conflict screens        │
│   ├── security/  biometric gate, lock screen, PIN                   │
│   ├── settings/  appearance, security, storage, about, sync devices │
│   ├── notebooks/ tags/ trash/ onboarding/                            │
│                                                                     │
│  lib/sync        peer-to-peer sync engine                            │
│   ├── protocol/  sync_bundle (CBOR), sync_message (wire envelope),   │
│   │              merge_resolver                                      │
│   ├── crypto/    identity_store (Ed25519 seed → stable peer id)      │
│   ├── discovery/ nook_mdns_discovery (own `_syncnotenet._udp` fork)  │
│   ├── sync_orchestrator.dart                                        │
│   └── transport/ sync_transport (interface), libp2p_sync_transport   │
│                  (default, UDX), tcp_sync_transport (fallback)       │
└─────────────────────────────────────────────────────────────────────┘
```

Entry point: `lib/main.dart` → `lib/app.dart` → `lib/core/router.dart`.

---

## 2. Data layer (`lib/data`)

- **Schema:** `lib/data/database.dart` declares the Drift `@DriftDatabase`.
  Tables live in `lib/data/tables/` (`notes.dart`, `attachments.dart`, …).
- **Encryption:** the DB is opened with SQLCipher. The key comes from the
  platform keystore via `flutter_secure_storage` (see
  `lib/core/providers/database_provider.dart`) — never hardcoded.
- **Opening gate:** DB open happens only after biometric unlock
  (`lib/core/providers/biometric_provider.dart`, `lib/features/security/`).
- **Repositories** wrap each table with `Stream`-based query API consumed by
  Riverpod providers.

Key note fields (see `docs/notes-app-detailed-plan.md`): `deviceOriginId`,
`syncVersion`, `updatedAt`, `pinned`, `locked`, `colorSeed`, `coverImagePath`,
`title`, `type`.

Generated code lives alongside tables (`database.g.dart`, `*.drift.dart`);
regenerate with `dart run build_runner build --delete-conflicting-outputs`.

---

## 3. Sync engine (`lib/sync`)

### 3.1 Protocol — `lib/sync/protocol/sync_bundle.dart` + `sync_message.dart`

The payload format is **CBOR**. On the libp2p transport each stream carries a
single `SyncMessage` envelope (`lib/sync/protocol/sync_message.dart`):
`[4B BE length][32B SHA-256][CBOR]`, checksum verified before deserialization.
The `dataBundle` message wraps a serialized `SyncBundle`:

- `SyncBundle` — top-level container: `protocolVersion`, `senderDeviceId`,
  `senderDeviceName`, `sentAt`, list of `SyncNoteEntry`.
- `SyncNoteEntry` — one note: `noteId`, `syncVersion`, `updatedAt`,
  `deviceOriginId`, `noteFields` (map), optional `checklistItems`, optional
  `attachments` (`List<SyncAttachment>`).
- `SyncAttachment` — `id`, `type` (`'image' | 'doodleLayer'`), `sortOrder`,
  `bytes`. Reads legacy single-attachment payloads for backward compatibility.
- `SyncHeader` — announces `bundleSizeBytes`, `checksum`, `noteCount` before the
  bundle so the receiver can stream and verify (used by the TCP fallback).
- `SyncAck` — `receivedNoteIds` + `rejectedNoteIds`, sent after processing.
- Helpers: `computeChecksum` / `verifyChecksum` (SHA-256), `splitIntoChunks` /
  `reassembleChunks`.

### 3.2 Merge resolver — `lib/sync/protocol/merge_resolver.dart`

Reconciles arriving notes with local state. Table-driven resolution by
`deviceOriginId` + `updatedAt` + `syncVersion`. Branch rules:

- incoming note is new → insert
- incoming is older → keep local (no-op)
- same lineage, newer → overwrite
- true conflict (both changed) → **never silently resolved**: returns
  `promptUser`, which surfaces a conflict card. User chooses Keep this device /
  Keep incoming / Keep both.

Merge semantics details:

- **Keep both** resets `deviceOriginId` to the receiving device so the
  duplicate becomes a locally-owned note and never re-conflicts.
- On kept notes (insert or overwrite), the receiver bumps `syncVersion` so the
  next exchange stays coherent.

### 3.3 Orchestrator — `lib/sync/sync_orchestrator.dart`

Coordinates a transfer end-to-end:

- Builds the default `Libp2pSyncTransport` (or `TcpSyncTransport` when
  `useTcpFallback: true`); tests inject a mock via `testTransport`.
- Subscribes to the transport's session-state stream once and carries each
  categorized failure into `SyncOrchestratorState.outcome`, so the UI can render
  a distinct treatment per failure mode.
- Exposes `pendingPairing` state and `confirmPairing()` / `rejectPairing()`
  (receiver-side pairing enforcement).
- Serializes notes (with **all** attachments) into a `SyncBundle`, computes the
  checksum, and hands the bytes to the transport.
- Receives a bundle, verifies checksum, feeds entries to the merge resolver,
  persists accepted notes/attachments (images + doodles into the app's managed
  documents directory via `path_provider`), and replies with an `SyncAck`.
- Records transfer results into `sync_log` for the history screen.

### 3.4 Transports — `lib/sync/transport/`

- `sync_transport.dart` — abstract `SyncTransport` + the session state streams
  and device/naming types. Also defines `SyncOutcomeCategory`
  (`rejected | timedOut | connectionLost | cancelled | protocol | internal`),
  the field every failure is categorized into so the UI can render distinct
  treatments (a decline is never shown as a generic red error).
- `libp2p_sync_transport.dart` — `Libp2pSyncTransport`, the **default**
  transport. Built on `dart_libp2p` over UDX (UDP-based reliable transport) with
  Noise encryption and Yamux multiplexing. Details in
  [`SYNC-LIBP2P-TRANSPORT.md`](SYNC-LIBP2P-TRANSPORT.md).
- `tcp_sync_transport.dart` — `TcpSyncTransport`, the legacy transport kept
  behind `useTcpFallback: true`. Length-prefixed JSON frames on raw TCP:
  - **Handshake:** sender `hello` (device identity + optional `pairingCode`);
    receiver replies with identity; if a code is present the receiver must send
    `pairing_confirm` before the sender's `connectToDevice(...)` succeeds.
  - **Transfer:** `sync_header` → `sync_chunk`* → receiver verifies SHA-256 and
    sends `sync_ack`.
  - **Reliability:** `sendData` returns the parsed `SyncAck`; it retries the
    full bundle once on ack timeout before surfacing an error.
  - **Naming:** configurable `localDeviceName` (no more hardcoded 'Nook').

### 3.5 Sync wire frames (libp2p — default)

Every stream carries exactly one envelope: `[4B BE length][32B SHA-256][CBOR]`
where the length prefix counts the checksum + payload. The SHA-256 is verified
**before** the CBOR payload is deserialized; Noise covers confidentiality and
authenticity on top. The CBOR payload is a `SyncMessage`:

| `type` | Direction | Meaning |
|---|---|---|
| `pairingRequest` | sender → receiver | device identity + `pairingCode` + `requestId` |
| `pairingAccepted` | receiver → sender | user approved the code |
| `pairingRejected` | receiver → sender | user declined |
| `dataBundle` | sender → receiver | raw `SyncBundle` CBOR bytes |
| `ack` | receiver → sender | `SyncAck` (received/rejected note ids) |

Each transaction is one stream with half-close: the initiator writes the
envelope, calls `closeWrite()`, then reads the response to EOF.

### 3.6 Sync wire frames (TCP — fallback)

All frames are: `uint32 BE length` + UTF-8 JSON payload (optionally
AES-GCM-encrypted after the ECDH handshake).

| Frame | Sender | Payload |
|---|---|---|
| `hello` | connecting | `{deviceId, deviceName, protocolVersion, pairingCode?}` |
| identity reply | server | `{deviceId, deviceName, protocolVersion}` |
| `pairing_confirm` / `pairing_rejected` | server | confirmation after user approves code |
| `sync_header` + `sync_chunk`… | sender | checksum + size, then base64 payload chunks |
| `sync_ack` | receiver | `{data: base64(CBOR SyncAck)}` |

---

## 4. Feature surface (`lib/features`)

- **home/** — polymorphic note cards (`note_card`, `note_banner_card`,
  `note_doodle_card`, `note_minimal_card`), staggered grid, filter pills,
  pull-to-search, morphing editorial FAB.
- **editor/** — AppFlowy editor integration in `note_editor_screen`; autosave
  debounces `transactionStream` (~600ms) and serializes `document.toJson()` into
  Drift. Custom node types: `doodle` (`lib/features/editor/doodle/doodle_block.dart`)
  and re-skinned `todo_list` (`custom_todo_list_block.dart`). Image
  handling in `zoomable_image_block.dart` / `image_picker_handler.dart`.
  Non-checklist notes wrap the editor in `MobileToolbarV2` with a custom blocks
  menu, a Doodle action, and `textDecorationMobileToolbarItemV2` (see AGENTS.md →
  "Mobile toolbar & global shortcuts").
- **doodle/** — `doodle_controller` (undo/redo, mode), `doodle_painter`,
  `doodle_strokes_codec` (v1/v2 codec, `isPerfectShape`), thumbnail renderer,
  shape-assist toolbar.
- **sync_ui/** — screen-by-screen UI over the orchestrator:
  `sync_screen`, `sync_send_screen`, `sync_receive_screen`, `sync_pairing_screen`,
  `sync_transfer_screen`, `sync_history_screen`, plus `widgets/conflict_card.dart`.

---

## 5. Platform / core (`lib/core`)

- **Theme:** `theme/app_theme.dart` + `design_tokens.dart`; per-note color
  scopes via `note_theme_scope.dart`.
- **Router:** `router.dart` (go_router, 28 routes).
- **Providers:** database, theme, pin, biometric, screenshot blocker, talker.
- **Platform bridges:** `platform/window_manager.dart` (MethodChannel, replaced
  discontinued `flutter_windowmanager`), `platform/nearby_permissions.dart`.
- **Global keyboard shortcuts:** `widgets/keyboard_shortcuts.dart`
  (`NookKeyboardShortcuts`, wraps the `MaterialApp.router.builder` output) binds
  `/` and Ctrl/Cmd+K → search, Ctrl/Cmd+N → new note. A guard skips firing while
  an `EditableText` (or the editor's nested `FocusScope`) holds focus, so typing
  `/` in the editor still opens AppFlowy's slash menu. Covered by
  `test/core/widgets/keyboard_shortcuts_test.dart`.
- **Wide shell:** the `NavigationRail` is pinned to a fixed 80px rail
  (`widgets/app_shell.dart`); dual-pane list screens tint their left pane with
  `surfaceContainerLow`.
- **Logging:** `talker_flutter` — global `talker` + `talkerProvider` in
  `providers/talker_provider.dart`, `FlutterError.onError` /
  `PlatformDispatcher.onError` wired in `main.dart`, viewer at
  `features/settings/settings_logs_screen.dart` (`Settings → Developer → App Logs`).

---

## 6. Editor patches & gotchas (`docs/notes-app-part3-editor…`)

- `AppFlowyEditorLocalizations.delegate` must be added to
  `MaterialApp.localizationsDelegates` or the editor throws at runtime.
- `android/settings.gradle.kts` patches the pub-cache `keyboard_height_plugin`
  build.gradle (compileSdk 31 → 34) — see
  https://github.com/AppFlowy-IO/appflowy-editor/issues/1036.
- `tool/patch_appflowy_editor.dart` patches two files in the pub cache:
  (1) `delta_input_service.dart` — the `TextInputClient.onFocusReceived`
  override Flutter 3.44+ requires; and (2) `slash_command.dart` — makes `/`
  work on mobile by inserting the slash character and consuming the event
  without the SelectionMenu overlay. CI runs it after `flutter pub get`; local
  dev must too. Remove once upstream publishes fixes (>= 6.2.1).

---

## 7. Testing

| Area | Approach | Where |
|---|---|---|
| Data | in-memory Drift `NativeDatabase.memory()` | `test/data/*` |
| Merge | table-driven over all resolver branches | `test/sync/merge_resolver_test.dart` |
| Protocol | CBOR round-trips, legacy payload compat, checksum | `test/sync/protocol_test.dart` |
| Wire envelope | `SyncMessage` framing: round-trip, checksum tamper, truncation | `test/sync/sync_message_test.dart` |
| Identity | Ed25519 seed persistence + stable key pair | `test/sync/sync_message_test.dart` |
| Discovery | mDNS fork TXT parsing + split modes, no multicast | `test/sync/nook_mdns_discovery_test.dart` |
| Orchestrator | fake transport + real resolver/DB + outcome mapping | `test/sync/sync_orchestrator_test.dart` |
| Transport | mock + **loopback UDX between two real libp2p hosts** | `test/sync/libp2p_transport_test.dart`, `test/sync/libp2p_integration_test.dart` |
| Legacy transport | mock + real loopback TCP (`127.0.0.1`) | `test/sync/transport_test.dart`, `test/sync/tcp_transport_integration_test.dart` |
| Widgets | `flutter_test` + goldens (NoteCard color/locked/pinned), outcome states | `test/features/*`, `test/features/sync_ui/sync_test.dart` |
| Real devices | real-mDNS round trip tagged `network` (skipped in CI); two-emulator harness | `test/sync/nook_mdns_discovery_test.dart`, detailed plan §11 |

CI (`github/workflows/ci.yml`): `format → analyze → test --coverage -x network`,
then an APK build + tag-triggered GitHub release.

## 8. Common changes & where to make them

| You want to… | Touch |
|---|---|
| Add a note field | table → repository → serialization in `sync_bundle.dart` |
| Change the wire protocol | `sync_message.dart` + `libp2p_sync_transport.dart` (or `tcp_sync_transport.dart` for the fallback) + `protocol_test.dart` / `sync_message_test.dart` |
| Change conflict UX | `merge_resolver.dart` + `sync_ui/widgets/conflict_card.dart` |
| Change failure outcomes | `SyncOutcomeCategory` in `sync_transport.dart` + `sync_transfer_screen.dart` |
| Add a sync screen/route | `core/router.dart` + `features/sync_ui/` |
| New attachment type | `tables/attachments.dart` + `SyncAttachment` mapping + restore path |
| Change editor behavior | `features/editor/` (blocks, autosave, toolbar) |
| Security/scanner UI | `core/providers/*_provider.dart` + `features/security/` |
| CI / release | `.github/workflows/ci.yml` |