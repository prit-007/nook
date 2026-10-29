import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/trusted_device_repository.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/sync_transport.dart';

class _TestSyncOrchestrator extends SyncOrchestrator {
  final MockSyncTransport _mockTransport;

  _TestSyncOrchestrator(this._mockTransport);

  @override
  Future<void> initializeTransport({
    SyncTransport? testTransport,
    String? localDeviceName,
    bool useTcpFallback = false,
    IdentityStore? identityStore,
    String? listenAddress,
    bool discoveryNetworkEnabled = true,
  }) async {
    await super.initializeTransport(testTransport: _mockTransport);
  }
}

void main() {
  late AppDatabase db;
  late MockSyncTransport mockTransport;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    mockTransport = MockSyncTransport();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncOrchestratorProvider.overrideWith(
          () => _TestSyncOrchestrator(mockTransport),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Trusted Device Auto-Pairing (TDD)', () {
    test(
        'untrusted peer surfaces pendingPairing and saves to trusted_devices on confirm',
        () async {
      final notifier = container.read(syncOrchestratorProvider.notifier);
      final trustedRepo = TrustedDeviceRepository(db);

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      expect(await trustedRepo.isDeviceTrusted('peer-unknown'), isFalse);

      mockTransport.emitPairingRequest(const PairingRequest(
        remoteDeviceId: 'peer-unknown',
        remoteDeviceName: 'Pixel 9 Pro',
        pairingCode: '123456',
        connectionId: 'conn-1',
      ));
      await Future<void>.delayed(Duration.zero);

      final stateBefore = container.read(syncOrchestratorProvider);
      expect(stateBefore.pendingPairing, isNotNull);
      expect(stateBefore.pendingPairing!.remoteDeviceId, 'peer-unknown');

      // User confirms pairing
      await notifier.confirmPairing();

      final stateAfter = container.read(syncOrchestratorProvider);
      expect(stateAfter.pendingPairing, isNull);
      expect(stateAfter.selectedDevice?.deviceId, 'peer-unknown');
      expect(mockTransport.lastPairingApproved, isTrue);

      // Verify peer is now trusted in DB
      expect(await trustedRepo.isDeviceTrusted('peer-unknown'), isTrue);
      final device = await trustedRepo.getTrustedDeviceByPeerId('peer-unknown');
      expect(device?.deviceName, 'Pixel 9 Pro');
    });

    test('trusted peer auto-approves pairing without user confirmation',
        () async {
      final notifier = container.read(syncOrchestratorProvider.notifier);
      final trustedRepo = TrustedDeviceRepository(db);

      // Pre-trust the peer
      await trustedRepo.addOrUpdateTrustedDevice(
        peerId: 'peer-trusted',
        deviceName: 'iPad Pro',
      );
      expect(await trustedRepo.isDeviceTrusted('peer-trusted'), isTrue);

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      mockTransport.emitPairingRequest(const PairingRequest(
        remoteDeviceId: 'peer-trusted',
        remoteDeviceName: 'iPad Pro',
        pairingCode: '654321',
        connectionId: 'conn-auto',
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      // Must NOT require manual user confirmation
      expect(state.pendingPairing, isNull);
      // Auto-approved on transport
      expect(mockTransport.lastPairingApproved, isTrue);
      expect(
          mockTransport.lastRespondedPairing?.remoteDeviceId, 'peer-trusted');
      // Selected device is set
      expect(state.selectedDevice?.deviceId, 'peer-trusted');
    });

    test('peer with autoSyncEnabled=false is not auto-approved', () async {
      final notifier = container.read(syncOrchestratorProvider.notifier);
      final trustedRepo = TrustedDeviceRepository(db);

      await trustedRepo.addOrUpdateTrustedDevice(
        peerId: 'peer-disabled',
        deviceName: 'ThinkPad',
        autoSyncEnabled: false,
      );

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      mockTransport.emitPairingRequest(const PairingRequest(
        remoteDeviceId: 'peer-disabled',
        remoteDeviceName: 'ThinkPad',
        pairingCode: '112233',
        connectionId: 'conn-disabled',
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.pendingPairing, isNotNull);
      expect(mockTransport.lastPairingApproved, isNull);
    });

    test('untrusted peer after being revoked is not auto-approved', () async {
      final notifier = container.read(syncOrchestratorProvider.notifier);
      final trustedRepo = TrustedDeviceRepository(db);

      await trustedRepo.addOrUpdateTrustedDevice(
        peerId: 'peer-revoked',
        deviceName: 'Linux Desktop',
      );
      await trustedRepo.untrustDevice('peer-revoked');

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      mockTransport.emitPairingRequest(const PairingRequest(
        remoteDeviceId: 'peer-revoked',
        remoteDeviceName: 'Linux Desktop',
        pairingCode: '998877',
        connectionId: 'conn-revoked',
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.pendingPairing, isNotNull);
      expect(mockTransport.lastPairingApproved, isNull);
    });
  });
}
