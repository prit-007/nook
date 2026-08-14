import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dart_libp2p/core/host/host.dart';
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/peer/addr_info.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:mdns_dart/mdns_dart.dart';

import '../../core/providers/talker_provider.dart';

/// Constants for Nook's mDNS service.
class NookMdnsConstants {
  /// Nook sync runs its own service so it never collides with libp2p's
  /// built-in `_p2p._udp` (which would leak raw libp2p mDNS traffic).
  static const String serviceName = '_syncnotenet._udp';

  static const String mdnsDomain = 'local';

  /// Prefix for DNS address records (libp2p standard).
  static const String dnsaddrPrefix = 'dnsaddr=';

  /// TXT key carrying the URL-encoded human-readable device name.
  static const String deviceNameKey = 'devicename';

  /// Default mDNS service port (must be non-zero to advertise).
  static const int defaultPort = 4001;
}

/// A peer discovered via Nook mDNS, including its optional friendly name.
class NookDiscoveredPeer {
  const NookDiscoveredPeer({required this.addrInfo, this.deviceName});

  final AddrInfo addrInfo;

  /// The friendly device name carried in the TXT record, if any.
  final String? deviceName;
}

/// Result of parsing a mDNS service entry's TXT records.
class ParsedNookService {
  const ParsedNookService({
    required this.addresses,
    required this.peerId,
    required this.deviceName,
  });

  final List<MultiAddr> addresses;
  final PeerId? peerId;
  final String? deviceName;
}

/// Interface for receiving discovered peers.
abstract class NookMdnsNotifee {
  void handlePeerFound(NookDiscoveredPeer peer);
}

/// Nook's fork of dart_libp2p's [MdnsDiscovery].
///
/// Differences from the upstream class:
/// - Own service name (`_syncnotenet._udp`) and a configurable port.
/// - Advertises a `devicename=` TXT record so the peer's friendly name is
///   known from discovery without an extra round-trip.
/// - Splits `advertiseOnly()` / `discoverOnly()` so a sender can discover
///   while the receiver only advertises (matches the sync orchestrator's
///   one-directional flow).
/// - Keeps [debugInjectPeer] so discovery logic is testable without multicast.
class NookMdnsDiscovery {
  NookMdnsDiscovery(
    this._host, {
    String? serviceName,
    NookMdnsNotifee? notifee,
    int port = NookMdnsConstants.defaultPort,
    String? deviceName,
    this.networkEnabled = true,
  })  : _serviceName = serviceName ?? NookMdnsConstants.serviceName,
        _port = port,
        _deviceName = deviceName,
        _notifee = notifee;

  final Host _host;
  final String _serviceName;
  final int _port;
  final String? _deviceName;
  NookMdnsNotifee? _notifee;

  /// When false, advertise/discover become pure state changes and never touch
  /// the network. Tests that exercise mode semantics stay hermetic and fast.
  final bool networkEnabled;

  // Advertise state.
  MDNSServer? _server;
  MDNSService? _service;

  // Discover state.
  StreamSubscription<ServiceEntry>? _discoverySubscription;
  Timer? _discoveryTimer;
  bool _isDiscovering = false;
  bool _isAdvertising = false;
  final Set<String> _discoveredServices = <String>{};

  /// Sets the notifee.
  set notifee(NookMdnsNotifee? value) {
    _notifee = value;
  }

  /// Whether advertising is currently active.
  bool get isAdvertising => _isAdvertising;

  /// Whether discovery is currently active.
  bool get isDiscovering => _isDiscovering;

  /// Starts both advertising and discovery (compatibility with upstream).
  Future<void> start() async {
    await advertiseOnly();
    await discoverOnly();
  }

  /// Starts advertising only. Safe to call repeatedly.
  Future<void> advertiseOnly() async {
    if (_isAdvertising) return;
    await _startAdvertising();
    _isAdvertising = true;
  }

  /// Starts discovery only. Safe to call repeatedly.
  Future<void> discoverOnly() async {
    if (_isDiscovering) return;
    await _startDiscovery();
    _isDiscovering = true;
  }

  /// Stops advertising and discovery.
  Future<void> stop() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    _discoveryTimer?.cancel();
    _discoveryTimer = null;

    _discoveredServices.clear();
    _isDiscovering = false;

