import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/transport/sync_transport.dart';

void main() {
  group('SyncDevice.fromManualAddress', () {
    test('parses a full multiaddr with peer id', () {
      const peerId = '12D3KooWabcdefghijk';
      final device = SyncDevice.fromManualAddress(
        '/ip4/192.168.1.20/udp/52341/udx/p2p/$peerId',
      );

      expect(device, isNotNull);
      expect(device!.deviceId, peerId);
      expect(device.multiaddresses, ['/ip4/192.168.1.20/udp/52341/udx']);
      expect(device.isOnline, isTrue);
    });

    test('returns null without a /p2p/ peer id', () {
      expect(
        SyncDevice.fromManualAddress('/ip4/192.168.1.20/udp/52341/udx'),
        isNull,
      );
    });

    test('returns null for empty or whitespace input', () {
      expect(SyncDevice.fromManualAddress(''), isNull);
      expect(SyncDevice.fromManualAddress('   '), isNull);
    });

    test('returns null when the peer id is empty', () {
      expect(
        SyncDevice.fromManualAddress(
          '/ip4/192.168.1.20/udp/52341/udx/p2p/',
        ),
        isNull,
      );
    });

    test('trims surrounding whitespace', () {
      final device = SyncDevice.fromManualAddress(
        '  /ip4/192.168.1.20/udp/52341/udx/p2p/abc123  ',
      );

      expect(device, isNotNull);
      expect(device!.deviceId, 'abc123');
    });
  });
}
