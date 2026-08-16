import 'dart:async';
import 'dart:typed_data';

import 'package:dart_libp2p/config/config.dart' as p2p_config;
import 'package:dart_libp2p/core/host/host.dart';
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/network/context.dart';
import 'package:dart_libp2p/core/network/network.dart' show Reachability;
import 'package:dart_libp2p/core/network/stream.dart';
import 'package:dart_libp2p/core/peer/addr_info.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:dart_libp2p/p2p/security/noise/noise_protocol.dart';
import 'package:dart_libp2p/p2p/transport/connection_manager.dart'
    as p2p_conn_manager;
import 'package:dart_libp2p/p2p/transport/multiplexing/yamux/yamux_exceptions.dart';
import 'package:dart_libp2p/p2p/transport/udx_transport.dart';
import 'package:dart_udx/dart_udx.dart';
import 'package:uuid/uuid.dart';

import '../crypto/identity_store.dart';
import '../discovery/nook_mdns_discovery.dart';
import '../protocol/sync_bundle.dart';
import '../protocol/sync_message.dart';
import '../../core/providers/talker_provider.dart';
import 'sync_transport.dart';

/// libp2p protocol id for Nook sync streams.
const String kSyncNotenetProtocol = '/syncnotenet/sync/1.0.0';

/// libp2p-based sync transport built on dart_libp2p over UDX (UDP-based
/// reliable transport), with Noise encryption + Yamux multiplexing.
///
/// Wire model — one stream per transaction (request/response):
/// - Initiator: `connect` → open stream → write one [SyncMessage] envelope →
///   `closeWrite()` (half-close) → read the peer's response envelope to EOF.
/// - Acceptor: stream handler reads the request to EOF, then either holds the
///   stream while the user decides on pairing, or emits received bytes and
///   waits for the orchestrator's ack to write back on the same stream.
///
/// Every envelope is `[4B length][32B SHA-256][CBOR]` (see [SyncMessageCodec]);
/// Noise covers confidentiality/authenticity on top.
class Libp2pSyncTransport implements SyncTransport {
  Libp2pSyncTransport({
    String? localDeviceName,
    IdentityStore? identityStore,
    Duration pairingTimeout = const Duration(seconds: 30),
    Duration ackTimeout = const Duration(seconds: 60),
    this.heldStreamTimeout = const Duration(seconds: 120),
    this.listenAddress = '/ip4/0.0.0.0/udp/0/udx',
    this.discoveryNetworkEnabled = true,
  })  : _configuredDeviceName = localDeviceName ?? 'Nook',
        _pairingTimeout = pairingTimeout,
        _ackTimeout = ackTimeout {
    _identityStore = identityStore ?? IdentityStore();
  }

  final String _configuredDeviceName;
  final Duration _pairingTimeout;
  final Duration _ackTimeout;

  /// Multiaddr the libp2p host binds to. Defaults to all interfaces (port 0 =
  /// ephemeral). Tests override with a loopback address.
  final String listenAddress;

  /// When false, the mDNS advertise/discover layers become pure state changes
  /// and never touch the network. Keeps discovery hermetic (no multicast) in
  /// tests while still exercising real dials, pairing, and transfer.
  final bool discoveryNetworkEnabled;

  /// How long the receiver holds an undecided pairing stream before closing it.
  final Duration heldStreamTimeout;

  late final IdentityStore _identityStore;

  final _deviceFoundController = StreamController<SyncDevice>.broadcast();
  final _sessionStateController =
      StreamController<SyncSessionState>.broadcast();
  final _bytesReceivedController = StreamController<List<int>>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _pairingRequestController =
      StreamController<PairingRequest>.broadcast();

  Host? _host;
  NookMdnsDiscovery? _discovery;

  bool _initialized = false;
  String _localDeviceId = '';
  String _localDeviceName = '';

  /// Peer the initiator has paired with (set on successful pairing).
  PeerId? _connectedPeerId;

  /// Streams held awaiting a receiver-side pairing decision, keyed by request id.
  final Map<String, P2PStream> _heldStreams = {};
  final Map<String, Timer> _heldStreamTimers = {};

