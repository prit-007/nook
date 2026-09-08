import 'dart:async';

import '../protocol/sync_bundle.dart';

/// Represents a nearby device discovered via the sync transport.
class SyncDevice {
  const SyncDevice({
    required this.deviceId,
    required this.deviceName,
    required this.isOnline,
    this.hostAddress,
    this.port,
    this.multiaddresses,
    this.transportType = 'libp2p',
    this.wifiDirectAddress,
  });

  final String deviceId;
  final String deviceName;
  final bool isOnline;
  final String? hostAddress;
  final int? port;

  /// libp2p multiaddrs (e.g. `/ip4/192.168.1.50/udp/4001/udx`) advertised by
  /// the peer. Null for transports that only expose [hostAddress]/[port].
  final List<String>? multiaddresses;

  /// Which transport dials this device: `libp2p` (mDNS/UDX on the same
  /// network) or `wifi-direct` (found over a Wi-Fi Direct P2P link — requires
  /// joining the peer's group before dialing).
  final String transportType;

  /// The peer's Wi-Fi Direct device address; required to join its P2P group
  /// before dialing when [transportType] is `wifi-direct`.
  final String? wifiDirectAddress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          transportType == other.transportType;

  @override
  int get hashCode => Object.hash(deviceId, transportType);

  /// Builds a [SyncDevice] from a user-entered libp2p multiaddr such as
  /// `/ip4/192.168.1.20/udp/52341/udx/p2p/12D3KooW...`. The `/p2p/<peer id>`
  /// suffix is required — it identifies the peer to dial. Returns null for
  /// malformed or incomplete addresses so the caller can surface an error.
  static SyncDevice? fromManualAddress(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    const p2pMarker = '/p2p/';
    final p2pIdx = trimmed.indexOf(p2pMarker);
    if (p2pIdx == -1) return null;
    final peerId = trimmed.substring(p2pIdx + p2pMarker.length);
    if (peerId.isEmpty) return null;
    final addr = trimmed.substring(0, p2pIdx);
    if (addr.isEmpty) return null;
    return SyncDevice(
      deviceId: peerId,
      deviceName: 'Manual device',
      isOnline: true,
      multiaddresses: [addr],
    );
  }

  /// Builds a [SyncDevice] from a Wi-Fi Direct DNS-SD service entry.
  ///
  /// The receiver registers `_syncnotenet._tcp` over the P2P link with its
  /// dialable multiaddr in the `dnsaddr` TXT record (see
  /// `lib/core/platform/wifi_direct.dart`). Returns null for non-Nook or
  /// malformed services so discovery can ignore them.
  static SyncDevice? fromWifiDirectService({
    required String instanceName,
    required String deviceAddress,
    required Map<String, String> txt,
  }) {
    final dnsaddr = txt['dnsaddr'];
    final name = txt['name'] ?? instanceName;
    if (dnsaddr == null) return null;
    const p2pMarker = '/p2p/';
    final p2pIdx = dnsaddr.indexOf(p2pMarker);
    if (p2pIdx == -1) return null;
    final peerId = dnsaddr.substring(p2pIdx + p2pMarker.length);
    final addr = dnsaddr.substring(0, p2pIdx);
    if (peerId.isEmpty || addr.isEmpty) return null;
    return SyncDevice(
      deviceId: peerId,
      deviceName: name,
      isOnline: true,
      transportType: 'wifi-direct',
      wifiDirectAddress: deviceAddress,
      multiaddresses: [addr],
    );
  }
}

/// An incoming connection that requests pairing confirmation on the receiver.
///
/// The receiver must confirm (or reject) before any note data is transferred,
/// so both devices verify the same pairing code.
class PairingRequest {
  const PairingRequest({
    required this.remoteDeviceId,
    required this.remoteDeviceName,
    required this.pairingCode,
    required this.connectionId,
  });

  final String remoteDeviceId;
  final String remoteDeviceName;
  final String pairingCode;
  final String connectionId;
}

/// State machine for a sync session.
class SyncSessionState {
  const SyncSessionState.idle()
      : error = null,
        outcome = null;
  const SyncSessionState.advertising()
      : error = null,
        outcome = null;
  const SyncSessionState.discovering()
      : error = null,
        outcome = null;
  const SyncSessionState.connecting()
      : error = null,
        outcome = null;
  const SyncSessionState.connected()
      : error = null,
        outcome = null;
  const SyncSessionState.transferring()
      : error = null,
        outcome = null;
  const SyncSessionState.complete()
      : error = null,
        outcome = null;
  const SyncSessionState.error(
    String this.error, {
    this.outcome = SyncOutcomeCategory.internal,
  });

  final String? error;

  /// Category of the failure, when [error] is non-null. Lets callers
  /// distinguish a declined transfer from a timeout or a protocol violation
  /// instead of guessing from the message string.
  final SyncOutcomeCategory? outcome;
}

/// Categories a failed sync session/operation can be bucketed into.
///
/// Drives distinct UI treatments (declined vs. timeout vs. connection lost vs.
/// protocol error) so a user is never shown an ambiguous red error for a
/// deliberate rejection.
enum SyncOutcomeCategory {
  /// The remote device deliberately declined the pairing/transfer.
  rejected,

