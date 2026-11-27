@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_sync_transport.dart';

void main() {
  test('Nightly soak harness exchanges 1,000 sync payloads cleanly', () async {
    final transport = FakeSyncTransport(deviceId: 'soak-peer');
    await transport.initialize();

    for (var i = 0; i < 1000; i++) {
      final ack = await transport.sendData([i & 0xff, (i >> 8) & 0xff]);
      expect(ack, isNotNull);
    }
    expect(transport.sentPayloads, hasLength(1000));
    transport.dispose();
  });
}