  /// The stream carrying the most recently emitted data bundle, awaiting the
  /// orchestrator's ack. Enforces one in-flight transfer at a time.
  P2PStream? _pendingAckStream;
  Timer? _pendingAckTimer;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

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
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final keyPair = await _identityStore.getKeyPair();
    final udx = UDX();
    final connMgr = p2p_conn_manager.ConnectionManager();

    final options = <p2p_config.Option>[
      p2p_config.Libp2p.identity(keyPair),
      p2p_config.Libp2p.connManager(connMgr),
      p2p_config.Libp2p.transport(
        UDXTransport(connManager: connMgr, udxInstance: udx),
      ),
      p2p_config.Libp2p.security(await NoiseSecurity.create(keyPair)),
      p2p_config.Libp2p.listenAddrs([MultiAddr(listenAddress)]),
      // A LAN-only app must not dial public peers. applyDefaults() hard-sets
      // enableAutoNAT=true after options are applied, so the only lever is to
      // force private reachability, which skips the ambient probing dials.
      p2p_config.Libp2p.forceReachability(Reachability.private),
      p2p_config.Libp2p.holePunching(false),
      // Keep every advertised address (the default factory strips loopback
      // and wildcard addrs, which would break dialing advertised addrs).
      p2p_config.Libp2p.addrsFactory((addrs) => addrs),
    ];

    final host = await p2p_config.Libp2p.new_(options);
    host.setStreamHandler(kSyncNotenetProtocol, _onIncomingStream);
    await host.start();

    _host = host;
    _localDeviceId = host.id.toString();
    _localDeviceName = _configuredDeviceName;
    _discovery = NookMdnsDiscovery(
      host,
      port: _udxListenPort(host),
      deviceName: _localDeviceName,
      networkEnabled: discoveryNetworkEnabled,
    );

