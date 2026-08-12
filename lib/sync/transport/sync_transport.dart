import 'dart:async';

/// Represents a nearby device discovered via the sync transport.
class SyncDevice {
  const SyncDevice({
    required this.deviceId,
    required this.deviceName,
    required this.isOnline,
  });

  final String deviceId;
  final String deviceName;
  final bool isOnline;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

/// State machine for a sync session.
class SyncSessionState {
  const SyncSessionState.idle() : error = null;
  const SyncSessionState.advertising() : error = null;
  const SyncSessionState.discovering() : error = null;
  const SyncSessionState.connecting() : error = null;
  const SyncSessionState.connected() : error = null;
  const SyncSessionState.transferring() : error = null;
  const SyncSessionState.complete() : error = null;
  const SyncSessionState.error(String this.error);

  final String? error;
}

/// Abstract interface for a sync transport (e.g., Nearby Connections, NSD).
///
/// Implementations wrap platform-specific discovery, pairing, and data transfer.
abstract class SyncTransport {
  Stream<SyncDevice> get deviceFoundStream;
  Stream<SyncSessionState> get sessionStateStream;
  Stream<List<int>> get bytesReceivedStream;
  Stream<double> get progressStream;

  Future<void> startAdvertising();
  Future<void> stopAdvertising();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> sendData(List<int> data);
  Future<void> sendAck(List<int> ackData);
  Future<void> disconnect();
}

/// A mock implementation of SyncTransport for testing.
class MockSyncTransport implements SyncTransport {
  MockSyncTransport() {
    _deviceFoundController = StreamController<SyncDevice>.broadcast();
    _sessionStateController = StreamController<SyncSessionState>.broadcast();
    _bytesReceivedController = StreamController<List<int>>.broadcast();
    _progressController = StreamController<double>.broadcast();
  }

  late final StreamController<SyncDevice> _deviceFoundController;
  late final StreamController<SyncSessionState> _sessionStateController;
  late final StreamController<List<int>> _bytesReceivedController;
  late final StreamController<double> _progressController;

  bool isAdvertising = false;
  bool isDiscovering = false;
  SyncSessionState sessionState = const SyncSessionState.idle();

  Future<void> Function(List<int> data)? onSend;

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
  Future<void> sendData(List<int> data) async {
    if (onSend != null) {
      await onSend!(data);
    }
  }

  @override
  Future<void> sendAck(List<int> ackData) async {}

  @override
  Future<void> disconnect() async {
    isAdvertising = false;
    isDiscovering = false;
    sessionState = const SyncSessionState.idle();
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
}
