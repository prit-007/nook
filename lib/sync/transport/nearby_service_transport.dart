import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:nearby_service/nearby_service.dart' as ns;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'sync_transport.dart';

/// Concrete [SyncTransport] implementation using the `nearby_service` package.
///
/// Uses Wi-Fi Direct on Android and Multipeer Connectivity on iOS/macOS.
/// Data transfer protocol:
/// 1. Sender writes CBOR bundle to a temp file
/// 2. Sends a text message with the file path + metadata
/// 3. Receiver gets the file via NearbyServiceFilesListener
class NearbyServiceTransport implements SyncTransport {
  NearbyServiceTransport({ns.NearbyService? service})
      : _service = service ?? ns.NearbyService.getInstance();

  final ns.NearbyService _service;

  final _deviceFoundController = StreamController<SyncDevice>.broadcast();
  final _sessionStateController =
      StreamController<SyncSessionState>.broadcast();
  final _bytesReceivedController = StreamController<List<int>>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  StreamSubscription<List<ns.NearbyDevice>>? _peersSubscription;
  StreamSubscription<ns.NearbyDevice?>? _connectionSubscription;
  StreamSubscription<ns.CommunicationChannelState>? _channelStateSubscription;

  String? _connectedDeviceId;
  bool _initialized = false;

  @override
  Stream<SyncDevice> get deviceFoundStream => _deviceFoundController.stream;

  @override
  Stream<SyncSessionState> get sessionStateStream =>
      _sessionStateController.stream;

  @override
  Stream<List<int>> get bytesReceivedStream => _bytesReceivedController.stream;

  @override
  Stream<double> get progressStream => _progressController.stream;

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
      // Darwin: default to advertiser role (receiver)
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

  @override
  Future<void> startAdvertising() async {
    await initialize();
    _emitState(const SyncSessionState.advertising());
    // On Android, Wi-Fi Direct auto-advertises.
    // On Darwin, setIsBrowser(false) handles advertising.
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

    _peersSubscription?.cancel();
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
    _peersSubscription?.cancel();
    _peersSubscription = null;
    await _service.stopDiscovery();
  }

  @override
  Future<void> sendData(List<int> data) async {
    if (_connectedDeviceId == null) {
      _emitState(const SyncSessionState.error('No device connected'));
      return;
    }

    _emitState(const SyncSessionState.transferring());

    try {
      final tempDir = await getTemporaryDirectory();
      final bundleId = const Uuid().v4();
      final filePath = '${tempDir.path}/sync_bundle_$bundleId.cbor';
      final file = File(filePath);
      await file.writeAsBytes(data);

      // Send a text message with the bundle metadata
      final fileInfo = jsonEncode({
        'type': 'sync_bundle',
        'filePath': filePath,
        'sizeBytes': data.length,
      });

      final connectedDevice = await _getConnectedDeviceInfo();
      if (connectedDevice == null) {
        _emitState(const SyncSessionState.error('Connected device not found'));
        return;
      }

      await _service.send(
        ns.OutgoingNearbyMessage(
          content: ns.NearbyMessageTextRequest.create(value: fileInfo),
          receiver: connectedDevice,
        ),
      );

      // Also send the file itself
      await _service.send(
        ns.OutgoingNearbyMessage(
          content: ns.NearbyMessageFilesRequest.create(
            files: [ns.NearbyFileInfo(path: filePath)],
          ),
          receiver: connectedDevice,
        ),
      );

      _emitProgress(1.0);
      _emitState(const SyncSessionState.complete());
    } catch (e) {
      _emitState(SyncSessionState.error('Send failed: $e'));
    }
  }

  @override
  Future<void> disconnect() async {
    _peersSubscription?.cancel();
    _connectionSubscription?.cancel();
    _channelStateSubscription?.cancel();
    _peersSubscription = null;
    _connectionSubscription = null;
    _channelStateSubscription = null;

    if (_connectedDeviceId != null) {
      await _service.disconnectById(_connectedDeviceId);
      await _service.endCommunicationChannel();
      _connectedDeviceId = null;
    }

    await _service.stopDiscovery();
    _emitState(const SyncSessionState.idle());
  }

  /// Connects to a discovered device and starts the communication channel.
  Future<bool> connectToDevice(String deviceId) async {
    _emitState(const SyncSessionState.connecting());
    _connectedDeviceId = deviceId;

    // Listen for connection state changes
    _connectionSubscription?.cancel();
    _connectionSubscription =
        _service.getConnectedDeviceStreamById(deviceId).listen((device) {
      if (device == null) {
        _connectedDeviceId = null;
        _emitState(const SyncSessionState.error('Device disconnected'));
      }
    });

    final connected = await _service.connectById(deviceId);
    if (!connected) {
      _emitState(const SyncSessionState.error('Connection failed'));
      return false;
    }

    // Set up communication channel with message and file listeners
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

    _channelStateSubscription?.cancel();
    _channelStateSubscription =
        _service.getCommunicationChannelStateStream().listen((state) {
      if (state == ns.CommunicationChannelState.connected) {
        _emitState(const SyncSessionState.connected());
      }
    });

    return channelReady.future;
  }

  void _handleIncomingMessage(ns.ReceivedNearbyMessage message) {
    message.content.byType(
      onTextRequest: (request) {
        // Could be a sync_header or other metadata
        // For now, we primarily handle file-based bundles
      },
      onTextResponse: (response) {},
      onFilesRequest: (request) {
        // Auto-accept file transfers
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

  void _handleIncomingFiles(ns.ReceivedNearbyFilesPack pack) {
    for (final fileInfo in pack.files) {
      final file = File(fileInfo.path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        _bytesReceivedController.add(bytes);
        // Clean up temp file
        file.deleteSync();
      }
    }
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
    _peersSubscription?.cancel();
    _connectionSubscription?.cancel();
    _channelStateSubscription?.cancel();
    _deviceFoundController.close();
    _sessionStateController.close();
    _bytesReceivedController.close();
    _progressController.close();
  }
}
