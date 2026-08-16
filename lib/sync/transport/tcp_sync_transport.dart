import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../crypto/sync_session_cipher.dart';
import '../protocol/sync_bundle.dart';
import 'sync_transport.dart';

/// mDNS service type for Nook sync.
const String kNookSyncServiceType = '_nook-sync._tcp';

/// Protocol version with mandatory E2E encryption (ECDH + AES-256-GCM).
const String kSyncProtocolVersion = '1.1';

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
    String? localDeviceName,
    this.pairingTimeout = const Duration(seconds: 30),
    this.ackTimeout = const Duration(seconds: 60),
  })  : _serviceName = serviceName ?? 'Nook',
        _configuredDeviceName = localDeviceName ?? 'Nook';

  final int chunkSize;
  final String _serviceName;
  final String _configuredDeviceName;
  final Duration pairingTimeout;
  final Duration ackTimeout;

  final _deviceFoundController = StreamController<SyncDevice>.broadcast();
  final _sessionStateController =
      StreamController<SyncSessionState>.broadcast();
  final _bytesReceivedController = StreamController<List<int>>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _pairingRequestController =
      StreamController<PairingRequest>.broadcast();

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<dynamic>? _broadcastSubscription;
  StreamSubscription<dynamic>? _discoverySubscription;

  ServerSocket? _serverSocket;
  Socket? _outgoingSocket;
  Socket? _incomingSocket;
  StreamSubscription<Socket>? _serverSubscription;
  StreamSubscription<List<int>>? _socketSubscription;

  /// During a handshake, protocol frames (identity, pairing_confirm) are
  /// consumed one at a time by [_awaitNextFrame]. Frames that arrive before
  /// the next read is registered are buffered here so they are never lost.
  final _protoFrames = Queue<String>();
  final _protoWaiters = Queue<Completer<String>>();
  bool _handshaking = false;

  /// Sockets waiting for receiver-side pairing approval.
  final _pendingSockets = <String, Socket>{};

  late String _localDeviceId;
  late String _localDeviceName;

  String? _connectedDeviceId;

  String? _incomingBundleId;
  int _incomingTotalChunks = 0;
  String? _incomingChecksum;
  final _incomingChunks = <int, String>{};

  Completer<void>? _ackCompleter;
  Uint8List? _ackData;

  /// Serializes frame writes per socket so two concurrent [socket.add] calls
  /// can never interleave length prefixes and payloads on the wire.
  final Map<Socket, _SocketWriteQueue> _writeQueues = {};

  /// E2E encryption session (ECDH key exchange + AES-256-GCM).
  ///
  /// Null until the handshake begins; frames are plaintext only for the
  /// identity exchange and become encrypted once both public keys are known.
  SyncSessionCipher? _sessionCipher;

  /// Pending receiver-side handshakes keyed by connection id, so crypto state
  /// survives between the hello read and the user's pairing confirmation.
  final Map<String, SyncSessionCipher> _pendingHandshakes = {};

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

  @override
  Stream<PairingRequest> get pairingRequestStream =>
      _pairingRequestController.stream;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _localDeviceId = const Uuid().v4();
    _localDeviceName = _configuredDeviceName;
    _initialized = true;
  }

  @override
  bool get isInitialized => _initialized;

  /// Returns the current device info.
  @override
  Future<String?> getCurrentDeviceId() async {
    await initialize();
    return _localDeviceId;
  }

  /// Manual dial-in is only exposed by the libp2p/UDX transport (the default);
  /// the legacy TCP transport reports none so the send screen's manual-entry
  /// path never proposes a non-dialable address.
  @override
  List<String> get localMultiaddresses => const [];

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
    _broadcastSubscription = _broadcast!.eventStream?.listen((event) {
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
    await _broadcastSubscription?.cancel();
    _broadcastSubscription = null;
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

    _discoverySubscription = _discovery!.eventStream?.listen((event) async {
      if (event is BonsoirDiscoveryServiceFoundEvent) {
        // Resolve to get IP address.
        await _discovery!.serviceResolver.resolveService(event.service);
      } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
        final service = event.service;
        final hostAddress = service.hostAddress;
        if (hostAddress == null) return;

        final deviceId = service.attributes['deviceId'] ?? 'unknown';
        final deviceName = service.attributes['deviceName'] ?? 'Unknown Device';

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
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _discovery = null;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<bool> connectToDevice(SyncDevice device, {String? pairingCode}) async {
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

      // Start the persistent, buffered listener up front so handshake frames
      // (identity + pairing_confirm) can arrive back-to-back without loss.
      _setupSocketListener(_outgoingSocket!);
      _handshaking = true;

      // Begin the E2E handshake: generate an ephemeral ECDH key pair.
      final session = SyncSessionCipher();
      _sessionCipher = session;
      await session.beginHandshake();

      // Send our identity (pairing code included when provided).
      await _writeFrame(
          _outgoingSocket!,
          utf8.encode(jsonEncode({
            'deviceId': _localDeviceId,
            'deviceName': _localDeviceName,
            'protocolVersion': kSyncProtocolVersion,
            'publicKey': base64Encode(session.exportPublicKey()),
            if (pairingCode != null) 'pairingCode': pairingCode,
          })));

      // Read their identity.
      final identityFrame = await _awaitNextFrame();
      final remoteIdentity = jsonDecode(identityFrame);

      _connectedDeviceId = remoteIdentity['deviceId'] as String;

      // Complete the key exchange using the peer's public key. The identity
      // frame is processed by [_handleFrame], which completes the exchange as
      // soon as the public key arrives; this is the fallback for callers that
      // receive the identity outside the frame pump.
      final remotePublicKey = remoteIdentity['publicKey'] as String?;
      if (remotePublicKey == null) {
        _handshaking = false;
        _protoFrames.clear();
        _emitState(const SyncSessionState.error(
          'Peer does not support encrypted sync',
        ));
        await _outgoingSocket?.close();
        _outgoingSocket = null;
        return false;
      }
      if (!session.isActive) {
        await session.completeKeyExchange(base64Decode(remotePublicKey));
      }

      // If a pairing code was exchanged, wait for the receiver to confirm it
      // before proceeding.
      if (pairingCode != null) {
        final confirmFrame = await _awaitNextFrame().timeout(pairingTimeout);
        final confirm = jsonDecode(confirmFrame);
        if (confirm['type'] != 'pairing_confirm') {
          _handshaking = false;
          _protoFrames.clear();
          _emitState(const SyncSessionState.error(
            'Pairing rejected',
            outcome: SyncOutcomeCategory.rejected,
          ));
          await _outgoingSocket?.close();
          _outgoingSocket = null;
          return false;
        }
      }

      _handshaking = false;
      _protoFrames.clear();
      _emitState(const SyncSessionState.connected());

      return true;
    } on TimeoutException {
      _handshaking = false;
      _protoFrames.clear();
      _emitState(const SyncSessionState.error(
        'Pairing timed out',
        outcome: SyncOutcomeCategory.timedOut,
      ));
      await _outgoingSocket?.close();
      _outgoingSocket = null;
      return false;
    } catch (e) {
      _handshaking = false;
      _protoFrames.clear();
      _emitState(SyncSessionState.error('Connection failed: $e'));
      await _outgoingSocket?.close();
      _outgoingSocket = null;
      return false;
    }
  }

  /// Awaits the next full protocol frame delivered by the persistent listener.
  Future<String> _awaitNextFrame() {
    if (_protoFrames.isNotEmpty) {
      return Future.value(_protoFrames.removeFirst());
    }
    final completer = Completer<String>();
    _protoWaiters.add(completer);
    return completer.future;
  }

  /// Sends a [pairing_confirm] frame to the sender to approve their request.
  @override
  Future<void> respondToPairing(PairingRequest request, bool approve) async {
    final socket = _pendingSockets.remove(request.connectionId);
    if (socket == null) return;

    if (!approve) {
      // Reject — close the socket; the sender will surface an error.
      _pendingHandshakes.remove(request.connectionId);
      await socket.close();
      _emitState(const SyncSessionState.idle());
      return;
    }

    // Approve: activate the socket for data FIRST (so nothing is missed), then
    // tell the sender the pairing was confirmed.
    _incomingSocket = socket;
    _connectedDeviceId = request.remoteDeviceId;
    _sessionCipher = _pendingHandshakes.remove(request.connectionId);
    _emitState(const SyncSessionState.connected());
    _setupSocketListener(socket);
    await _writeFrame(
        socket, utf8.encode(jsonEncode({'type': 'pairing_confirm'})));
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  @override
  Future<SyncAck?> sendData(List<int> data) async {
    final socket = _outgoingSocket ?? _incomingSocket;
    if (socket == null) {
      _emitState(const SyncSessionState.error('No device connected'));
      return null;
    }

    _emitState(const SyncSessionState.transferring());

    try {
      final bytes = Uint8List.fromList(data);
      final checksum = sha256.convert(bytes).toString();
      final bundleId = const Uuid().v4();

      final chunks = SyncBundle.splitIntoChunks(bytes, chunkSize: chunkSize);

      // Attempt the send; retry the full bundle once if the ack is missed.
      for (var attempt = 0; attempt < 2; attempt++) {
        _ackData = null;
        _ackCompleter = Completer<void>();

        // 1. Send header.
        await _writeFrame(
            socket,
            utf8.encode(jsonEncode({
              'type': 'sync_header',
              'bundleId': bundleId,
              'bundleSizeBytes': bytes.length,
              'checksum': checksum,
              'totalChunks': chunks.length,
            })));

        // 2. Send each chunk with progress.
        for (var i = 0; i < chunks.length; i++) {
          await _writeFrame(
              socket,
              utf8.encode(jsonEncode({
                'type': 'sync_chunk',
                'bundleId': bundleId,
                'seq': i,
                'total': chunks.length,
                'data': base64Encode(chunks[i]),
              })));
          _emitProgress((i + 1) / chunks.length);
        }

        // 3. Wait for ack from receiver.
        try {
          await _ackCompleter!.future.timeout(ackTimeout);
          _emitProgress(1.0);
          _emitState(const SyncSessionState.complete());
          return _ackData != null
              ? SyncAck.fromCbor(_ackData!)
              : const SyncAck(receivedNoteIds: [], rejectedNoteIds: []);
        } on TimeoutException {
          if (attempt == 1) {
            _emitState(const SyncSessionState.error(
              'Timed out waiting for ack',
              outcome: SyncOutcomeCategory.timedOut,
            ));
            return null;
          }
          // First timeout — retry the whole bundle once.
        }
      }

      _emitState(const SyncSessionState.error(
        'Timed out waiting for ack',
        outcome: SyncOutcomeCategory.timedOut,
      ));
      return null;
    } catch (e) {
      _emitState(SyncSessionState.error('Send failed: $e'));
      return null;
    }
  }

  @override
  Future<void> sendAck(List<int> ackData) async {
    final socket = _outgoingSocket ?? _incomingSocket;
    if (socket == null) return;
    await _writeFrame(
        socket,
        utf8.encode(jsonEncode({
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
        _ackData = base64Decode(map['data'] as String);
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
      nookLog(NookLogKey.sync, 'TCP sync checksum mismatch', LogLevel.error);
      _emitState(const SyncSessionState.error(
        'Checksum mismatch',
        outcome: SyncOutcomeCategory.protocol,
      ));
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
        // Only one active connection at a time: a second device connecting
        // mid-transfer must not cancel the in-flight socket listener.
        if (_incomingSocket != null || _outgoingSocket != null) {
          _emitState(const SyncSessionState.error(
            'Already connected to a device',
          ));
          await socket.close().catchError((_) {});
          return;
        }

        _emitState(const SyncSessionState.connecting());

        try {
          // Read identity from incoming connection.
          final identityFrame = await _readFrame(socket);
          final remoteIdentity = jsonDecode(utf8.decode(identityFrame));

          final remoteDeviceId = remoteIdentity['deviceId'] as String;
          final remoteDeviceName =
              (remoteIdentity['deviceName'] as String?) ?? 'Unknown Device';
          final pairingCode = remoteIdentity['pairingCode'] as String?;
          final remotePublicKey = remoteIdentity['publicKey'] as String?;

          if (remotePublicKey == null) {
            _emitState(const SyncSessionState.error(
              'Peer does not support encrypted sync',
            ));
            await socket.close();
            return;
          }

          // Begin our E2E handshake and complete it with the peer's key.
          final session = SyncSessionCipher();
          await session.beginHandshake();
          await session.completeKeyExchange(base64Decode(remotePublicKey));

          // Send our identity back (with our public key).
          await _writeFrame(
              socket,
              utf8.encode(jsonEncode({
                'deviceId': _localDeviceId,
                'deviceName': _localDeviceName,
                'protocolVersion': kSyncProtocolVersion,
                'publicKey': base64Encode(session.exportPublicKey()),
              })));

          // Mutual pairing: when a code is exchanged, the receiver must
          // confirm before any data is accepted.
          if (pairingCode != null) {
            final connectionId = const Uuid().v4();
            _pendingSockets[connectionId] = socket;
            _pendingHandshakes[connectionId] = session;
            _pairingRequestController.add(PairingRequest(
              remoteDeviceId: remoteDeviceId,
              remoteDeviceName: remoteDeviceName,
              pairingCode: pairingCode,
              connectionId: connectionId,
            ));
            return;
          }

          _incomingSocket = socket;
          _connectedDeviceId = remoteDeviceId;
          _sessionCipher = session;
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

  /// Maximum acceptable frame payload in bytes. Guards against a malicious or
  /// buggy sender advertising a huge frame and exhausting memory.
  static const int maxFrameSize = 512 * 1024 * 1024; // 512 MB

  void _setupSocketListener(Socket socket) {
    _socketSubscription?.cancel();

    final buffer = <int>[];

    _socketSubscription = socket.listen(
      (data) async {
        buffer.addAll(data);

        while (buffer.length >= 4) {
          final expectedLength = ByteData.sublistView(
            Uint8List.fromList(buffer.sublist(0, 4)),
          ).getUint32(0, Endian.big);

          if (expectedLength > maxFrameSize) {
            _emitState(SyncSessionState.error(
              'Frame too large ($expectedLength bytes)',
              outcome: SyncOutcomeCategory.protocol,
            ));
            _resetIncomingBuffer();
            buffer.clear();
            return;
          }

          if (buffer.length < 4 + expectedLength) break;

          final payload = buffer.sublist(4, 4 + expectedLength);
          buffer.removeRange(0, 4 + expectedLength);

          await _handleFrame(payload);
        }
      },
      onError: (error) {
        _emitState(SyncSessionState.error('Socket error: $error'));
      },
      onDone: () {
        if (_connectedDeviceId != null) {
          _emitState(const SyncSessionState.error(
            'Connection lost',
            outcome: SyncOutcomeCategory.connectionLost,
          ));
        }
      },
    );
  }

  Future<void> _handleFrame(List<int> payload) async {
    // Decrypt frames that arrive after the E2E key exchange. Frames received
    // during the plaintext identity handshake pass through unchanged.
    final decrypted = await _sessionCipher?.decryptFrame(payload) ?? payload;
    final text = utf8.decode(decrypted);
    if (_handshaking) {
      // The identity frame carries the peer's ECDH public key. Complete the
      // key exchange immediately so that any subsequent (encrypted) frame —
      // such as pairing_confirm — is decrypted correctly even if it arrives
      // back-to-back in the same TCP segment.
      final session = _sessionCipher;
      if (session != null && !session.isActive) {
        try {
          final map = jsonDecode(text);
          final publicKey = map is Map && map['publicKey'] is String
              ? map['publicKey'] as String
              : null;
          if (publicKey != null) {
            await session.completeKeyExchange(base64Decode(publicKey));
          }
        } on FormatException {
          // Not a JSON frame; leave key exchange to the caller.
        }
      }
      // Resolve the oldest awaiting read, or buffer for a read that is about
      // to be registered.
      if (_protoWaiters.isNotEmpty) {
        _protoWaiters.removeFirst().complete(text);
      } else {
        _protoFrames.add(text);
      }
    } else {
      _handleIncomingText(text);
    }
  }

  Future<void> _writeFrame(Socket socket, List<int> payload) async {
    final encrypted = await _sessionCipher?.encryptFrame(payload) ?? payload;
    final queue = _writeQueues.putIfAbsent(
      socket,
      () => _SocketWriteQueue(),
    );
    return queue.enqueue(socket, encrypted);
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

          if (expectedLength > maxFrameSize) {
            sub.cancel();
            completer.completeError(
              StateError('Frame too large ($expectedLength bytes)'),
            );
            return;
          }

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
          completer
              .completeError(StateError('Socket closed before frame complete'));
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
    _ackData = null;

    for (final socket in _pendingSockets.values) {
      await socket.close().catchError((_) {});
    }
    _pendingSockets.clear();
    _pendingHandshakes.clear();
    _sessionCipher = null;

    await _outgoingSocket?.close();
    _outgoingSocket = null;
    await _incomingSocket?.close();
    _incomingSocket = null;
    _writeQueues.clear();

    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _serverSocket?.close();
    _serverSocket = null;

    await _broadcast?.stop();
    await _broadcastSubscription?.cancel();
    _broadcastSubscription = null;
    _broadcast = null;
    await _discovery?.stop();
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
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
    if (!_pairingRequestController.isClosed) {
      _pairingRequestController.close();
    }
    unawaited(_socketSubscription?.cancel());
    unawaited(_serverSubscription?.cancel());
    unawaited(_broadcastSubscription?.cancel());
    unawaited(_discoverySubscription?.cancel());
    _writeQueues.clear();
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

/// Serializes writes to a single [Socket] so length-prefixed frames are never
/// interleaved on the wire.
class _SocketWriteQueue {
  Future<void>? _tail;

  Future<void> enqueue(Socket socket, List<int> payload) {
    final previous = _tail ?? Future<void>.value();
    final next = previous.then((_) async {
      final lengthBytes = ByteData(4)..setUint32(0, payload.length, Endian.big);
      socket.add(lengthBytes.buffer.asUint8List());
      socket.add(payload);
      await socket.flush();
    });
    // Keep the chain alive even if one write fails, so a later write is not
    // permanently stuck behind a failed one.
    _tail = next.catchError((_) {});
    return next;
  }
}
