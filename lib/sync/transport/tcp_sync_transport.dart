import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../protocol/sync_bundle.dart';
import 'sync_transport.dart';

/// mDNS service type for Nook sync.
const String kNookSyncServiceType = '_nook-sync._tcp';

/// TCP-based sync transport using mDNS for discovery.
///
/// Wire protocol:
/// - All messages use length-prefixed frames: [4-byte big-endian length][payload]
/// - Identity handshake: JSON with deviceId, deviceName, protocolVersion
/// - Sync data: JSON header + JSON chunks (base64-encoded) + JSON ack
class TcpSyncTransport implements SyncTransport {
  TcpSyncTransport({
    this.chunkSize = 256 * 1024,
    String? serviceName,
  })  : _serviceName = serviceName ?? 'Nook';

  final int chunkSize;
  final String _serviceName;

  final _deviceFoundController = StreamController<SyncDevice>.broadcast();
  final _sessionStateController = StreamController<SyncSessionState>.broadcast();
  final _bytesReceivedController = StreamController<List<int>>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  ServerSocket? _serverSocket;
  Socket? _outgoingSocket;
  Socket? _incomingSocket;
  StreamSubscription<Socket>? _serverSubscription;
  StreamSubscription<List<int>>? _socketSubscription;

  late String _localDeviceId;
  late String _localDeviceName;

  String? _connectedDeviceId;

  String? _incomingBundleId;
  int _incomingTotalChunks = 0;
  String? _incomingChecksum;
  final _incomingChunks = <int, String>{};

