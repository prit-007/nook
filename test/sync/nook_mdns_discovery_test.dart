import 'package:dart_libp2p/core/host/host.dart';
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/peer/addr_info.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdns_dart/mdns_dart.dart';
import 'package:nook/sync/discovery/nook_mdns_discovery.dart';

import 'libp2p_test_host.dart';

void main() {
  late Host host;

  setUp(() async {
    host = await createLoopbackHost();
  });

  tearDown(() async {
    await host.close();
  });

  group('NookMdnsDiscovery TXT parsing', () {
    test('extracts dnsaddr and devicename with spaces and unicode', () {
      final entry = ServiceEntry(
        name: 'node-abc123.',
        host: 'mynook.',
        port: 4001,
        infoFields: [
          'dnsaddr=/ip4/192.168.1.50/udp/4001/udx/p2p/${host.id}',
          'devicename=${Uri.encodeComponent('Galaxy S24 Max')}',
        ],
      );

      final parsed = NookMdnsDiscovery.parseServiceEntry(entry);

      expect(parsed.addresses, hasLength(1));
      expect(parsed.peerId, host.id);
      expect(parsed.deviceName, 'Galaxy S24 Max');
    });

    test('decodes unicode device names', () {
      final entry = ServiceEntry(
        name: 'node-1.',
        port: 4001,
        infoFields: [
          'dnsaddr=/ip4/10.0.0.5/udp/4001/udx/p2p/${host.id}',
          'devicename=${Uri.encodeComponent('iPad 日本語 📱')}',
        ],
      );

      final parsed = NookMdnsDiscovery.parseServiceEntry(entry);

      expect(parsed.deviceName, 'iPad 日本語 📱');
    });

    test('handles missing device name', () {
      final entry = ServiceEntry(
        name: 'node-2.',
        port: 4001,
        infoFields: ['dnsaddr=/ip4/10.0.0.6/udp/4001/udx/p2p/${host.id}'],
      );

      final parsed = NookMdnsDiscovery.parseServiceEntry(entry);

      expect(parsed.deviceName, isNull);
      expect(parsed.peerId, host.id);
    });
  });

  group('NookMdnsDiscovery modes', () {
    test('debugInjectPeer fires notifee with AddrInfo and deviceName',
        () async {
      final peers = <NookDiscoveredPeer>[];
      final discovery = NookMdnsDiscovery(
        host,
        notifee: _RecordingNotifee(peers),
      );

      discovery.debugInjectPeer(
        AddrInfo.withId(await PeerId.random()),
        deviceName: 'Pixel 9',
      );

      expect(peers, hasLength(1));
      expect(peers.first.deviceName, 'Pixel 9');
    });

    test('advertiseOnly never starts discovery', () async {
      final discovery = NookMdnsDiscovery(host, networkEnabled: false);

      await discovery.advertiseOnly();

      expect(discovery.isAdvertising, isTrue);
      expect(discovery.isDiscovering, isFalse);

      await discovery.stop();
      expect(discovery.isAdvertising, isFalse);
      expect(discovery.isDiscovering, isFalse);
    });

    test('discoverOnly starts discovery without advertising', () async {
      final discovery = NookMdnsDiscovery(host, networkEnabled: false);

      await discovery.discoverOnly();

      expect(discovery.isDiscovering, isTrue);
      expect(discovery.isAdvertising, isFalse);

      await discovery.stop();
    });

    test('advertiseOnly and discoverOnly are idempotent', () async {
      final discovery = NookMdnsDiscovery(host, networkEnabled: false);

      await discovery.advertiseOnly();
      await discovery.advertiseOnly();
      await discovery.discoverOnly();
      await discovery.discoverOnly();

      expect(discovery.isAdvertising, isTrue);
      expect(discovery.isDiscovering, isTrue);

      await discovery.stop();
    });

    test('stop is safe to repeat and discovery can restart', () async {
      final discovery = NookMdnsDiscovery(host, networkEnabled: false);

      await discovery.discoverOnly();
      await discovery.stop();
      await discovery.stop();
      await discovery.discoverOnly();

      expect(discovery.isDiscovering, isTrue);
      await discovery.stop();
      expect(discovery.isDiscovering, isFalse);
    });
  });

  group('NookMdnsDiscovery self-exclusion', () {
    test('a service advertising our own peer id is not reported', () {
      final peers = <NookDiscoveredPeer>[];
      final discovery = NookMdnsDiscovery(
        host,
        notifee: _RecordingNotifee(peers),
      );
      // Listen for the parsed service on the same host so _host.id matches.
      final entry = ServiceEntry(
        name: 'self-node.',
        port: 4001,
        infoFields: ['dnsaddr=/ip4/10.0.0.9/udp/4001/udx/p2p/${host.id}'],
      );

      discovery.processDiscoveredServiceForTesting(entry);

      expect(peers, isEmpty);
    });

    test('a service advertising a foreign peer id is reported', () async {
      final peers = <NookDiscoveredPeer>[];
      final discovery = NookMdnsDiscovery(
        host,
        notifee: _RecordingNotifee(peers),
      );
      final other = await PeerId.random();
      final entry = ServiceEntry(
        name: 'other-node.',
        port: 4001,
        infoFields: ['dnsaddr=/ip4/10.0.0.9/udp/4001/udx/p2p/$other'],
      );

      discovery.processDiscoveredServiceForTesting(entry);

      expect(peers, hasLength(1));
      expect(peers.first.addrInfo.id, other);
    });
  });

  group('NookMdnsDiscovery interface selection', () {
    test('resolveActiveInterface returns a usable LAN interface or null',
        () async {
      final iface = await NookMdnsDiscovery.resolveActiveInterface();
      // Never throws, even headless/offline. When a candidate exists it must
      // carry a real (non-loopback) IPv4 address so multicast can leave the
      // box on the active adapter.
      if (iface != null) {
        expect(
          iface.addresses.any((a) => !a.isLoopback),
          isTrue,
          reason: 'selected interface must have a LAN IPv4 address',
        );
      }
    });
  });

  group('NookMdnsDiscovery dialable address filter', () {
    MultiAddr lan(String ip) => MultiAddr('/ip4/$ip/udp/4001/udx');
    MultiAddr lan6(String ip) => MultiAddr('/ip6/$ip/udp/4001/udx');

    test('keeps real LAN addresses', () {
      final filtered = NookMdnsDiscovery.filterDialableAddrs([
        lan('192.168.1.50'),
        lan('10.0.0.5'),
      ]);

      expect(filtered, hasLength(2));
    });

    test('drops IPv6 ULA addresses (Tailscale fd7a:115c:a1e0::/48)', () {
      final filtered = NookMdnsDiscovery.filterDialableAddrs([
        lan6('fd7a:115c:a1e0::d633:964e'),
        lan('192.168.1.50'),
      ]);

      expect(filtered, hasLength(1));
      expect(filtered.single.ip4, '192.168.1.50');
    });

    test('drops link-local and loopback addresses', () {
      final filtered = NookMdnsDiscovery.filterDialableAddrs([
        lan6('fe80::1'),
        lan('169.254.1.1'),
        lan('127.0.0.1'),
        lan6('::1'),
        lan('192.168.1.50'),
      ]);

      expect(filtered, hasLength(1));
      expect(filtered.single.ip4, '192.168.1.50');
    });

    test('drops multicast addresses', () {
      final filtered = NookMdnsDiscovery.filterDialableAddrs([
        lan('224.0.0.251'),
        lan('192.168.1.50'),
      ]);

      expect(filtered, hasLength(1));
      expect(filtered.single.ip4, '192.168.1.50');
    });

    test('drops addresses on virtual adapters (Docker 172.20.x)', () {
      final filtered = NookMdnsDiscovery.filterDialableAddrs(
        [lan('172.20.208.1'), lan('192.168.1.50')],
        virtualInterfaceIps: const {'172.20.208.1'},
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.ip4, '192.168.1.50');
    });

    test('keeps the LAN address when the only address is a LAN address', () {
      final filtered =
          NookMdnsDiscovery.filterDialableAddrs([lan('192.168.1.50')]);

      expect(filtered, hasLength(1));
    });

    test('returns empty when every address is non-dialable', () {
      final filtered = NookMdnsDiscovery.filterDialableAddrs([
        lan6('fd7a:115c:a1e0::d633:964e'),
        lan('172.20.208.1'),
      ], virtualInterfaceIps: const {
        '172.20.208.1'
      });

      expect(filtered, isEmpty);
    });
  });

  group('NookMdnsDiscovery real mDNS', () {
    test(
      'discovers an advertising device on the real network',
      () async {
        final receiver = await createLoopbackHost();
        final discovered = <NookDiscoveredPeer>[];
        final advertiser = NookMdnsDiscovery(
          receiver,
          serviceName: '_syncnotenet_test._udp',
          deviceName: 'Loopback Announcer',
        );
        await advertiser.advertiseOnly();

        final sender = NookMdnsDiscovery(
          host,
          serviceName: '_syncnotenet_test._udp',
          notifee: _RecordingNotifee(discovered),
        );
        await sender.discoverOnly();

        // mDNS is best-effort and timing-sensitive; wait for at least one
        // announcement cycle (5s periodic query) before giving up.
        var found = false;
        for (var i = 0; i < 8 && !found; i++) {
          await Future<void>.delayed(const Duration(seconds: 2));
          found = discovered.any(
            (p) => p.addrInfo.id == receiver.id,
          );
        }

        await sender.stop();
        await advertiser.stop();
        await receiver.close();

        expect(found, isTrue,
            reason: 'expected to discover ${receiver.id} over real mDNS');
      },
      tags: ['network'],
    );
  });
}

class _RecordingNotifee implements NookMdnsNotifee {
  _RecordingNotifee(this.peers);

  final List<NookDiscoveredPeer> peers;

  @override
  void handlePeerFound(NookDiscoveredPeer peer) {
    peers.add(peer);
  }
}
