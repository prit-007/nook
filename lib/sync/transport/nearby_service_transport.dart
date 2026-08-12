import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:nearby_service/nearby_service.dart' as ns;
import 'package:uuid/uuid.dart';

import '../protocol/sync_bundle.dart';
import 'sync_transport.dart';

/// Concrete [SyncTransport] implementation using the `nearby_service` package.
///
/// Transfer protocol:
/// 1. Sender sends a JSON header: {type: 'sync_header', bundleSizeBytes, checksum, totalChunks, bundleId}
/// 2. Sender streams each chunk as JSON: {type: 'sync_chunk', bundleId, seq, total, data: base64}
/// 3. Receiver reassembles chunks, verifies SHA-256 checksum, emits bytes
/// 4. Receiver sends ack: {type: 'sync_ack', received: [ids], rejected: [ids]}
/// 5. Sender waits for ack with timeout, then completes
class NearbyServiceTransport implements SyncTransport {
  NearbyServiceTransport(
      {ns.NearbyService? service, this.chunkSize = 64 * 1024})
      : _service = service ?? ns.NearbyService.getInstance();

  final ns.NearbyService _service;
  final int chunkSize;

  final _deviceFoundController = StreamController<SyncDevice>.broadcast();
  final _sessionStateController =
      StreamController<SyncSessionState>.broadcast();
  final _bytesReceivedController = StreamController<List<int>>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  StreamSubscription<List<ns.NearbyDevice>>? _peersSubscription;
  StreamSubscription<ns.NearbyDevice?>? _connectionSubscription;
  StreamSubscription<ns.CommunicationChannelState>? _channelStateSubscription;

  String? _connectedDeviceId;
  ns.NearbyDeviceInfo? _connectedDeviceInfo;
  bool _initialized = false;

  // Incoming-bundle reassembly buffer.
  String? _incomingBundleId;
  int _incomingTotalChunks = 0;
  String? _incomingChecksum;
  final _incomingChunks = <int, String>{};

  // Outgoing ack — sendData waits on this.
  Completer<void>? _ackCompleter;

  @override
  Stream<SyncDevice> get deviceFoundStream => _deviceFoundController.stream;

  @override
  Stream<SyncSessionState> get sessionStateStream =>
      _sessionStateController.stream;

  @override
  Stream<List<int>> get bytesReceivedStream => _bytesReceivedController.stream;