  Completer<void>? _ackCompleter;

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

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;
    _localDeviceId = const Uuid().v4();
    _localDeviceName = 'Nook';
    _initialized = true;
  }

  /// Returns the current device info.
  Future<String?> getCurrentDeviceId() async {
    await initialize();
    return _localDeviceId;
  }

  // ---------------------------------------------------------------------------
  // Advertising (receiver mode)
  // ---------------------------------------------------------------------------

  @override
  Future<void> startAdvertising() async {
    await initialize();
    _emitState(const SyncSessionState.advertising());

    await _startTcpServer();

    final service = BonsoirService(
      name: _serviceName,
      type: kNookSyncServiceType,
      port: _serverSocket!.port,
      attributes: {
        'deviceId': _localDeviceId,
        'deviceName': _localDeviceName,
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    _broadcast!.eventStream?.listen((event) {
      if (event is BonsoirBroadcastNameAlreadyExistsEvent) {
        _emitState(const SyncSessionState.error(
          'Another Nook device is already visible on this network',
        ));
      }
    });
    await _broadcast!.start();
  }

  @override
  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    _broadcast = null;
    _emitState(const SyncSessionState.idle());
  }

  // ---------------------------------------------------------------------------
  // Discovery (sender mode)
  // ---------------------------------------------------------------------------

  @override
  Future<void> startDiscovery() async {
    await initialize();
    _emitState(const SyncSessionState.discovering());

    _discovery = BonsoirDiscovery(type: kNookSyncServiceType);
    await _discovery!.initialize();

    _discovery!.eventStream?.listen((event) async {
      if (event is BonsoirDiscoveryServiceFoundEvent) {
        // Resolve to get IP address.
        await _discovery!.serviceResolver.resolveService(event.service);
      } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
        final service = event.service;
        final hostAddress = service.hostAddress;
        if (hostAddress == null) return;

        final deviceId = service.attributes['deviceId'] ?? 'unknown';
        final deviceName =
            service.attributes['deviceName'] ?? 'Unknown Device';

        _deviceFoundController.add(SyncDevice(
          deviceId: deviceId,
          deviceName: deviceName,
          hostAddress: hostAddress,
          port: service.port,
          isOnline: true,
        ));
      } else if (event is BonsoirDiscoveryServiceLostEvent) {
        final deviceId = event.service.attributes['deviceId'];
        if (deviceId != null) {
          _deviceFoundController.add(SyncDevice(
            deviceId: deviceId,
            deviceName: '',
            isOnline: false,
          ));
        }
      }
    });

    await _discovery!.start();
  }

  @override
  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<bool> connectToDevice(SyncDevice device) async {
    if (device.hostAddress == null || device.port == null) {
      _emitState(const SyncSessionState.error('Device address unknown'));
      return false;
    }

    _emitState(const SyncSessionState.connecting());

    try {
      _outgoingSocket = await Socket.connect(
        device.hostAddress!,
        device.port!,
        timeout: const Duration(seconds: 10),
      );

      // Send our identity.
      await _writeFrame(_outgoingSocket!, utf8.encode(jsonEncode({
        'deviceId': _localDeviceId,
        'deviceName': _localDeviceName,
        'protocolVersion': '1.0',
      })));

      // Read their identity.
      final identityFrame = await _readFrame(_outgoingSocket!);
      final remoteIdentity = jsonDecode(utf8.decode(identityFrame));

      _connectedDeviceId = remoteIdentity['deviceId'] as String;
      _emitState(const SyncSessionState.connected());

      // Listen for acks and incoming data.
      _setupSocketListener(_outgoingSocket!);

      return true;
    } catch (e) {
      _emitState(SyncSessionState.error('Connection failed: $e'));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  @override
  Future<void> sendData(List<int> data) async {
    final socket = _outgoingSocket ?? _incomingSocket;
    if (socket == null) {
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
      await _writeFrame(socket, utf8.encode(jsonEncode({
        'type': 'sync_header',
        'bundleId': bundleId,
        'bundleSizeBytes': bytes.length,
        'checksum': checksum,
        'totalChunks': chunks.length,
      })));

      // 2. Send each chunk with progress.
      for (var i = 0; i < chunks.length; i++) {
        await _writeFrame(socket, utf8.encode(jsonEncode({
          'type': 'sync_chunk',
          'bundleId': bundleId,
          'seq': i,
          'total': chunks.length,
          'data': base64Encode(chunks[i]),
        })));
        _emitProgress((i + 1) / chunks.length);
      }

      // 3. Wait for ack from receiver.
      _ackCompleter = Completer<void>();
      await _ackCompleter!.future.timeout(const Duration(seconds: 60));
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
    final socket = _outgoingSocket ?? _incomingSocket;
    if (socket == null) return;
    await _writeFrame(socket, utf8.encode(jsonEncode({
      'type': 'sync_ack',
      'data': base64Encode(ackData),
    })));
  }

  // ---------------------------------------------------------------------------
  // Receive
  // ---------------------------------------------------------------------------

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
        if (_incomingBundleId != bundleId) return;
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

  // ---------------------------------------------------------------------------
  // TCP server
  // ---------------------------------------------------------------------------

  Future<void> _startTcpServer() async {
    _serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );

    _serverSubscription = _serverSocket!.listen(
      (socket) async {
        _emitState(const SyncSessionState.connecting());

        try {
          // Read identity from incoming connection.
          final identityFrame = await _readFrame(socket);
          final remoteIdentity = jsonDecode(utf8.decode(identityFrame));

          final remoteDeviceId = remoteIdentity['deviceId'] as String;

          // Send our identity back.
          await _writeFrame(socket, utf8.encode(jsonEncode({
            'deviceId': _localDeviceId,
            'deviceName': _localDeviceName,
            'protocolVersion': '1.0',
          })));

          _incomingSocket = socket;
          _connectedDeviceId = remoteDeviceId;
          _emitState(const SyncSessionState.connected());

          _setupSocketListener(socket);
        } catch (e) {
          _emitState(SyncSessionState.error('Handshake failed: $e'));
          await socket.close();
        }
      },
      onError: (error) {
        _emitState(SyncSessionState.error('Server error: $error'));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Socket framing
  // ---------------------------------------------------------------------------

  void _setupSocketListener(Socket socket) {
    _socketSubscription?.cancel();

    final buffer = <int>[];

    _socketSubscription = socket.listen(
      (data) {
        buffer.addAll(data);

        while (buffer.length >= 4) {
          final expectedLength = ByteData.sublistView(
            Uint8List.fromList(buffer.sublist(0, 4)),
          ).getUint32(0, Endian.big);

          if (buffer.length < 4 + expectedLength) break;

          final payload = buffer.sublist(4, 4 + expectedLength);
          buffer.removeRange(0, 4 + expectedLength);

          _handleFrame(payload);
        }
      },
      onError: (error) {
        _emitState(SyncSessionState.error('Socket error: $error'));
      },
      onDone: () {
        if (_connectedDeviceId != null) {
          _emitState(const SyncSessionState.error('Connection lost'));
        }
      },
    );
  }

  void _handleFrame(List<int> payload) {
    final text = utf8.decode(payload);
    _handleIncomingText(text);
  }

  Future<void> _writeFrame(Socket socket, List<int> payload) async {
    final lengthBytes = ByteData(4)..setUint32(0, payload.length, Endian.big);
    socket.add(lengthBytes.buffer.asUint8List());
    socket.add(payload);
    await socket.flush();
  }

  Future<List<int>> _readFrame(Socket socket) async {
    final completer = Completer<List<int>>();
    final buffer = <int>[];
    late StreamSubscription<List<int>> sub;

    sub = socket.listen(
      (data) {
        buffer.addAll(data);
        if (buffer.length >= 4 && !completer.isCompleted) {
          final expectedLength = ByteData.sublistView(
            Uint8List.fromList(buffer.sublist(0, 4)),
          ).getUint32(0, Endian.big);

          if (buffer.length >= 4 + expectedLength) {
            sub.cancel();
            completer.complete(buffer.sublist(4, 4 + expectedLength));
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
              StateError('Socket closed before frame complete'));
        }
      },
    );

    return completer.future.timeout(const Duration(seconds: 10));
  }

  // ---------------------------------------------------------------------------
  // Disconnect / dispose
  // ---------------------------------------------------------------------------

  @override
  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
      _ackCompleter!.completeError(StateError('Disconnected'));
    }
    _ackCompleter = null;

    await _outgoingSocket?.close();
    _outgoingSocket = null;
    await _incomingSocket?.close();
    _incomingSocket = null;

    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _serverSocket?.close();
    _serverSocket = null;

    await _broadcast?.stop();
    _broadcast = null;
    await _discovery?.stop();
    _discovery = null;

    _connectedDeviceId = null;
    _resetIncomingBuffer();
    _emitState(const SyncSessionState.idle());
  }

  @override
  void dispose() {
    _deviceFoundController.close();
    _sessionStateController.close();
    _bytesReceivedController.close();
    _progressController.close();
    _outgoingSocket?.destroy();
    _incomingSocket?.destroy();
    _serverSocket?.close();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _emitState(SyncSessionState state) {
    if (!_sessionStateController.isClosed) {
      _sessionStateController.add(state);
    }
  }

  void _emitProgress(double progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }
}
