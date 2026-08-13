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
  });

  final String deviceId;
  final String deviceName;
  final bool isOnline;
  final String? hostAddress;
  final int? port;

  /// libp2p multiaddrs (e.g. `/ip4/192.168.1.50/udp/4001/udx`) advertised by
  /// the peer. Null for transports that only expose [hostAddress]/[port].
  final List<String>? multiaddresses;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
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
  void dispose() {}

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
