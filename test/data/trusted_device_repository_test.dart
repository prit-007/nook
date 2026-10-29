import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/trusted_device_repository.dart';

void main() {
  late AppDatabase db;
  late TrustedDeviceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrustedDeviceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TrustedDeviceRepository', () {
    test('addOrUpdateTrustedDevice inserts a new trusted device', () async {
      final device = await repo.addOrUpdateTrustedDevice(
        peerId: '12D3KooWTestPeer1',
        deviceName: 'MacBook Pro',
        publicKey: 'pubkey123',
      );

      expect(device.peerId, '12D3KooWTestPeer1');
      expect(device.deviceName, 'MacBook Pro');
      expect(device.publicKey, 'pubkey123');
      expect(device.autoSyncEnabled, isTrue);
      expect(device.lastSyncedAt, isNull);
      expect(device.trustedAt, isNotNull);

      final fetched = await repo.getTrustedDeviceByPeerId('12D3KooWTestPeer1');
      expect(fetched, isNotNull);
      expect(fetched!.peerId, '12D3KooWTestPeer1');
      expect(fetched.deviceName, 'MacBook Pro');
    });

    test('addOrUpdateTrustedDevice updates an existing device name', () async {
      await repo.addOrUpdateTrustedDevice(
        peerId: '12D3KooWTestPeer1',
        deviceName: 'MacBook Pro',
      );

      final updated = await repo.addOrUpdateTrustedDevice(
        peerId: '12D3KooWTestPeer1',
        deviceName: 'MacBook Pro M3 Max',
      );

      expect(updated.deviceName, 'MacBook Pro M3 Max');
      final all = await repo.getTrustedDevices();
      expect(all.length, 1);
      expect(all.first.deviceName, 'MacBook Pro M3 Max');
    });

    test(
        'isDeviceTrusted returns true only for existing and auto-sync enabled devices',
        () async {
      expect(await repo.isDeviceTrusted('unknown-peer'), isFalse);

      await repo.addOrUpdateTrustedDevice(
        peerId: '12D3KooWTestPeer1',
        deviceName: 'Pixel 8',
      );
      expect(await repo.isDeviceTrusted('12D3KooWTestPeer1'), isTrue);

      await repo.setAutoSyncEnabled('12D3KooWTestPeer1', false);
      expect(await repo.isDeviceTrusted('12D3KooWTestPeer1'), isFalse);
    });

    test('updateLastSynced updates the lastSyncedAt timestamp', () async {
      await repo.addOrUpdateTrustedDevice(
        peerId: '12D3KooWTestPeer1',
        deviceName: 'Pixel 8',
      );

      final syncTime = DateTime(2026, 10, 29, 12, 0, 0);
      await repo.updateLastSynced('12D3KooWTestPeer1', syncTime);

      final device = await repo.getTrustedDeviceByPeerId('12D3KooWTestPeer1');
      expect(device?.lastSyncedAt, syncTime);
    });

    test('untrustDevice removes the device from trusted list', () async {
      await repo.addOrUpdateTrustedDevice(
        peerId: '12D3KooWTestPeer1',
        deviceName: 'Pixel 8',
      );
      expect(await repo.isDeviceTrusted('12D3KooWTestPeer1'), isTrue);

      await repo.untrustDevice('12D3KooWTestPeer1');
      expect(await repo.isDeviceTrusted('12D3KooWTestPeer1'), isFalse);
      expect(await repo.getTrustedDeviceByPeerId('12D3KooWTestPeer1'), isNull);
    });

    test('watchTrustedDevices emits live updates when devices change',
        () async {
      final stream = repo.watchTrustedDevices();
      final expectation = expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
          isEmpty,
        ]),
      );

      await pumpEventQueue();
      await repo.addOrUpdateTrustedDevice(
        peerId: 'peer-live',
        deviceName: 'Live Device',
      );
      await pumpEventQueue();
      await repo.untrustDevice('peer-live');

      await expectation;
    });
  });
}
