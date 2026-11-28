import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/transport/sync_transport.dart';

import 'fake_sync_transport.dart';

void main() {
  test('FakeSyncTransport implements SyncTransport contract', () async {
    final transport = FakeSyncTransport(deviceId: 'peer-a');
    expect(transport.isInitialized, isFalse);
    expect(await transport.getCurrentDeviceId(), 'peer-a');
    expect(transport.isInitialized, isTrue);
    expect(transport.localMultiaddresses, isNotEmpty);

    await transport.startAdvertising();
    expect(transport.isAdvertising, isTrue);

    await transport.startDiscovery();
    expect(transport.isDiscovering, isTrue);

    const peer = SyncDevice(
      deviceId: 'peer-b',
      deviceName: 'Pixel',
      isOnline: true,
    );
    expect(await transport.connectToDevice(peer), isTrue);
    expect(transport.connectedDevices, [peer]);

    final ack = await transport.sendData([1, 2, 3]);
    expect(ack, isNotNull);
    expect(transport.sentPayloads, [
      [1, 2, 3]
    ]);

    await transport.disconnect();
    expect(transport.isAdvertising, isFalse);
    expect(transport.isDiscovering, isFalse);
    transport.dispose();
  });
}
