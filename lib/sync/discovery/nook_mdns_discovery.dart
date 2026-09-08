import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dart_libp2p/core/host/host.dart';
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/peer/addr_info.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:mdns_dart/mdns_dart.dart';

import '../../core/platform/multicast_lock.dart';
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

  /// The LAN interface multicast is bound to, resolved once and reused by
  /// advertising and discovery. Keeps mDNS traffic on the active adapter
  /// instead of silently going out the wrong NIC (Wi-Fi vs cellular on
  /// Android, VPN/multi-NIC on Windows). Null when it cannot be resolved
  /// (offline, tests).
  NetworkInterface? _activeInterface;

  // Announcements: unsolicited multicast broadcasts so peers discover this
  // device even if their one-shot query fires while we were off.
  Timer? _announceTimer;
  RawDatagramSocket? _announceSocket;
  String? _announcedServiceAddr;

  // Discover state.
  StreamSubscription<ServiceEntry>? _discoverySubscription;
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
    _isDiscovering = true;
    await _startDiscovery();
  }

  /// Stops advertising and discovery.
  Future<void> stop() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    _discoveredServices.clear();
    _isDiscovering = false;

    _announceTimer?.cancel();
    _announceTimer = null;
    _announceSocket?.close();
    _announceSocket = null;
    _announcedServiceAddr = null;

    if (_server != null) {
      await _server!.stop();
      _server = null;
    }
    _service = null;
    _isAdvertising = false;

    await MulticastLock.release();
  }

  /// Advertises the host on mDNS, adding one `dnsaddr=` record per dialable
  /// listen address (with the peer id) plus a URL-encoded `devicename=` record.
  Future<void> _startAdvertising() async {
    if (!networkEnabled) return;
    final addresses = _host.addrs;
    if (addresses.isEmpty) return;

    try {
      await MulticastLock.acquire();
      _activeInterface ??= await _resolveActiveInterface();

      final virtualIps = await virtualAdapterAddresses();
      final dialable = filterDialableAddrs(
        addresses,
        virtualInterfaceIps: virtualIps,
      );
      // Advertise only addresses a peer can actually dial (skip Tailscale ULA,
      // Docker/VPN virtual adapters); fall back to the full set when nothing
      // survives (hermetic loopback tests).
      final advertised = dialable.isNotEmpty ? dialable : addresses;

      final txtRecords = <String>[];
      for (final addr in advertised) {
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

      final config = MDNSServerConfig(
        zone: _service!,
        networkInterface: _activeInterface,
        reusePort: !Platform.isAndroid,
        reuseAddress: true,
      );
      _server = MDNSServer(config);
      await _server!.start();

      // Actively broadcast our records every few seconds in addition to
      // answering PTR queries, so a discoverer whose query falls in a gap
      // still finds us — mDNS on Android is otherwise pull-only and picky.
      _startAnnouncements();
      nookLog(NookLogKey.sync, 'mDNS advertising started', LogLevel.info);
    } catch (e) {
      // mDNS advertising is best-effort (discovery still works), but a silent
      // failure leaves the receiver invisible — log the real reason so the
      // sync logs can explain "no device found".
      nookLog(
        NookLogKey.sync,
        'mDNS advertising failed: $e',
        LogLevel.error,
      );
    }
  }

  /// Sends the full record set (PTR + SRV + TXT + A) as an unsolicited
  /// multicast response on a repeating timer.
  void _startAnnouncements() {
    final service = _service;
    if (service == null) return;
    _announcedServiceAddr = '$service.service.${service.domain}';

    _announceTimer?.cancel();
    _announceTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _sendAnnouncement(),
    );
    // Fire once immediately so a peer that just started discovering sees us
    // without waiting a full cycle.
    _sendAnnouncement();
  }

  Future<void> _sendAnnouncement() async {
    final service = _service;
    final serviceAddr = _announcedServiceAddr;
    if (service == null || serviceAddr == null) return;
    try {
      final socket = _announceSocket ??=
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final iface = _activeInterface;
      if (iface != null) {
        // Route the unsolicited announcements out the active LAN interface so
        // they reach the subnet instead of the default-route adapter. Dart's
        // RawDatagramSocket has no setMulticastInterface; set the raw option
        // directly (mirrors mdns_dart's own extension in src/utils.dart).
        final level = RawSocketOption.levelIPv4;
        final option = RawSocketOption.IPv4MulticastInterface;
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            socket
                .setRawOption(RawSocketOption(level, option, addr.rawAddress));
            break;
          }
        }
      }
      final records = service.records(
        DNSQuestion(
          name: serviceAddr,
          type: DNSType.ANY,
          dnsClass: DNSClass.IN,
        ),
      );
      if (records.isEmpty) return;
      final data = DNSMessage.response(id: 0, answers: records).pack();
      socket.send(data, InternetAddress(ipv4mDNS), mDNSPort);
    } catch (_) {
      // Announcements are best-effort; responding to queries still works.
    }
  }

  /// Queries for other Nook devices on mDNS. The query runs immediately and
  /// re-runs after each one completes, because MDNSClient.query is a one-shot
  /// lookup that holds the mDNS port for its full timeout.
  Future<void> _startDiscovery() async {
    if (!networkEnabled) return;
    try {
      await MulticastLock.acquire();
      _activeInterface ??= await _resolveActiveInterface();

      final serviceOnly = _serviceName.replaceAll('.local', '');
      final params = QueryParams(
        service: serviceOnly,
        domain: NookMdnsConstants.mdnsDomain,
        timeout: const Duration(seconds: 10),
        wantUnicastResponse: false,
        networkInterface: _activeInterface,
        // Android has documented bind issues with SO_REUSEPORT on the mDNS
        // port; reuseAddress alone is enough for multicast there.
        reusePort: !Platform.isAndroid,
        reuseAddress: true,
        multicastHops: 1,
      );

      // Never overlap queries: each MDNSClient.query holds the mDNS port for
      // its whole timeout, so a fixed-period timer would re-bind while the
      // previous query is still listening and fail (especially on Android,
      // where reusePort is off). Run the next query only after the previous
      // one has fully completed.
      unawaited(_runDiscoveryLoop(params));
      nookLog(NookLogKey.sync, 'mDNS discovery started', LogLevel.info);
    } catch (e) {
      // Discovery is best-effort — but log the real reason so the "Searching
      // for devices..." state never stays mysteriously stuck.
      _isDiscovering = false;
      nookLog(
        NookLogKey.sync,
        'mDNS discovery failed to start: $e',
        LogLevel.error,
      );
    }
  }

  Future<void> _runDiscoveryLoop(QueryParams params) async {
    while (_isDiscovering) {
      try {
        await _performDiscoveryQuery(params);
      } catch (e) {
        nookLog(
          NookLogKey.sync,
          'mDNS discovery loop iteration failed: $e',
          LogLevel.error,
        );
      }
      if (!_isDiscovering) break;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> _performDiscoveryQuery(QueryParams params) async {
    try {
      final stream = await MDNSClient.query(params);
      await for (final serviceEntry in stream) {
        _processDiscoveredService(serviceEntry);
      }
    } catch (e) {
      // Best-effort — a transient failure must not kill the periodic loop, but
      // the real reason must surface in the sync logs so "no device found" is
      // explainable.
      nookLog(
        NookLogKey.sync,
        'mDNS discovery query failed: $e',
        LogLevel.error,
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
      if (peerId != null && peerId == _host.id) {
        nookLog(
          NookLogKey.sync,
          'mDNS: ignoring our own advertisement (${_host.id})',
          LogLevel.debug,
        );
        return;
      }

      if (parsed.addresses.isNotEmpty && peerId != null) {
        nookLog(
          NookLogKey.sync,
          'Device found: "${parsed.deviceName}" '
          '($peerId @ ${parsed.addresses.first})',
          LogLevel.info,
        );
        _notifee?.handlePeerFound(NookDiscoveredPeer(
          addrInfo: AddrInfo(peerId, parsed.addresses),
          deviceName: parsed.deviceName,
        ));
      }
    } catch (e) {
      nookLog(
        NookLogKey.sync,
        'Failed to process mDNS service entry: $e',
        LogLevel.error,
      );
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

  /// Picks the LAN interface multicast should use, preferring a WiFi or
  /// Ethernet adapter that carries a real (non-loopback, non-link-local)
  /// IPv4 address, and skipping obvious virtual adapters (VPN, Docker,
  /// Tailscale, etc.). Returns null when no usable interface exists.
  ///
  /// Package-visible (static) so it can be tested without a live network.
  static Future<NetworkInterface?> resolveActiveInterface() async {
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    final candidates = <NetworkInterface>[];
    for (final iface in interfaces) {
      final hasLanIp = iface.addresses.any(
        (a) => !a.isLoopback && !a.isLinkLocal,
      );
      if (!hasLanIp) continue;
      if (_isVirtualAdapter(iface.name)) continue;
      candidates.add(iface);
    }
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    candidates.sort(
        (a, b) => _interfaceScore(b.name).compareTo(_interfaceScore(a.name)));
    return candidates.first;
  }

  /// Filters [addrs] down to the addresses a peer on the same LAN can actually
  /// dial: keeps LAN unicast addresses, drops loopback, link-local, IPv6 ULA
  /// (fc00::/7 — the range Tailscale/ZeroTier use), multicast, and any address
  /// that lives on a known virtual adapter (VPN, Docker, Tailscale, ...).
  ///
  /// [virtualInterfaceIps] is the set of IPs assigned to virtual adapters on
  /// this host (from [virtualAdapterAddresses]); tests inject it directly.
  /// Package-visible so the libp2p transport can advertise only dialable
  /// addresses (a phone cannot route to a Docker or Tailscale address).
  static List<MultiAddr> filterDialableAddrs(
    List<MultiAddr> addrs, {
    Set<String> virtualInterfaceIps = const {},
  }) {
    final dialable = <MultiAddr>[];
    for (final addr in addrs) {
      final v4 = addr.ip4;
      if (v4 != null) {
        final ip = InternetAddress.tryParse(v4);
        if (ip == null) continue;
        if (ip.isLoopback || ip.isLinkLocal || ip.isMulticast) continue;
        if (virtualInterfaceIps.contains(ip.address)) continue;
        dialable.add(addr);
        continue;
      }
      final v6 = addr.ip6;
      if (v6 != null) {
        final ip = InternetAddress.tryParse(v6);
        if (ip == null) continue;
        if (ip.isLoopback || ip.isLinkLocal || ip.isMulticast) continue;
        if (_isIpv6Ula(ip)) continue;
        if (virtualInterfaceIps.contains(ip.address)) continue;
        dialable.add(addr);
      }
    }
    return dialable;
  }

  /// Returns the set of IPv4/IPv6 addresses assigned to virtual adapters on
  /// this host (VPN, Docker, Tailscale, tunnels, ...). Addresses on these
  /// adapters are reachable only from the virtual network, never from a phone
  /// on the real LAN.
  static Future<Set<String>> virtualAdapterAddresses() async {
    final interfaces = await NetworkInterface.list();
    final ips = <String>{};
    for (final iface in interfaces) {
      if (!_isVirtualAdapter(iface.name)) continue;
      for (final addr in iface.addresses) {
        ips.add(addr.address);
      }
    }
    return ips;
  }

  /// Whether [ip] falls in the IPv6 unique-local range fc00::/7 (the range
  /// used by Tailscale, ZeroTier, and site-local VPNs — not reachable from a
  /// phone on the LAN).
  static bool _isIpv6Ula(InternetAddress ip) {
    if (ip.type != InternetAddressType.IPv6) return false;
    final bytes = ip.rawAddress;
    if (bytes.isEmpty) return false;
    // fc00::/7 → the first byte is 0xfc or 0xfd.
    return (bytes[0] & 0xfe) == 0xfc;
  }

  /// Convenience instance wrapper for [_resolveActiveInterface] usage in
  /// [NookMdnsDiscovery].
  Future<NetworkInterface?> _resolveActiveInterface() =>
      resolveActiveInterface();

  static bool _isVirtualAdapter(String name) {
    final lower = name.toLowerCase();
    return [
      'vpn',
      'tun',
      'tap',
      'veth',
      'docker',
      'vmnet',
      'vmware',
      'virtualbox',
      'utun',
      'tailscale',
      'zerotier',
      'wintun',
      'ppp'
    ].any(lower.contains);
  }

  static int _interfaceScore(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('wlan') ||
        lower.contains('wifi') ||
        lower.contains('wi-fi') ||
        lower.contains('wireless')) {
      return 3;
    }
    if (lower.contains('eth') ||
        lower.contains('en') ||
        lower.contains('ethernet')) {
      return 2;
    }
    return 1;
  }

  String _randomInstance() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(
        32 + random.nextInt(32),
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