  @override
  Stream<double> get progressStream => _progressController.stream;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Initializes the nearby_service and requests platform permissions.
  Future<void> initialize() async {
    if (_initialized) return;

    await _service.initialize();
    _initialized = true;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        await _service.android?.requestPermissions();
      }
      await _service.android?.checkWifiService();
    } else {
      // Darwin: default to advertiser role (receiver).
      _service.darwin?.setIsBrowser(value: false);
    }
  }

  /// Switches Darwin to browser role (for sending/discovering).
  Future<void> setDarwinBrowserRole() async {
    if (Platform.isIOS || Platform.isMacOS) {
      _service.darwin?.setIsBrowser(value: true);
    }
  }

  /// Switches Darwin to advertiser role (for receiving).
  Future<void> setDarwinAdvertiserRole() async {
    if (Platform.isIOS || Platform.isMacOS) {
      _service.darwin?.setIsBrowser(value: false);
    }
  }

  /// Returns the current device info (id, displayName).
  Future<ns.NearbyDeviceInfo?> getCurrentDeviceInfo() async {
    await initialize();
    return _service.getCurrentDeviceInfo();
  }

  // ---------------------------------------------------------------------------
  // Advertising / Discovery
  // ---------------------------------------------------------------------------

  @override
  Future<void> startAdvertising() async {
    await initialize();
    _emitState(const SyncSessionState.advertising());
    // On Android, Wi-Fi Direct auto-advertises during discovery.
    // On Darwin, setIsBrowser(false) in initialize() handles advertising.
  }

  @override
  Future<void> stopAdvertising() async {
    _emitState(const SyncSessionState.idle());
  }

  @override
  Future<void> startDiscovery() async {
    await initialize();
    _emitState(const SyncSessionState.discovering());

    await _service.discover();

    unawaited(_peersSubscription?.cancel());
    _peersSubscription = _service.getPeersStream().listen((peers) {
      for (final peer in peers) {
        _deviceFoundController.add(SyncDevice(
          deviceId: peer.info.id,
          deviceName: peer.info.displayName,
          isOnline: peer.status.isConnected || peer.status.isAvailable,
        ));
      }
    });
  }

  @override
  Future<void> stopDiscovery() async {
    unawaited(_peersSubscription?.cancel());
    _peersSubscription = null;
    await _service.stopDiscovery();
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connects to a discovered device and starts the communication channel.
  Future<bool> connectToDevice(String deviceId) async {
    _emitState(const SyncSessionState.connecting());
    _connectedDeviceId = deviceId;

    // Listen for connection state changes.
    unawaited(_connectionSubscription?.cancel());
    _connectionSubscription =
        _service.getConnectedDeviceStreamById(deviceId).listen((device) {
      if (device == null) {
        _connectedDeviceId = null;
        _connectedDeviceInfo = null;
        _emitState(const SyncSessionState.error('Device disconnected'));
      }
    });

    final connected = await _service.connectById(deviceId);
    if (!connected) {
      _emitState(const SyncSessionState.error('Connection failed'));
      return false;
    }

    // Cache device info for sendAck / sendData.
    _connectedDeviceInfo = await _getConnectedDeviceInfo();

    // Set up communication channel with message and file listeners.
    final channelReady = Completer<bool>();

    await _service.startCommunicationChannel(
      ns.NearbyCommunicationChannelData(
        deviceId,
        messagesListener: ns.NearbyServiceMessagesListener(
          onData: _handleIncomingMessage,
          onCreated: () {
            if (!channelReady.isCompleted) channelReady.complete(true);
          },
          onDone: () {},
          onError: (Object e, [StackTrace? stack]) {
            if (!channelReady.isCompleted) channelReady.completeError(e);
          },
        ),
        filesListener: ns.NearbyServiceFilesListener(
          onData: _handleIncomingFiles,
          onCreated: () {},
          onDone: () {},
          onError: (Object e, [StackTrace? stack]) {},
        ),
      ),
    );

    unawaited(_channelStateSubscription?.cancel());
    _channelStateSubscription =
        _service.getCommunicationChannelStateStream().listen((state) {
      if (state == ns.CommunicationChannelState.connected) {
        _emitState(const SyncSessionState.connected());
      }
    });

    return channelReady.future;
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  @override
  Future<void> sendData(List<int> data) async {
    if (_connectedDeviceInfo == null) {
      _emitState(const SyncSessionState.error('No device connected'));
      return;
    }

    _emitState(const SyncSessionState.transferring());

    try {
      final bytes = Uint8List.fromList(data);
      final checksum = sha256.convert(bytes).toString();
      final bundleId = const Uuid().v4();

      final chunks = SyncBundle.splitIntoChunks(bytes, chunkSize: chunkSize);

      // 1. Send header.
      await _sendText(jsonEncode({
        'type': 'sync_header',
        'bundleId': bundleId,
        'bundleSizeBytes': bytes.length,
        'checksum': checksum,
        'totalChunks': chunks.length,
      }));

      // 2. Send each chunk with progress.
      for (var i = 0; i < chunks.length; i++) {
        await _sendText(jsonEncode({
          'type': 'sync_chunk',
          'bundleId': bundleId,
          'seq': i,
          'total': chunks.length,
          'data': base64Encode(chunks[i]),
        }));
        _emitProgress((i + 1) / chunks.length);
      }

      // 3. Wait for ack from receiver.
      _ackCompleter = Completer<void>();
      await _ackCompleter!.future.timeout(const Duration(seconds: 30));
      _ackCompleter = null;

      _emitProgress(1.0);
      _emitState(const SyncSessionState.complete());
    } on TimeoutException {
      _emitState(const SyncSessionState.error('Timed out waiting for ack'));
    } catch (e) {
      _emitState(SyncSessionState.error('Send failed: $e'));
    }
  }

  @override
  Future<void> sendAck(List<int> ackData) async {
    if (_connectedDeviceInfo == null) return;
    await _sendText(jsonEncode({
      'type': 'sync_ack',
      'data': base64Encode(ackData),
    }));
  }

  // ---------------------------------------------------------------------------
  // Receive
  // ---------------------------------------------------------------------------

  void _handleIncomingMessage(ns.ReceivedNearbyMessage message) {
    // Cache sender info so sendAck can address the remote device.
    _connectedDeviceInfo ??= message.sender;

    message.content.byType(
      onTextRequest: (request) {
        _handleIncomingText(request.value);
      },
      onTextResponse: (response) {},
      onFilesRequest: (request) {
        // Auto-accept file transfers (legacy / doodle-image path).
        _service.send(
          ns.OutgoingNearbyMessage(
            content: ns.NearbyMessageFilesResponse(
              isAccepted: true,
              id: request.id,
            ),
            receiver: message.sender,
          ),
        );
      },
      onFilesResponse: (response) {},
    );
  }

  void _handleIncomingText(String value) {
    final map = jsonDecode(value) as Map<String, dynamic>;
    final type = map['type'] as String?;

    switch (type) {
      case 'sync_header':
        _incomingBundleId = map['bundleId'] as String;
        _incomingTotalChunks = map['totalChunks'] as int;
        _incomingChecksum = map['checksum'] as String;
        _incomingChunks.clear();
        break;

      case 'sync_chunk':
        final bundleId = map['bundleId'] as String;
        if (_incomingBundleId != bundleId) return; // stale chunk, ignore.
        final seq = map['seq'] as int;
        _incomingChunks[seq] = map['data'] as String;
        _emitProgress(_incomingChunks.length / _incomingTotalChunks);
        if (_incomingChunks.length == _incomingTotalChunks) {
          _reassembleBundle();
        }
        break;

      case 'sync_ack':
        if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
          _ackCompleter!.complete();
        }
        break;
    }
  }

  void _reassembleBundle() {
    final chunkList = <Uint8List>[];
    for (var i = 0; i < _incomingTotalChunks; i++) {
      chunkList.add(base64Decode(_incomingChunks[i]!));
    }
    final bytes = SyncBundle.reassembleChunks(chunkList);

    // Verify checksum before emitting.
    final checksum = sha256.convert(bytes).toString();
    if (_incomingChecksum != null && checksum != _incomingChecksum) {
      _emitState(const SyncSessionState.error('Checksum mismatch'));
      _resetIncomingBuffer();
      return;
    }

    _bytesReceivedController.add(bytes);
    _emitProgress(1.0);
    _resetIncomingBuffer();
  }

  void _resetIncomingBuffer() {
    _incomingBundleId = null;
    _incomingTotalChunks = 0;
    _incomingChecksum = null;
    _incomingChunks.clear();
  }

  void _handleIncomingFiles(ns.ReceivedNearbyFilesPack pack) {
    for (final fileInfo in pack.files) {
      final file = File(fileInfo.path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        _bytesReceivedController.add(bytes);
        // Clean up temp file.
        file.deleteSync();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  @override
  Future<void> disconnect() async {
    unawaited(_peersSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_channelStateSubscription?.cancel());
    _peersSubscription = null;
    _connectionSubscription = null;
    _channelStateSubscription = null;

    if (_connectedDeviceId != null) {
      await _service.disconnectById(_connectedDeviceId);
      await _service.endCommunicationChannel();
      _connectedDeviceId = null;
    }
    _connectedDeviceInfo = null;
    _resetIncomingBuffer();

    await _service.stopDiscovery();
    _emitState(const SyncSessionState.idle());
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _sendText(String value) async {
    final receiver = _connectedDeviceInfo;
    if (receiver == null) {
      throw StateError('No connected device to send to');
    }
    await _service.send(
      ns.OutgoingNearbyMessage(
        content: ns.NearbyMessageTextRequest.create(value: value),
        receiver: receiver,
      ),
    );
  }

  Future<ns.NearbyDeviceInfo?> _getConnectedDeviceInfo() async {
    if (_connectedDeviceId == null) return null;
    final peers = await _service.getPeers();
    for (final peer in peers) {
      if (peer.info.id == _connectedDeviceId) {
        return peer.info;
      }
    }
    return null;
  }

  void _emitState(SyncSessionState state) {
    _sessionStateController.add(state);
  }

  void _emitProgress(double progress) {
    _progressController.add(progress);
  }

  /// Cleans up all resources.
  void dispose() {
    unawaited(_peersSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_channelStateSubscription?.cancel());
    _deviceFoundController.close();
    _sessionStateController.close();
    _bytesReceivedController.close();
    _progressController.close();
  }
}
