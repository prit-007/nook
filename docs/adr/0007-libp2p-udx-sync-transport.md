# 7. libp2p (UDX) as the default sync transport

Date: 2026-08-13

## Status
Accepted

## Context
Nook syncs notes peer-to-peer between a user's own devices over the local
network. Two transports existed or were considered:

- **TCP + Bonsoir (mDNS)** — the Phase 5 transport (`TcpSyncTransport`). It
  works, but identity is a fresh random UUID per launch (no stable device
  identity), encryption is app-layer (ECDH + AES-GCM), and it is a hand-rolled
  protocol on raw sockets.
- **dart_libp2p** (`libp2p`-stack in pure Dart) — mature peer identity,
  pluggable transports, Noise security, Yamux multiplexing, built-in mDNS. Its
  TCP transport requires an internal `ResourceManagerImpl` import that is
  fragile to API drift; its UDX transport (a custom UDP-based reliable transport
  from `dart_udx`) is the package's own proven path (the chat example uses it)
  and is loopback-testable in CI without multicast.

We also needed a stable per-install device identity. The app already ships
`flutter_secure_storage` and a PIN-derivation pattern in `pin_provider.dart`.

## Decision
Make **`Libp2pSyncTransport` over UDX the default sync transport**
(`dart_libp2p ^1.0.3`), and keep `TcpSyncTransport` behind `useTcpFallback: true`.

Concretely:

- **Identity:** a 32-byte Ed25519 seed is generated once and sealed in
  `flutter_secure_storage`; a libp2p peer id is derived from it, so
  `getCurrentDeviceId()` is stable across restarts
  (`lib/sync/crypto/identity_store.dart`).
- **Wire protocol:** one `SyncMessage` envelope per stream transaction —
  `[4B big-endian length][32B SHA-256][CBOR]` with checksum-before-deserialization
  (`lib/sync/protocol/sync_message.dart`). Pairing is a held-stream
  request/response with a 120s cleanup deadline; transfer is a dataBundle stream
  whose ack is written back on the same stream.
- **Discovery:** a fork of dart_libp2p's mDNS with its own `_syncnotenet._udp`
  service, a `devicename=` TXT record, and split advertise/discover modes
  (`lib/sync/discovery/nook_mdns_discovery.dart`).
- **Outcomes:** `SyncOutcomeCategory` (rejected / timedOut / connectionLost /
  cancelled / protocol / internal) distinguishes a deliberate decline from a
  timeout or a connection loss, driving distinct UI treatments.
- **AutoNAT:** because `applyDefaults()` hard-sets `enableAutoNAT = true` after
  options run, the transport forces `Reachability.private` (skips ambient
  probing dials) — a LAN-only app must never dial public peers.

## Consequences
- The app gains a stable, authenticated, multiplexed transport with real peer
  identity and no server.
- The legacy TCP transport and its E2E session cipher remain in the codebase as
  a fallback; both must stay compiling and covered by tests.
- Discovery is unproven on some Android stacks (pure Dart cannot hold an Android
  MulticastLock) — real-device validation remains an open item.
- The `SyncTransport` interface grew (`initialize()`/`isInitialized`/
  `getCurrentDeviceId()`, `SyncDevice.multiaddresses`), so all implementations
  and the mock were updated.
- AutoNAT stray dials, if any, must be monitored; the forced-private-reachability
  lever is the mitigation available today.
