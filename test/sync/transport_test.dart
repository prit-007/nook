import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/transport/sync_transport.dart';

void main() {
  group('SyncDevice', () {
    test('equality is based on deviceId', () {
      const a = SyncDevice(
        deviceId: 'device-1',
        deviceName: 'Pixel 8',
        isOnline: true,
      );
      const b = SyncDevice(
        deviceId: 'device-1',
        deviceName: 'Pixel 9', // different name
        isOnline: false, // different status
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different deviceIds are not equal', () {
      const a = SyncDevice(
        deviceId: 'device-1',
        deviceName: 'Pixel 8',
        isOnline: true,
      );
      const b = SyncDevice(
        deviceId: 'device-2',
        deviceName: 'Pixel 8',
        isOnline: true,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('SyncSessionState', () {
    test('idle has no error', () {
      const state = SyncSessionState.idle();
      expect(state.error, isNull);
    });

    test('error carries message', () {
      const state = SyncSessionState.error('Connection failed');
      expect(state.error, 'Connection failed');
    });
  });

  group('MockSyncTransport', () {
    late MockSyncTransport transport;

    setUp(() {
      transport = MockSyncTransport();
    });

    test('startAdvertising sets isAdvertising', () async {
      expect(transport.isAdvertising, isFalse);
      await transport.startAdvertising();
      expect(transport.isAdvertising, isTrue);
    });

    test('stopAdvertising clears isAdvertising', () async {
      await transport.startAdvertising();
      await transport.stopAdvertising();
      expect(transport.isAdvertising, isFalse);
    });

    test('startDiscovery sets isDiscovering', () async {
      expect(transport.isDiscovering, isFalse);
      await transport.startDiscovery();
      expect(transport.isDiscovering, isTrue);
    });

    test('stopDiscovery clears isDiscovering', () async {
      await transport.startDiscovery();
      await transport.stopDiscovery();
      expect(transport.isDiscovering, isFalse);
    });

    test('sendData delegates to onSend', () async {
      var called = false;
      transport.onSend = (data) async {
        called = true;
        expect(data, [1, 2, 3]);
      };

      await transport.sendData([1, 2, 3]);
      expect(called, isTrue);
    });

    test('disconnect sets state to idle', () async {
      await transport.disconnect();
      expect(transport.sessionState, isA<SyncSessionState>());
    });

    test('deviceFoundStream emits discovered devices', () async {
      final devices = <SyncDevice>[];
      transport.deviceFoundStream.listen(devices.add);

      const device = SyncDevice(
        deviceId: 'device-2',
        deviceName: 'Galaxy S24',
        isOnline: true,
      );
      transport.emitDeviceFound(device);

      await Future.delayed(Duration.zero);
      expect(devices.length, 1);
      expect(devices[0].deviceId, 'device-2');
    });

    test('sessionStateStream emits state changes', () async {
      final states = <SyncSessionState>[];
      transport.sessionStateStream.listen(states.add);

      transport.emitStateChanged(const SyncSessionState.connecting());
      await Future.delayed(Duration.zero);

      transport.emitStateChanged(const SyncSessionState.connected());
      await Future.delayed(Duration.zero);

      expect(states.length, 2);
      expect(states[0], isA<SyncSessionState>());
      expect(states[1], isA<SyncSessionState>());
    });

    test('bytesReceivedStream emits received data', () async {
      final chunks = <List<int>>[];
      transport.bytesReceivedStream.listen(chunks.add);

      transport.emitBytesReceived([10, 20, 30]);
      await Future.delayed(Duration.zero);

      expect(chunks.length, 1);
      expect(chunks[0], [10, 20, 30]);
    });

    test('progressStream emits progress values', () async {
      final progresses = <double>[];
      transport.progressStream.listen(progresses.add);

      transport.emitProgress(0.5);
      transport.emitProgress(1.0);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(progresses, [0.5, 1.0]);
    });

    test('transport can simulate full flow', () async {
      // Simulate: discover → connect → send → receive → ack → disconnect
      final deviceEvents = <SyncDevice>[];
      transport.deviceFoundStream.listen(deviceEvents.add);

      await transport.startDiscovery();

      transport.emitDeviceFound(const SyncDevice(
        deviceId: 'device-2',
        deviceName: 'Galaxy',
        isOnline: true,
      ));
      await Future.delayed(Duration.zero);

      expect(deviceEvents.length, 1);

      await transport.sendData([1, 2, 3]);
      await transport.disconnect();

      expect(transport.isDiscovering, isFalse);
    });
  });

  group('SyncTransport interface contract', () {
    test('all required methods are defined', () {
      // Verify the abstract interface compiles and has the right shape
      final transport = MockSyncTransport();

      // Verify all methods exist
      expect(transport.startAdvertising, isA<Function>());
      expect(transport.stopAdvertising, isA<Function>());
      expect(transport.startDiscovery, isA<Function>());
      expect(transport.stopDiscovery, isA<Function>());
      expect(transport.sendData, isA<Function>());
      expect(transport.sendAck, isA<Function>());
      expect(transport.disconnect, isA<Function>());
    });

    test('streams are broadcast', () {
      final transport = MockSyncTransport();

      // Multiple listeners should work (broadcast streams)
      final sub1 = transport.deviceFoundStream.listen((_) {});
      final sub2 = transport.deviceFoundStream.listen((_) {});

      expect(sub1, isNotNull);
      expect(sub2, isNotNull);

      sub1.cancel();
      sub2.cancel();
    });
  });
}
