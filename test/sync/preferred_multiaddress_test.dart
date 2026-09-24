import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/transport/sync_transport.dart';

void main() {
  group('preferredMultiaddress', () {
    test('returns empty string for no addresses', () {
      expect(preferredMultiaddress(const []), '');
    });

    test('prefers the first IPv4 address over IPv6', () {
      const addresses = [
        '/ip6/fe80::1/udp/4001/udx/p2p/peer6',
        '/ip4/192.168.1.20/udp/52341/udx/p2p/peer4',
        '/ip4/10.0.0.5/udp/52342/udx/p2p/peer4b',
      ];
      expect(preferredMultiaddress(addresses), addresses[1]);
    });

    test('returns the first address when only IPv6 is present', () {
      const addresses = [
        '/ip6/2001:db8::1/udp/4001/udx/p2p/peer6',
      ];
      expect(preferredMultiaddress(addresses), addresses.first);
    });

    test('returns the first address when only IPv4 is present', () {
      const addresses = [
        '/ip4/192.168.1.20/udp/52341/udx/p2p/peer4',
        '/ip4/10.0.0.5/udp/52342/udx/p2p/peer4b',
      ];
      expect(preferredMultiaddress(addresses), addresses.first);
    });
  });
}