    if (_server != null) {
      await _server!.stop();
      _server = null;
    }
    _service = null;
    _isAdvertising = false;
  }

  /// Advertises the host on mDNS, adding one `dnsaddr=` record per listen
  /// address (with the peer id) plus a URL-encoded `devicename=` record.
  Future<void> _startAdvertising() async {
    if (!networkEnabled) return;
    final addresses = _host.addrs;
    if (addresses.isEmpty) return;

    try {
      final txtRecords = <String>[];
      for (final addr in addresses) {
        final fullAddr = '${addr.toString()}/p2p/${_host.id.toString()}';
        txtRecords.add('${NookMdnsConstants.dnsaddrPrefix}$fullAddr');
      }
      if (_deviceName != null && _deviceName.isNotEmpty) {
        txtRecords.add(
            '${NookMdnsConstants.deviceNameKey}=${Uri.encodeComponent(_deviceName)}');
      }

      final localIPs = await _getLocalIPAddresses();

      _service = await MDNSService.create(
        instance: _randomInstance(),
        service: _serviceName,
        domain: NookMdnsConstants.mdnsDomain,
        port: _port,
        ips: localIPs,
        txt: txtRecords,
      );

      final config = MDNSServerConfig(zone: _service!);
      _server = MDNSServer(config);
      await _server!.start();
      nookLog(NookLogKey.sync, 'mDNS advertising started', LogLevel.info);
    } catch (_) {
      // mDNS advertising is best-effort; discovery still works.
      nookLog(
        NookLogKey.sync,
        'mDNS advertising failed (best-effort)',
        LogLevel.warning,
      );
    }
  }

  /// Queries for other Nook devices on mDNS. The query runs immediately and
  /// repeats every few seconds because MDNSClient.query is a one-shot lookup.
  Future<void> _startDiscovery() async {
    if (!networkEnabled) return;
    try {
      final serviceOnly = _serviceName.replaceAll('.local', '');
      final params = QueryParams(
        service: serviceOnly,
        domain: NookMdnsConstants.mdnsDomain,
        timeout: const Duration(seconds: 10),
        wantUnicastResponse: false,
        reusePort: true,
        reuseAddress: true,
        multicastHops: 1,
      );

      await _performDiscoveryQuery(params);

      _discoveryTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) async => _performDiscoveryQuery(params),
      );
      nookLog(NookLogKey.sync, 'mDNS discovery started', LogLevel.info);
    } catch (_) {
      // Discovery is best-effort.
      nookLog(
        NookLogKey.sync,
        'mDNS discovery failed to start (best-effort)',
        LogLevel.warning,
      );
    }
  }

  Future<void> _performDiscoveryQuery(QueryParams params) async {
    try {
      final stream = await MDNSClient.query(params);
      await for (final serviceEntry in stream) {
        _processDiscoveredService(serviceEntry);
      }
    } catch (_) {
      // Best-effort.
      nookLog(
        NookLogKey.sync,
        'mDNS discovery query failed (best-effort)',
        LogLevel.warning,
      );
    }
  }

  void _processDiscoveredService(ServiceEntry serviceEntry) {
    try {
      final serviceKey =
          '${serviceEntry.name}@${serviceEntry.host}:${serviceEntry.port}';
      if (_discoveredServices.contains(serviceKey)) return;
      _discoveredServices.add(serviceKey);

      final parsed = parseServiceEntry(serviceEntry);

      // Never discover ourselves.
      final peerId = parsed.peerId;
      if (peerId != null && peerId == _host.id) return;

      if (parsed.addresses.isNotEmpty && peerId != null) {
        _notifee?.handlePeerFound(NookDiscoveredPeer(
          addrInfo: AddrInfo(peerId, parsed.addresses),
          deviceName: parsed.deviceName,
        ));
      }
    } catch (_) {
      // Best-effort.
    }
  }

  /// Extracts multiaddrs, peer id, and device name from a mDNS [ServiceEntry].
  ///
  /// Public so tests can exercise TXT parsing (spaces/unicode in `devicename=`)
  /// without multicast.
  static ParsedNookService parseServiceEntry(ServiceEntry serviceEntry) {
    final addresses = <MultiAddr>[];
    PeerId? peerId;
    String? deviceName;

    for (final txtRecord in serviceEntry.infoFields) {
      if (txtRecord.startsWith(NookMdnsConstants.dnsaddrPrefix)) {
        final addrStr =
            txtRecord.substring(NookMdnsConstants.dnsaddrPrefix.length);
        try {
          final addr = MultiAddr(addrStr);
          addresses.add(addr);
          if (peerId == null) {
            final peerIdStr = addr.valueForProtocol('p2p');
            if (peerIdStr != null) {
              peerId = PeerId.fromString(peerIdStr);
            }
          }
        } catch (_) {
          // Skip malformed dnsaddr records.
        }
      } else if (txtRecord.startsWith('${NookMdnsConstants.deviceNameKey}=')) {
        final encoded =
            txtRecord.substring(NookMdnsConstants.deviceNameKey.length + 1);
        deviceName = Uri.decodeComponent(encoded);
      }
    }

    return ParsedNookService(
      addresses: addresses,
      peerId: peerId,
      deviceName: deviceName,
    );
  }

  /// Test hook: feed a synthetic [ServiceEntry] through the dedupe + parse +
  /// self-exclusion pipeline without multicast.
  void processDiscoveredServiceForTesting(ServiceEntry entry) {
    _processDiscoveredService(entry);
  }

  /// Test helper: inject a discovered peer straight into the notifee pipeline,
  /// bypassing multicast entirely.
  void debugInjectPeer(AddrInfo peer, {String? deviceName}) {
    _notifee?.handlePeerFound(
      NookDiscoveredPeer(addrInfo: peer, deviceName: deviceName),
    );
  }

  Future<List<InternetAddress>> _getLocalIPAddresses() async {
    final interfaces = await NetworkInterface.list();
    final addresses = <InternetAddress>[];

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && !addr.isLinkLocal) {
          addresses.add(addr);
        }
      }
    }

    if (addresses.isEmpty && interfaces.isNotEmpty) {
      addresses.addAll(interfaces.first.addresses);
    }

    return addresses;
  }

  String _randomInstance() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      List.generate(
        32 + random.nextInt(32),
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
