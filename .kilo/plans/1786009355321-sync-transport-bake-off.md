# Sync Transport Abstraction & Bake-Off Plan

## Goal
Decouple the sync protocol and UI from the underlying network transport, prototype three candidate transports on physical hardware, and select the v1 implementation.

## Why this matters
Android Wi-Fi Direct is notoriously inconsistent across OEM skins. iOS uses a completely different API (Multipeer Connectivity). Committing to one transport before validation risks shipping a sync feature that silently fails on common devices.

## Interface (adopt as-is)
Place at `lib/sync/transport/sync_transport.dart`:

```dart
abstract interface class SyncTransport {
  Future<void> startAdvertising(String deviceName);
  Future<void> stopAdvertising();
  Stream<List<DiscoveredPeer>> discoverPeers();
  Future<SyncSession> connectTo(DiscoveredPeer peer);
}

class DiscoveredPeer {
  final String id;
  final String name;
  final dynamic networkContext;
  DiscoveredPeer({required this.id, required this.name, this.networkContext});
}

abstract interface class SyncSession {
  Stream<List<int>> get incomingData;
  Future<void> sendData(List<int> data);
  Future<void> close();
}
```

All sync code (CBOR serialization, `SyncBundle`, merge resolver, Sync UI) must depend only on these interfaces. No transport-specific imports outside `lib/sync/transport/`.

## Three candidates

1. **NearbyServiceTransport** — wraps existing `nearby_service` v0.2.1 (already in pubspec). Android-only in practice for v1.
2. **NsdSocketTransport** — `nsd` for mDNS discovery + raw TCP sockets. Cross-platform (Android/iOS/macOS/Linux/Windows/Web via WASM sockets). Requires shared Wi-Fi router.
3. **P2pConnectionTransport** — `flutter_p2p_connection` for BLE discovery handoff + Wi-Fi Direct data transfer. Android-only; BLE discovery is faster than pure Wi-Fi Direct.

## Implementation order

1. Define `SyncTransport` / `SyncSession` interfaces + `DiscoveredPeer`.
2. Create throwaway prototype harness: a minimal app with a "Send test payload" / "Receive" screen that logs connection timing, throughput, and failure modes.
3. Implement `NearbyServiceTransport` in the harness.
4. Implement `NsdSocketTransport` in the harness.
5. Implement `P2pConnectionTransport` in the harness.
6. Run bake-off on physical devices (see evaluation criteria below).

## Evaluation criteria (pass/fail + score)

| Criterion | Weight | Notes |
|---|---|---|
| Discovery time (seconds) | High | Target < 3s on average; BLE-augmented transports should lead here |
| Connection success rate | High | Test on stock Pixel + Samsung + Xiaomi; Wi-Fi Direct drops are disqualifying |
| Cross-platform viability | Medium | NSD wins by default; Android-only transports require future rewrite for iOS/Web |
| Payload reliability (no data loss/corruption) | High | Verify with SHA-256 checksum on 1MB test payload |
| Code maintenance risk | Medium | Assess package health: `nsd` and `nearby_service` are actively maintained; `flutter_p2p_connection` less so |
| Permission UX | Medium | Wi-Fi Direct requires multiple system prompts; mDNS requires only local network permission |

## Decision rule
- If any Android-only transport achieves >90% connection success across Pixel/Samsung/Xiaomi **and** the package is actively maintained, it is eligible for v1.
- NSD must demonstrate stable discovery + transfer on at least two platforms to win the cross-platform argument.
- If no single transport clearly wins, default to **NSD + raw sockets** for v1. It is the only option that does not depend on a fragile OEM Wi-Fi Direct implementation and maps cleanly to future WebRTC if the Web app ever needs sync.

## Out of scope
- WebRTC implementation (future, if Web sync is desired)
- Multi-hop relay (A → B → C)
- Automatic background sync (always user-initiated in v1)
- iOS Multipeer Connectivity wrapper (unless NSD prototype reveals an existing package worth using)

## Validation
- Each transport prototype must successfully transfer a 500KB CBOR payload between two physical Android devices with zero bytes dropped.
- Each prototype must log discovery time, connection time, and any failure mode encountered.
- Evaluation report written to `docs/` before selecting v1 transport.
