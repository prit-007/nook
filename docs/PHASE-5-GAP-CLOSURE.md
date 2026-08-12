# Phase 5 — Gap Closure Plan

Goal: close the remaining ~40% of Phase 5 (nearby sync). The core paths exist;
this plan hardens the flows, adds missing tests, and fixes the half-built
pieces. Everything here is tested via loopback transport tests and orchestrator
unit tests (no physical devices required), plus real-device validation steps.

## Gap 1 — Receiver-side pairing enforcement

**Problem:** Only the sender confirms via `/sync/pairing`. The receiver accepts
any TCP connection with no code verification — the "Verify this code on both
devices" copy is misleading.

**Fix (mutual pairing over the wire):**
- Transport handshake gains a `pairingCode` in the sender's `hello` identity and
  a `pairing_confirm` frame.
- Sender's `connectToDevice(device, {pairingCode})` waits for the receiver's
  `pairing_confirm` (with timeout) before returning `true`.
- Receiver, on an incoming `hello` carrying a code, does NOT auto-accept. It
  emits a `PairingRequest` and the receive UI shows an inline confirm prompt
  with the code + device name. Approve → sends `pairing_confirm`; reject →
  closes the socket.
- Orchestrator exposes `pendingPairing` state + `confirmPairing()` /
  `rejectPairing()`.

## Gap 2 — Real `TcpSyncTransport` integration test

**Problem:** `test/sync/transport_test.dart` only exercises the mock.

**Fix:** Loopback integration test driving two `TcpSyncTransport` instances
over `localhost` sockets (bypassing mDNS by binding the server on a known port
and connecting directly). Cover: hello/pairing handshake, chunked send/receive,
SHA-256 checksum, ack round-trip, disconnect.

## Gap 3 — Multi-attachment sync + stable storage

**Problem:** `sync_orchestrator.dart` sends only `attachments.first`, and
`_restoreAttachment` writes to `Directory.systemTemp`.

**Fix:**
- `SyncNoteEntry` carries `List<SyncAttachment>` (id, type, sortOrder, bytes)
  instead of a single `attachmentBytes`. Serialization stays backward-compatible
  (reads legacy single-attachment payloads).
- Sender serializes every attachment for each note.
- Restore writes attachments into the app's managed documents directory (via
  `path_provider`) using `addImage`/`addDoodle` with preserved ids/order.

## Gap 4 — Ack results surfaced to sender + device naming

**Problem:** `sendData` discards the receiver's ack; the sender never learns which
notes were rejected. Device name is hardcoded `'Nook'`.

**Fix:**
- `sendData` returns the parsed `SyncAck`; orchestrator stores `receivedNoteIds`
  / `rejectedNoteIds` on state and the transfer screen shows the result.
- `TcpSyncTransport`/`initializeTransport` accept a configurable `localDeviceName`.

## Gap 5 — Merge semantics edge cases

**Fix:**
- "Keep both" insert resets `deviceOriginId` to the receiving device so the
  duplicate is treated as a new, locally-owned note (never re-conflicts).
- Receiver bumps `syncVersion` on notes it keeps (insert/overwrite) so the next
  sync is coherent.

## Gap 6 — Retry on dropped transfer

**Fix:** `sendData` retries the full bundle once if the ack times out, then
surfaces an error if it still fails.

## Gap 7 — Checklist + docs

- Re-mark stale `[ ]` items in `docs/IMPLEMENTATION-CHECKLIST.md` (transport is
  implemented via bonsoir/TCP), keep device-validation items open, bump Phase 5
  status.

## Out of scope (still needs physical devices)
- Real two-device discovery / pairing / transfer validation.
- Cross-manufacturer (Pixel/Samsung/Xiaomi) testing.