  /// The peer never answered before the deadline elapsed.
  timedOut,

  /// The underlying connection dropped mid-transfer.
  connectionLost,

  /// The local user cancelled the operation.
  cancelled,

  /// The peer violated the wire protocol or sent corrupt data.
  protocol,

  /// Anything else — surfaced as the generic failure state.
  internal,
}

/// Abstract interface for a sync transport (e.g., Nearby Connections, NSD).
///
/// Implementations wrap platform-specific discovery, pairing, and data transfer.
abstract class SyncTransport {
  Stream<SyncDevice> get deviceFoundStream;
  Stream<SyncSessionState> get sessionStateStream;
  Stream<List<int>> get bytesReceivedStream;
  Stream<double> get progressStream;
  Stream<PairingRequest> get pairingRequestStream;

  /// Prepares the transport (identity, listeners) for use. Idempotent.
  Future<void> initialize();

  /// Whether [initialize] has completed at least once.
  bool get isInitialized;

  /// Stable identifier for this device, stable across restarts.
  Future<String?> getCurrentDeviceId();

  /// Multiaddrs this device is listening on (peer id suffixed), for manual
  /// dial-in when network discovery is unavailable. Empty until
  /// [initialize] has bound the listener.
  List<String> get localMultiaddresses;

  Future<void> startAdvertising();
  Future<void> stopAdvertising();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<bool> connectToDevice(SyncDevice device, {String? pairingCode});
  Future<void> respondToPairing(PairingRequest request, bool approve);
  Future<SyncAck?> sendData(List<int> data);
  Future<void> sendAck(List<int> ackData);
  Future<void> disconnect();
  void dispose();
}

/// A mock implementation of SyncTransport for testing.
class MockSyncTransport implements SyncTransport {
  MockSyncTransport() {
    _deviceFoundController = StreamController<SyncDevice>.broadcast();
    _sessionStateController = StreamController<SyncSessionState>.broadcast();
    _bytesReceivedController = StreamController<List<int>>.broadcast();
    _progressController = StreamController<double>.broadcast();
    _pairingRequestController = StreamController<PairingRequest>.broadcast();
  }

  late final StreamController<SyncDevice> _deviceFoundController;
  late final StreamController<SyncSessionState> _sessionStateController;
  late final StreamController<List<int>> _bytesReceivedController;
  late final StreamController<double> _progressController;
  late final StreamController<PairingRequest> _pairingRequestController;

  bool isAdvertising = false;
  bool isDiscovering = false;
  bool connectToDeviceResult = true;
  SyncSessionState sessionState = const SyncSessionState.idle();
  bool _isInitialized = false;
  String? deviceId;

  Future<void> Function(List<int> data)? onSend;
  SyncAck? sendResult = const SyncAck(receivedNoteIds: [], rejectedNoteIds: []);
  String? lastPairingCode;
  PairingRequest? lastRespondedPairing;
  bool? lastPairingApproved;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
    deviceId ??= 'mock-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<String?> getCurrentDeviceId() async {
    await initialize();
    return deviceId;
  }

  @override
  List<String> get localMultiaddresses => const [];

  @override
  Stream<SyncDevice> get deviceFoundStream => _deviceFoundController.stream;

  @override
  Stream<SyncSessionState> get sessionStateStream =>
      _sessionStateController.stream;

  @override
  Stream<List<int>> get bytesReceivedStream => _bytesReceivedController.stream;

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Stream<PairingRequest> get pairingRequestStream =>
      _pairingRequestController.stream;

  @override
  Future<void> startAdvertising() async {
    isAdvertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    isAdvertising = false;
  }

  @override
  Future<void> startDiscovery() async {
    isDiscovering = true;
  }

  @override
  Future<void> stopDiscovery() async {
    isDiscovering = false;
  }

  @override
  Future<bool> connectToDevice(SyncDevice device, {String? pairingCode}) async {
    lastPairingCode = pairingCode;
    return connectToDeviceResult;
  }

  @override
  Future<void> respondToPairing(PairingRequest request, bool approve) async {
    lastRespondedPairing = request;
    lastPairingApproved = approve;
  }

  @override
  Future<SyncAck?> sendData(List<int> data) async {
    if (onSend != null) {
      await onSend!(data);
    }
    return sendResult;
  }

  @override
  Future<void> sendAck(List<int> ackData) async {}

  @override
  Future<void> disconnect() async {
    isAdvertising = false;
    isDiscovering = false;
    sessionState = const SyncSessionState.idle();
  }

  @override
  void dispose() {
    _deviceFoundController.close();
    _sessionStateController.close();
    _bytesReceivedController.close();
    _progressController.close();
    if (!_pairingRequestController.isClosed) {
      _pairingRequestController.close();
    }
  }

  void emitDeviceFound(SyncDevice device) {
    _deviceFoundController.add(device);
  }

  void emitStateChanged(SyncSessionState state) {
    sessionState = state;
    _sessionStateController.add(state);
  }

  void emitBytesReceived(List<int> data) {
    _bytesReceivedController.add(data);
  }

  void emitProgress(double progress) {
    _progressController.add(progress);
  }

  void emitPairingRequest(PairingRequest request) {
    _pairingRequestController.add(request);
  }
}
