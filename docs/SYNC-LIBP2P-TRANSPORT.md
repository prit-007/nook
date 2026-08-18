# Nook Sync — libp2p UDX Transport

This document is the **current-state** reference for the default sync transport:
how Nook discovers, pairs, and transfers notes between two of *your* devices over
your local Wi-Fi, with no server and no account.

Read it alongside:

- `docs/ARCHITECTURE.md` §3 — the sync engine's place in the codebase.
- `lib/sync/transport/libp2p_sync_transport.dart` — the implementation.
- `docs/notes-app-detailed-plan.md` §9 — the product-level protocol spec (the
  plan's `nearby_service` choice is superseded; see the note at the top of §9).

---

## 1. Transport stack

```
┌─────────────────────────── Nook sync ───────────────────────────┐
│  SyncOrchestrator      state machine, bundle assembly, resolver  │
│  Libp2pSyncTransport   one SyncMessage per stream transaction    │
│  dart_libp2p           Host + protocol switch (stream handlers)  │
│  Noise                encrypted + authenticated handshake        │
│  Yamux                stream multiplexing over one connection    │
│  UDX (dart_udx)       UDP-based reliable transport (dart:io)     │
└──────────────────────────────────────────────────────────────────┘
```

- **UDX** is a custom reliable UDP transport from `dart_udx`. It is used because
  the TCP transport in `dart_libp2p` requires an internal `ResourceManagerImpl`
  import that is fragile to API drift; UDX is the proven path (it is what the
  package's own chat example ships) and is loopback-testable in CI.
- **Noise** provides per-connection encryption and authentication of the remote
  peer's identity.
- **Yamux** lets a single UDX connection carry many logical streams — one per
  sync transaction.

## 2. Stable identity

Every Nook install owns a permanent libp2p peer id:

1. On first sync, `IdentityStore` (`lib/sync/crypto/identity_store.dart`)
   generates a random **32-byte Ed25519 seed** and seals it in the platform
   keystore via `flutter_secure_storage` (key `sync_libp2p_ed25519_seed`,
   base64url-encoded). The raw seed never leaves the keystore.
2. On every launch the seed is re-derived into the same key pair
   (`generateEd25519KeyPairFromSeed`), so `host.id` — and therefore
   `getCurrentDeviceId()` — is **stable across restarts**. This is what makes a
   device addressable by other Nooks over time.

The seed storage is an injectable seam (`SeedStorage`), so unit tests use an
in-memory fake instead of the platform keystore.

## 3. Discovery — `lib/sync/discovery/nook_mdns_discovery.dart`

`NookMdnsDiscovery` is a fork of dart_libp2p's mDNS class. Differences:

- **Own service name** `_syncnotenet._udp` (never collides with libp2p's
  `_p2p._udp`) and a configurable port (default 4001).
- **`devicename=` TXT record** (URL-encoded) so the peer's friendly name is known
  the moment it is discovered — no extra round-trip.
- **Split modes** — `advertiseOnly()` and `discoverOnly()`:
  - the **receiver advertises** (holds the door open),
  - the **sender discovers** (finds the receiver's address).
- **`debugInjectPeer(AddrInfo, {deviceName})`** drives discovery logic in tests
  without multicast.
- Self-discovery is skipped (a peer whose id equals our own is never reported).

The transport owns one discovery instance, constructed after the host starts so
the advertised port is the host's real bound UDX port.

### 3.1 LAN interface selection & multicast reliability

Discovery and advertising run on physical devices only, and mDNS multicast is
the one component the loopback test suite never exercises. Three rules keep it
working on real networks:

- **Pin the active LAN interface.** `NookMdnsDiscovery.resolveActiveInterface()`
  picks a WiFi/Ethernet IPv4 adapter (skipping VPN/Docker/Tailscale-style
  virtual adapters) and passes it to `MDNSClient.query(...)`, the
  `MDNSServerConfig`, and the announce socket. Without this, multicast can go
  out the wrong NIC (Wi-Fi vs cellular on Android, VPN/multi-NIC on Windows).
- **`reusePort: false` on Android.** mdns_dart documents Android socket-bind
  issues with `SO_REUSEPORT` on port 5353; `reuseAddress: true` is enough there.
  Windows keeps `reusePort: true`.
- **Fail loudly.** mDNS start/bind/query failures are logged at `error` in the
  `sync` domain (not swallowed), so "Searching for devices..." that never finds
  anything is diagnosable from `Settings → Developer → App Logs`.

### 3.2 Manual dial-in (mDNS bypass)

When multicast is blocked — AP client isolation, a Windows firewall rule, or a
VPN — discovery cannot work. Nook's receive screen shows the device's own
dialable multiaddr (peer id suffixed, from `Libp2pSyncTransport.localMultiaddresses`)
with tap-to-copy; the send screen's **"Add device manually"** pastes it straight
into `connectToDevice` via `SyncDevice.fromManualAddress`. No mDNS involved.

LAN requirements for mDNS + UDX:

- Both devices on the **same subnet** (mDNS TTL 1, no routing).
- **AP client isolation OFF** — guest networks silently block device-to-device
  unicast and multicast.
- **Windows**: allow Nook through the inbound firewall the first time it runs
  (UDP 5353 for mDNS and the app's UDX port). A permanent rule:
  `netsh advfirewall firewall add rule name="Nook sync" dir=in action=allow protocol=UDP localport=5353 profile=private`
- **Android**: `CHANGE_WIFI_MULTICAST_STATE` is held as a `WifiManager.MulticastLock`
  while advertising/discovering (see `lib/core/platform/multicast_lock.dart` +
  the `com.nook/multicast_lock` channel in `MainActivity.kt`).

### 3.3 Cross-network discovery — Wi-Fi Direct (Quick Share mechanism)

When the sender and receiver are **not on the same Wi-Fi network**, mDNS cannot
reach across subnets. Nook reproduces Quick Share's approach **without the
deprecated Nearby Connections API**: an Android Wi-Fi Direct P2P link.

- **Receiver (advertise):** creates a Wi-Fi Direct group (group owner = soft
  AP, `WifiP2pManager.createGroup`) and registers Nook's `_syncnotenet._tcp`
  DNS-SD service carrying its dialable multiaddr in the `dnsaddr` TXT record
  (`WifiDirect.buildDnsaddr` → `/ip4/<owner>/udp/<udxPort>/udx/p2p/<peerId>`).
  The UDX host binds `0.0.0.0`, so the same port is reachable on the P2P
  subnet (owner default `192.168.49.1`).
- **Sender (discover):** Wi-Fi Direct DNS-SD discovery (`discoverServices`)
  surfaces the receiver as a `SyncDevice` with `transportType: 'wifi-direct'`
  and `wifiDirectAddress`. On connect, the sender `WifiDirect.joinGroup()`s the
  peer, waits for the group-owner IP, then dials `/ip4/<owner>/udp/<port>/udx`
  over the established P2P link — everything after that is the normal
  UDX + Noise/Yamux + pairing flow.
- **Native bridge:** `WifiDirect` (`lib/core/platform/wifi_direct.dart`) →
  `com.nook/wifi_direct` + `com.nook/wifi_direct/events` channels in
  `MainActivity.kt`.

**Platform support is tiered and safe:**
`WifiDirect.isSupportedPlatform` is `true` only on Android. On **Linux, iOS,
macOS, Windows and Web** every Wi-Fi Direct call is a no-op and the transport
falls back to the same-network mDNS path (or manual entry). Wi-Fi Direct itself
is Android-only because the other OSes provide no equivalent cross-network P2P
link API; keep the tiered behavior in mind when adding discovery features.

Requirements for Wi-Fi Direct sync: both devices nearby, Wi-Fi on, nearby
permissions granted, and Location on (Android's P2P framework requires it, same
as Nearby Connections).

## 4. Wire protocol — `lib/sync/protocol/sync_message.dart`

### 4.1 Envelope

Every stream carries exactly one envelope:

```
[4 bytes big-endian length N]  // N = 32 + payload length
[32 bytes SHA-256 of payload]
[N bytes CBOR payload]
```

The SHA-256 is verified **before** the CBOR payload is deserialized
(AGENTS.md's checksum-before-deserialization guarantee). Noise already protects
confidentiality/authenticity; the checksum additionally guards against
corruption. `SyncMessageCodec.decode` rejects truncated frames, trailing bytes,
oversized frames, and unknown types.

### 4.2 Message types

| `type` | Carries | Meaning |
|---|---|---|
| `pairingRequest` | `senderDeviceId`, `senderDeviceName`, `requestId`, `pairingCode?` | "Pair with me" |
| `pairingAccepted` | identity | receiver approved the code |
| `pairingRejected` | identity | receiver declined |
| `dataBundle` | identity, `bundleBytes` (raw `SyncBundle` CBOR) | the note payload |
| `ack` | identity, `ack` (`SyncAck`) | result of processing a bundle |

### 4.3 One stream per transaction (half-close request/response)

- **Initiator (sender):** `host.connect(AddrInfo)` → `host.newStream(peer, [protocol])`
  → `write(envelope)` → `closeWrite()` (FIN) → read the response to EOF.
  Because Yamux supports half-close, the initiator can keep reading after its
  own FIN, and the acceptor can keep writing after receiving the FIN — this
  mirrors the request/response socket semantics of the old TCP transport.
- **Acceptor (receiver):** the stream handler reads to EOF, verifies the
  checksum, then branches:
  - `pairingRequest` → **hold the stream** in a `Map<requestId, P2PStream>` and
    emit a `PairingRequest` to the UI. `respondToPairing(...)` writes the
    `pairingAccepted`/`pairingRejected` envelope on the held stream and closes
    it. A 120s timer (`heldStreamTimeout`) closes undecided held streams so
    requests never leak.
  - `dataBundle` → emit `bundleBytes` on `bytesReceivedStream` and **hold the
    stream for the orchestrator's ack**. `sendAck(ackCbor)` writes the `ack`
    envelope back on the same stream and closes it.
- `read([maxLength])` returns **one chunk**, not a full frame — readers
  accumulate until EOF. `read()` blocks ~5 minutes by default when a peer goes
  silent, so the transport calls `setReadDeadline(...)` before **every** await;
  a missing ack/pairing response times out in seconds.

## 5. Transport lifecycle — `Libp2pSyncTransport`

```
initialize()   load seed → build Host (UDX + Noise + Yamux) →
               setStreamHandler('/syncnotenet/sync/1.0.0') → host.start()
               → derive _localDeviceId = host.id → build NookMdnsDiscovery

startAdvertising()  discovery.advertiseOnly()   (receiver)
startDiscovery()    discovery.discoverOnly()    (sender)
connectToDevice(device, {pairingCode})
    → host.connect → newStream → pairingRequest → read pairingAccepted/Rejected
sendData(bytes)     → newStream → dataBundle → read ack
sendAck(bytes)      → write ack on the held dataBundle stream
disconnect()        → stop discovery, close held streams, host.close()
```

`SyncDevice.multiaddresses` carries the advertised libp2p multiaddrs; the
`deviceId` is the peer's libp2p id. `connectToDevice` builds dialable
`MultiAddr`s (appending `/p2p/<peerId>` to addresses that lack it).

## 6. Failure outcomes

`SyncOutcomeCategory` (`lib/sync/transport/sync_transport.dart`) classifies every
failure so the UI never guesses from a message string:

| Category | Produced by | UI treatment (`sync_transfer_screen.dart`) |
|---|---|---|
| `rejected` | receiver writes `pairingRejected` | amber shield, **"Transfer Declined"**, Dismiss-only |
| `timedOut` | initiator's read deadline fires (`YamuxStreamTimeoutException` / `YamuxStreamStateException` wrapping a timeout) | hourglass, **"Transfer Timed Out"**, Try Again + Dismiss |
| `connectionLost` | connection dropped mid-transfer | wifi-off, **"Connection Lost"**, Try Again + Dismiss |
| `cancelled` | local abort | neutral, **"Transfer Cancelled"**, Dismiss |
| `protocol` | checksum/format/state violations | red circle-alert, "Transfer Failed" |
| `internal` | anything else | red circle-alert, "Transfer Failed" |

The orchestrator subscribes to `sessionStateStream` once and carries the outcome
into `SyncOrchestratorState.outcome`.

## 7. AutoNAT & LAN-only behavior

`dart_libp2p`'s `applyDefaults()` hard-sets `enableAutoNAT = true` *after*
options are applied, so a LAN-only app cannot turn AutoNAT off via options. The
transport instead forces `Reachability.private` (and disables hole punching),
which makes `BasicHost.start()` skip the ambient AutoNAT probing that would
otherwise dial public peers. Known open items:

- AutoNAT stray dials (should not occur with forced private reachability).
- Android MulticastLock — pure Dart cannot hold one; mDNS may work without it,
  but reliability is unproven on some Android stacks.

## 8. Testing

- **Loopback UDX** between two in-process libp2p hosts, no multicast:
  `test/sync/libp2p_test_host.dart` builds hosts with
  `forceReachability(Reachability.private)` and a keep-all addrs factory (the
  defaults strip loopback addrs and would make dials fail).
- `test/sync/libp2p_transport_test.dart` — scripted fake peer: byte-identical
  payloads, pairing accept/reject, ack, timeout, cancel.
- `test/sync/libp2p_integration_test.dart` — two real `Libp2pSyncTransport`
  instances complete pair → transfer → ack.
- `test/sync/nook_mdns_discovery_test.dart` — TXT parsing, split modes,
  self-exclusion (no multicast); the real-mDNS round trip is tagged `network`
  and skipped by CI (`flutter test --coverage -x network`).
- `test/sync/sync_message_test.dart` — envelope round-trips, checksum tamper,
  truncation, oversized frames, and identity seed persistence.

## 9. Permissions

- **Android** (`android/app/src/main/AndroidManifest.xml`): `INTERNET`,
  `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, and
  `NEARBY_WIFI_DEVICES` (13+, `neverForLocation`).
- **iOS** (`ios/Runner/Info.plist`): `NSLocalNetworkUsageDescription` and
  `NSBonjourServices` = `_syncnotenet._udp`.
- **macOS**: `com.apple.security.network.client` + `.server` in both
  `DebugProfile.entitlements` and `Release.entitlements`.
