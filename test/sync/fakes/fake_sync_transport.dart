import 'dart:async';

import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/transport/sync_transport.dart';

/// Deterministic in-memory [SyncTransport] fake for unit and widget tests.
///
/// Allows tests to simulate discovery, pairing approvals/rejections, and
/// payload delivery without opening UDP sockets or mDNS listeners.
class FakeSyncTransport implements SyncTransport {
  FakeSyncTransport({
    this.deviceId = 'fake-device-1',
    List<String>? localMultiaddresses,
  }) : _localMultiaddresses = localMultiaddresses ??
            const ['/ip4/127.0.0.1/udp/4001/udx/p2p/fake-device-1'];

  final String deviceId;
  final List<String> _localMultiaddresses;

  final _deviceFoundController = StreamController<SyncDevice>.broadcast();
  final _sessionStateController =
      StreamController<SyncSessionState>.broadcast();
  final _bytesReceivedController = StreamController<List<int>>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _pairingRequestController =
      StreamController<PairingRequest>.broadcast();

  bool _initialized = false;
  bool isAdvertising = false;
  bool isDiscovering = false;
  bool connectResult = true;
  SyncSessionState currentState = const SyncSessionState.idle();

  final List<SyncDevice> connectedDevices = [];
  final List<List<int>> sentPayloads = [];
  final List<List<int>> sentAcks = [];
  final List<(PairingRequest, bool)> pairingResponses = [];

  SyncAck? nextSendAck =
      const SyncAck(receivedNoteIds: [], rejectedNoteIds: []);

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
  bool get isInitialized => _initialized;

  @override
  List<String> get localMultiaddresses =>
      _initialized ? _localMultiaddresses : const [];

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<String?> getCurrentDeviceId() async {
    await initialize();
    return deviceId;
  }

  @override
  Future<void> startAdvertising() async {
    await initialize();
    isAdvertising = true;
    emitState(const SyncSessionState.advertising());
  }

  @override
  Future<void> stopAdvertising() async {
    isAdvertising = false;
  }

  @override
  Future<void> startDiscovery() async {
    await initialize();
    isDiscovering = true;
    emitState(const SyncSessionState.discovering());
  }

  @override
  Future<void> stopDiscovery() async {
    isDiscovering = false;
  }

  @override
  Future<bool> connectToDevice(SyncDevice device, {String? pairingCode}) async {
    await initialize();
    emitState(const SyncSessionState.connecting());
    if (!connectResult) {
      emitState(const SyncSessionState.error(
        'Connection failed',
        outcome: SyncOutcomeCategory.connectionLost,
      ));
      return false;
    }
    connectedDevices.add(device);
    emitState(const SyncSessionState.connected());
    return true;
  }

  @override
  Future<void> respondToPairing(PairingRequest request, bool approve) async {
    pairingResponses.add((request, approve));
  }

  @override
  Future<SyncAck?> sendData(List<int> data) async {
    emitState(const SyncSessionState.transferring());
    sentPayloads.add(data);
    emitProgress(1.0);
    emitState(const SyncSessionState.complete());
    return nextSendAck;
  }

  @override
  Future<void> sendAck(List<int> ackData) async {
    sentAcks.add(ackData);
  }

  @override
  Future<void> disconnect() async {
    isAdvertising = false;
    isDiscovering = false;
    emitState(const SyncSessionState.idle());
  }

  @override
  void dispose() {
    _deviceFoundController.close();
    _sessionStateController.close();
    _bytesReceivedController.close();
    _progressController.close();
    _pairingRequestController.close();
  }

  void emitDeviceFound(SyncDevice device) => _deviceFoundController.add(device);

  void emitState(SyncSessionState state) {
    currentState = state;
    _sessionStateController.add(state);
  }

  void emitBytesReceived(List<int> data) => _bytesReceivedController.add(data);

  void emitProgress(double progress) => _progressController.add(progress);

  void emitPairingRequest(PairingRequest request) =>
      _pairingRequestController.add(request);
}