    _initialized = true;
    nookLog(
      NookLogKey.sync,
      'libp2p host started (peer $_localDeviceId) on '
      '${host.network.listenAddresses.map((a) => a.toString()).join(', ')}',
      LogLevel.info,
    );
  }

  /// Returns the current device info (the libp2p peer id, stable per install).
  @override
  Future<String?> getCurrentDeviceId() async {
    await initialize();
    return _localDeviceId;
  }

  /// Dialable multiaddrs with the peer id suffixed, e.g.
  /// `/ip4/192.168.1.20/udp/52341/udx/p2p/12D3KooW...` — the addresses a sender
  /// can enter manually (see [SyncDevice.fromManualAddress]) to bypass mDNS
  /// discovery entirely. Uses `host.addrs` so the unspecified `0.0.0.0` bind
  /// resolves to the device's real LAN addresses. Empty until [initialize].
  @override
  List<String> get localMultiaddresses {
    final host = _host;
    if (host == null) return const [];
    return host.addrs
        .map((a) => '${a.toString()}/p2p/${host.id.toString()}')
        .toSet()
        .toList();
  }

  /// Test hook: simulate discovering [device] without multicast by injecting it
  /// into the mDNS discovery pipeline, which fans out through
  /// [deviceFoundStream] exactly as a real discovery would. Requires
  /// [startDiscovery] to have installed the discovery notifee.
  Future<void> debugInjectDiscoveredPeer(SyncDevice device) async {
    await initialize();
    final discovery = _discovery;
    if (discovery == null) return;
    final addrs = (device.multiaddresses ?? const [])
        .map((raw) => MultiAddr(raw))
        .toList();
    discovery.debugInjectPeer(
      AddrInfo(PeerId.fromString(device.deviceId), addrs),
      deviceName: device.deviceName,
    );
  }

  // ---------------------------------------------------------------------------
  // Advertising (receiver mode)
  // ---------------------------------------------------------------------------

  @override
  Future<void> startAdvertising() async {
    await initialize();
    nookLog(NookLogKey.sync, 'Advertising on mDNS (_syncnotenet._udp)',
        LogLevel.info);
    _emitState(const SyncSessionState.advertising());
    await _discovery!.advertiseOnly();
  }

  @override
  Future<void> stopAdvertising() async {
    await _discovery?.stop();
    nookLog(NookLogKey.sync, 'Advertising stopped', LogLevel.info);
    _emitState(const SyncSessionState.idle());
  }

  // ---------------------------------------------------------------------------
  // Discovery (sender mode)
  // ---------------------------------------------------------------------------

  @override
  Future<void> startDiscovery() async {
    await initialize();
    nookLog(NookLogKey.sync, 'Discovering peers over mDNS', LogLevel.info);
    _emitState(const SyncSessionState.discovering());
    _discovery!.notifee = _DiscoveryNotifee(
      _deviceFoundController,
      hostId: _host!.id,
    );
    await _discovery!.discoverOnly();
  }

  @override
  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    nookLog(NookLogKey.sync, 'Discovery stopped', LogLevel.info);
  }

  // ---------------------------------------------------------------------------
  // Connection + pairing (initiator)
  // ---------------------------------------------------------------------------

  @override
  Future<bool> connectToDevice(SyncDevice device, {String? pairingCode}) async {
    await initialize();

    final multiaddresses = device.multiaddresses;
    if (multiaddresses == null || multiaddresses.isEmpty) {
      _emitState(const SyncSessionState.error('Device address unknown'));
      return false;
    }

    _emitState(const SyncSessionState.connecting());

    try {
      final peerId = PeerId.fromString(device.deviceId);
      final addrs = _parseAddrs(multiaddresses, peerId);
      nookLog(
        NookLogKey.sync,
        'Dialing ${device.deviceName} via ${addrs.map((a) => a.toString()).join(', ')}',
        LogLevel.info,
      );

      await _host!.connect(
        AddrInfo(peerId, addrs),
        context: Context(timeout: _pairingTimeout),
      );
      nookLog(
        NookLogKey.sync,
        'Transport connected to ${device.deviceName}; opening sync stream',
        LogLevel.debug,
      );

      final stream = await _host!.newStream(
        peerId,
        [kSyncNotenetProtocol],
        Context(timeout: _pairingTimeout),
      );

      final requestId = const Uuid().v4();
      await stream.write(SyncMessageCodec.encode(SyncMessage(
        type: SyncMessageType.pairingRequest,
        senderDeviceId: _localDeviceId,
        senderDeviceName: _localDeviceName,
        requestId: requestId,
        pairingCode: pairingCode,
      )));
      await stream.closeWrite();
      nookLog(
        NookLogKey.sync,
        'Pairing request sent to ${device.deviceName}',
        LogLevel.debug,
      );

      final response = await _readMessageToEof(stream, _pairingTimeout);

      switch (response.type) {
        case SyncMessageType.pairingAccepted:
          _connectedPeerId = peerId;
          nookLog(
            NookLogKey.sync,
            'Pairing accepted by ${device.deviceName}',
            LogLevel.info,
          );
          _emitState(const SyncSessionState.connected());
          return true;
        case SyncMessageType.pairingRejected:
          nookLog(
            NookLogKey.sync,
            'Pairing rejected by ${device.deviceName}',
            LogLevel.warning,
          );
          _emitState(const SyncSessionState.error(
            'Pairing rejected',
            outcome: SyncOutcomeCategory.rejected,
          ));
          return false;
        default:
          nookLog(
            NookLogKey.sync,
            'Unexpected pairing response from ${device.deviceName}',
            LogLevel.error,
          );
          _emitState(const SyncSessionState.error(
            'Unexpected pairing response',
            outcome: SyncOutcomeCategory.protocol,
          ));
          return false;
      }
    } on TimeoutException {
      nookLog(NookLogKey.sync, 'Pairing with ${device.deviceName} timed out',
          LogLevel.warning);
      _emitState(const SyncSessionState.error(
        'Pairing timed out',
        outcome: SyncOutcomeCategory.timedOut,
      ));
      return false;
    } on YamuxException catch (e) {
      if (_isYamuxTimeout(e)) {
        nookLog(NookLogKey.sync, 'Pairing with ${device.deviceName} timed out',
            LogLevel.warning);
        _emitState(const SyncSessionState.error(
          'Pairing timed out',
          outcome: SyncOutcomeCategory.timedOut,
        ));
        return false;
      }
      nookLog(NookLogKey.sync, 'Connection to ${device.deviceName} failed: $e',
          LogLevel.error);
      _emitState(SyncSessionState.error('Connection failed: $e'));
      return false;
    } catch (e) {
      nookLog(NookLogKey.sync, 'Connection to ${device.deviceName} failed: $e',
          LogLevel.error);
      _emitState(SyncSessionState.error('Connection failed: $e'));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Respond to pairing (receiver)
  // ---------------------------------------------------------------------------

  @override
  Future<void> respondToPairing(PairingRequest request, bool approve) async {
    final stream = _heldStreams.remove(request.connectionId);
    _heldStreamTimers.remove(request.connectionId)?.cancel();
    if (stream == null) return;

    nookLog(
      NookLogKey.sync,
      'Responding to pairing from ${request.remoteDeviceName}: '
      '${approve ? 'approve' : 'reject'}',
      LogLevel.info,
    );

    try {
      await stream.write(SyncMessageCodec.encode(SyncMessage(
        type: approve
            ? SyncMessageType.pairingAccepted
            : SyncMessageType.pairingRejected,
        senderDeviceId: _localDeviceId,
        senderDeviceName: _localDeviceName,
      )));
      await stream.closeWrite();
      await stream.close();
      if (approve) {
        _emitState(const SyncSessionState.connected());
      } else {
        _emitState(const SyncSessionState.idle());
      }
    } catch (e) {
      nookLog(
        NookLogKey.sync,
        'Failed to respond to pairing from ${request.remoteDeviceName}: $e',
        LogLevel.error,
      );
      await stream.close().catchError((_) {});
      _emitState(SyncSessionState.error('Failed to respond to pairing: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Send (initiator)
  // ---------------------------------------------------------------------------

  @override
  Future<SyncAck?> sendData(List<int> data) async {
    await initialize();

    final peerId = _connectedPeerId;
    if (peerId == null) {
      _emitState(const SyncSessionState.error('No device connected'));
      return null;
    }

    _emitState(const SyncSessionState.transferring());

    try {
      final stream = await _host!.newStream(
        peerId,
        [kSyncNotenetProtocol],
        Context(timeout: _ackTimeout),
      );
      nookLog(
        NookLogKey.sync,
        'Opening data stream to send ${data.length} bytes',
        LogLevel.info,
      );

      final bytes = Uint8List.fromList(data);
      await stream.write(SyncMessageCodec.encode(SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: _localDeviceId,
        senderDeviceName: _localDeviceName,
        bundleBytes: bytes,
      )));
      _emitProgress(0.5);
      await stream.closeWrite();
      nookLog(
          NookLogKey.sync, 'Data bundle sent; awaiting ack', LogLevel.debug);

      final response = await _readMessageToEof(stream, _ackTimeout);

      if (response.type == SyncMessageType.ack && response.ack != null) {
        _emitProgress(1.0);
        _emitState(const SyncSessionState.complete());
        nookLog(
          NookLogKey.sync,
          'Ack received: ${response.ack!.receivedNoteIds.length} kept, '
          '${response.ack!.rejectedNoteIds.length} rejected',
          LogLevel.info,
        );
        return response.ack;
      }

      nookLog(
        NookLogKey.sync,
        'Unexpected response from peer (expected ack)',
        LogLevel.error,
      );
      _emitState(const SyncSessionState.error(
        'Unexpected response from peer',
        outcome: SyncOutcomeCategory.protocol,
      ));
      return null;
    } on TimeoutException {
      nookLog(NookLogKey.sync, 'Timed out waiting for ack', LogLevel.warning);
      _emitState(const SyncSessionState.error(
        'Timed out waiting for ack',
        outcome: SyncOutcomeCategory.timedOut,
      ));
      return null;
    } on YamuxException catch (e) {
      if (_isYamuxTimeout(e)) {
        nookLog(NookLogKey.sync, 'Timed out waiting for ack', LogLevel.warning);
        _emitState(const SyncSessionState.error(
          'Timed out waiting for ack',
          outcome: SyncOutcomeCategory.timedOut,
        ));
        return null;
      }
      nookLog(NookLogKey.sync, 'Send failed: $e', LogLevel.error);
      _emitState(SyncSessionState.error('Send failed: $e'));
      return null;
    } catch (e) {
      nookLog(NookLogKey.sync, 'Send failed: $e', LogLevel.error);
      _emitState(SyncSessionState.error('Send failed: $e'));
      return null;
    }
  }

  /// Writes the receiver's ack back on the stream that delivered the bundle.
  @override
  Future<void> sendAck(List<int> ackData) async {
    final stream = _pendingAckStream;
    if (stream == null) return;

    _pendingAckStream = null;
    _pendingAckTimer?.cancel();
    _pendingAckTimer = null;

    try {
      await stream.write(SyncMessageCodec.encode(SyncMessage(
        type: SyncMessageType.ack,
        senderDeviceId: _localDeviceId,
        senderDeviceName: _localDeviceName,
        ack: SyncAck.fromCbor(Uint8List.fromList(ackData)),
      )));
      await stream.closeWrite();
      await stream.close();
      nookLog(NookLogKey.sync, 'Ack sent to sender', LogLevel.info);
    } catch (e) {
      nookLog(NookLogKey.sync, 'Failed to send ack: $e', LogLevel.error);
      _emitState(SyncSessionState.error('Failed to send ack: $e'));
    }
  }

  // ---------------------------------------------------------------------------
  // Incoming streams (acceptor)
  // ---------------------------------------------------------------------------

  Future<void> _onIncomingStream(P2PStream stream, PeerId remotePeer) async {
    try {
      final message = await _readMessageToEof(stream, _ackTimeout);

      switch (message.type) {
        case SyncMessageType.pairingRequest:
          _handleIncomingPairingRequest(stream, message);
        case SyncMessageType.dataBundle:
          _handleIncomingDataBundle(stream, message);
        case SyncMessageType.ack:
        case SyncMessageType.pairingAccepted:
        case SyncMessageType.pairingRejected:
          // Unexpected on a fresh incoming stream; close politely.
          await stream.close();
      }
    } on TimeoutException {
      nookLog(
          NookLogKey.sync, 'Incoming stream read timed out', LogLevel.warning);
      await stream.close().catchError((_) {});
    } on YamuxStreamTimeoutException {
      nookLog(
        NookLogKey.sync,
        'Incoming stream read timed out (yamux)',
        LogLevel.warning,
      );
      await stream.close().catchError((_) {});
    } catch (e) {
      nookLog(
        NookLogKey.sync,
        'Incoming stream error: $e',
        LogLevel.error,
      );
      await stream.close().catchError((_) {});
    }
  }

  void _handleIncomingPairingRequest(P2PStream stream, SyncMessage message) {
    if (message.requestId == null) {
      unawaited(stream.close());
      return;
    }

    if (_heldStreams.isNotEmpty) {
      // A second pairing request while one is undecided: refuse it so the
      // sender sees a clear rejection instead of a hang.
      unawaited(
        stream
            .write(SyncMessageCodec.encode(SyncMessage(
              type: SyncMessageType.pairingRejected,
              senderDeviceId: _localDeviceId,
              senderDeviceName: _localDeviceName,
            )))
            .then((_) => stream.close()),
      );
      return;
    }

    final requestId = message.requestId!;
    _heldStreams[requestId] = stream;

    _heldStreamTimers[requestId] = Timer(heldStreamTimeout, () {
      final held = _heldStreams.remove(requestId);
      _heldStreamTimers.remove(requestId);
      unawaited(held?.close());
    });

    nookLog(
      NookLogKey.sync,
      'Incoming pairing request from ${message.senderDeviceName} '
      '(code ${message.pairingCode ?? 'none'})',
      LogLevel.info,
    );

    _pairingRequestController.add(PairingRequest(
      remoteDeviceId: message.senderDeviceId,
      remoteDeviceName: message.senderDeviceName,
      pairingCode: message.pairingCode ?? '',
      connectionId: requestId,
    ));
  }

  void _handleIncomingDataBundle(P2PStream stream, SyncMessage message) {
    final bundleBytes = message.bundleBytes;
    if (bundleBytes == null) {
      unawaited(stream.close());
      return;
    }

    if (_pendingAckStream != null) {
      // One transfer at a time: refuse the second so the sender gets a clear
      // protocol error rather than a silently dropped bundle.
      unawaited(stream.close());
      _emitState(const SyncSessionState.error(
        'Another transfer is already in progress',
        outcome: SyncOutcomeCategory.protocol,
      ));
      return;
    }

    _pendingAckStream = stream;
    _pendingAckTimer = Timer(_ackTimeout, () {
      _pendingAckStream = null;
      _pendingAckTimer = null;
      unawaited(stream.close());
    });

    nookLog(
      NookLogKey.sync,
      'Data bundle received: ${bundleBytes.length} bytes; waiting for ack',
      LogLevel.info,
    );
    _bytesReceivedController.add(bundleBytes);
  }

  // ---------------------------------------------------------------------------
  // Disconnect / dispose
  // ---------------------------------------------------------------------------

  @override
  Future<void> disconnect() async {
    await _discovery?.stop();
    _discovery = null;

    _connectedPeerId = null;

    for (final held in _heldStreams.values) {
      unawaited(held.close());
    }
    _heldStreams.clear();
    for (final timer in _heldStreamTimers.values) {
      timer.cancel();
    }
    _heldStreamTimers.clear();

    _pendingAckTimer?.cancel();
    _pendingAckTimer = null;
    if (_pendingAckStream != null) {
      unawaited(_pendingAckStream?.close());
      _pendingAckStream = null;
    }

    await _host?.close();
    _host = null;
    _initialized = false;
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
    unawaited(_host?.close());
    _host = null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Reads a single [SyncMessage] envelope from [stream], accumulating chunks
  /// until EOF (the peer has half-closed after writing the request/response).
  ///
  /// Sets a read deadline before every await so a silent peer times out in
  /// [timeout] instead of the ~5 minute default wait.
  Future<SyncMessage> _readMessageToEof(
    P2PStream stream,
    Duration timeout,
  ) async {
    final buffer = BytesBuilder(copy: false);
    while (true) {
      await stream.setReadDeadline(DateTime.now().add(timeout));
      final chunk = await stream.read();
      if (chunk.isEmpty) break; // EOF
      buffer.add(chunk);
    }
    return SyncMessageCodec.decode(buffer.toBytes());
  }

  /// Builds dialable [MultiAddr]s from a device's advertised multiaddr strings,
  /// appending the peer id to addresses that lack a `/p2p/` suffix.
  List<MultiAddr> _parseAddrs(List<String> rawAddrs, PeerId peerId) {
    final addrs = <MultiAddr>[];
    for (final raw in rawAddrs) {
      try {
        final addr = MultiAddr(raw);
        if (addr.valueForProtocol('p2p') != null) {
          addrs.add(addr);
        } else {
          addrs.add(MultiAddr('$raw/p2p/${peerId.toString()}'));
        }
      } catch (_) {
        // Skip malformed advertised addresses.
      }
    }
    return addrs;
  }

  /// The host's bound UDX listen port, used for mDNS service advertisement.
  static int _udxListenPort(Host host) {
    for (final addr in host.network.listenAddresses) {
      if (addr.hasProtocol('udx')) {
        final port = int.tryParse(addr.valueForProtocol('udp') ?? '');
        if (port != null && port > 0) return port;
      }
    }
    return NookMdnsConstants.defaultPort;
  }

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

  /// Whether [e] represents a stream read that elapsed its deadline. Yamux
  /// rethrows a timeout in the half-closed state as a
  /// [YamuxStreamStateException] whose `originalException` is the underlying
  /// [YamuxStreamTimeoutException].
  static bool _isYamuxTimeout(Object e) {
    if (e is YamuxStreamTimeoutException) return true;
    if (e is YamuxStreamStateException) {
      return e.originalException is YamuxStreamTimeoutException;
    }
    return false;
  }
}

/// Maps discovered [NookDiscoveredPeer]s to [SyncDevice]s, filtering out the
/// host's own peer id (double-check; the discovery also skips self).
class _DiscoveryNotifee implements NookMdnsNotifee {
  _DiscoveryNotifee(this._controller, {required this.hostId});

  final StreamController<SyncDevice> _controller;
  final PeerId hostId;

  @override
  void handlePeerFound(NookDiscoveredPeer peer) {
    if (peer.addrInfo.id == hostId) return;
    if (_controller.isClosed) return;

    _controller.add(SyncDevice(
      deviceId: peer.addrInfo.id.toString(),
      deviceName: peer.deviceName ?? 'Unknown Device',
      isOnline: true,
      multiaddresses: peer.addrInfo.addrs.map((a) => a.toString()).toList(),
    ));
  }
}
