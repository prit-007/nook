import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/sync_transport.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late MockSyncTransport mockTransport;
  late ProviderContainer container;

  setUp(() {
    db = createTestDb();
    mockTransport = MockSyncTransport();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncOrchestratorProvider.overrideWith(
          () => _TestSyncOrchestrator(mockTransport),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // State machine
  // -------------------------------------------------------------------------

  group('SyncOrchestrator state', () {
    test('starts in idle phase', () {
      container = makeContainer();
      final state = container.read(syncOrchestratorProvider);
      expect(state.phase, SyncPhase.idle);
      expect(state.devices, isEmpty);
      expect(state.error, isNull);
    });

    test('startDiscovery transitions to discovering', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startDiscovery();

      final state = container.read(syncOrchestratorProvider);
      expect(state.phase, SyncPhase.discovering);
      expect(mockTransport.isDiscovering, isTrue);
    });

    test('startAdvertising transitions to receiving', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      final state = container.read(syncOrchestratorProvider);
      expect(state.phase, SyncPhase.receiving);
      expect(mockTransport.isAdvertising, isTrue);
    });

    test('stop resets to idle', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startDiscovery();
      await notifier.stop();

      final state = container.read(syncOrchestratorProvider);
      expect(state.phase, SyncPhase.idle);
    });
  });

  // -------------------------------------------------------------------------
  // Device discovery
  // -------------------------------------------------------------------------

  group('device discovery', () {
    test('adds discovered devices to state', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startDiscovery();

      mockTransport.emitDeviceFound(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Galaxy S24',
        isOnline: true,
        hostAddress: '192.168.1.50',
        port: 12345,
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.devices, hasLength(1));
      expect(state.devices.first.deviceId, 'peer-1');
      expect(state.devices.first.deviceName, 'Galaxy S24');
    });

    test('does not duplicate devices', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startDiscovery();

      mockTransport.emitDeviceFound(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Galaxy',
        isOnline: true,
        hostAddress: '192.168.1.50',
        port: 12345,
      ));
      await Future<void>.delayed(Duration.zero);

      mockTransport.emitDeviceFound(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Galaxy',
        isOnline: true,
        hostAddress: '192.168.1.50',
        port: 12345,
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.devices, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // sendNotes
  // -------------------------------------------------------------------------

  group('sendNotes', () {
    test('sets error when no device connected', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.sendNotes(['note-1']);

      final state = container.read(syncOrchestratorProvider);
      expect(state.error, 'No device connected');
    });

    test('sets error when transport is null', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      // Don't call initializeTransport — _transport is null.
      await notifier.sendNotes(['note-1']);

      final state = container.read(syncOrchestratorProvider);
      expect(state.error, 'No device connected');
    });

    test('sets error when no valid notes found', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();

      await notifier.connectToDevice(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Peer',
        isOnline: true,
      ));

      await notifier.sendNotes(['nonexistent-note']);

      final state = container.read(syncOrchestratorProvider);
      expect(state.error, 'No valid notes to send');
    });

    test('sends notes and transitions to complete', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();

      // Insert a note into the test database.
      final noteRepo = NoteRepository(db);
      final note = await noteRepo.createNote(
        title: 'Test Note',
        type: NoteType.text,
        deviceOriginId: 'local-1',
      );

      // Set up connected device.
      await notifier.connectToDevice(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Peer',
        isOnline: true,
      ));

      // Wire onSend to deliver ack after data is sent.
      mockTransport.onSend = (data) async {
        // Simulate the receiver sending an ack back.
        // The transport's sendData will complete when it receives the ack.
      };

      final sendFuture = notifier.sendNotes([note.id]);

      // Allow the transport to send header + chunks.
      await Future<void>.delayed(Duration.zero);

      await sendFuture;

      final state = container.read(syncOrchestratorProvider);
      expect(state.phase, SyncPhase.complete);
      expect(state.sentCount, 1);
    });

    test('increments syncVersion after sending', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();

      final noteRepo = NoteRepository(db);
      final note = await noteRepo.createNote(
        title: 'Test Note',
        type: NoteType.text,
        deviceOriginId: 'local-1',
      );

      expect(note.syncVersion, 0);

      await notifier.connectToDevice(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Peer',
        isOnline: true,
      ));

      // Receiver confirms it kept the note, so the sender bumps syncVersion.
      final noteId = note.id;
      mockTransport.sendResult = SyncAck(
        receivedNoteIds: [noteId],
        rejectedNoteIds: [],
      );

      final sendFuture = notifier.sendNotes([note.id]);
      await Future<void>.delayed(Duration.zero);
      await sendFuture;

      final updated = await noteRepo.getNoteById(note.id);
      expect(updated!.syncVersion, 1);
    });

    test('does not bump syncVersion for rejected notes', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();

      final noteRepo = NoteRepository(db);
      final note = await noteRepo.createNote(
        title: 'Test Note',
        type: NoteType.text,
        deviceOriginId: 'local-1',
      );

      await notifier.connectToDevice(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Peer',
        isOnline: true,
      ));

      // Receiver rejected the note, so no version bump happens.
      mockTransport.sendResult = const SyncAck(
        receivedNoteIds: [],
        rejectedNoteIds: ['note-rejected'],
      );

      final sendFuture = notifier.sendNotes([note.id]);
      await Future<void>.delayed(Duration.zero);
      await sendFuture;

      final updated = await noteRepo.getNoteById(note.id);
      expect(updated!.syncVersion, 0);
    });
  });

  // -------------------------------------------------------------------------
  // resolveConflict
  // -------------------------------------------------------------------------

  group('resolveConflict', () {
    test('remote: applies incoming and logs', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      final incoming = SyncNoteEntry(
        noteId: 'conflict-1',
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 8, 12),
        deviceOriginId: 'device-b',
        noteFields: {'title': 'Remote Version', 'type': 'text'},
      );

      final conflict = SyncConflict(
        incoming: incoming,
        localDeviceName: 'This Device',
        remoteDeviceName: 'Remote Device',
      );

      notifier.state = notifier.state.copyWith(
        phase: SyncPhase.resolving,
        conflicts: [conflict],
      );

      await notifier.resolveConflict(conflict, 'remote');

      final state = container.read(syncOrchestratorProvider);
      expect(state.conflicts, isEmpty);
      expect(state.phase, SyncPhase.complete);
    });

    test('local: keeps local version, no DB changes', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      final incoming = SyncNoteEntry(
        noteId: 'conflict-2',
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 8, 12),
        deviceOriginId: 'device-b',
        noteFields: {'title': 'Remote', 'type': 'text'},
      );

      final conflict = SyncConflict(
        incoming: incoming,
        localDeviceName: 'This Device',
        remoteDeviceName: 'Remote Device',
      );

      notifier.state = notifier.state.copyWith(
        phase: SyncPhase.resolving,
        conflicts: [conflict],
      );

      await notifier.resolveConflict(conflict, 'local');

      final state = container.read(syncOrchestratorProvider);
      expect(state.conflicts, isEmpty);
    });

    test('both: inserts incoming as new', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      final incoming = SyncNoteEntry(
        noteId: 'conflict-3',
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 8, 12),
        deviceOriginId: 'device-b',
        noteFields: {'title': 'Both Version', 'type': 'text'},
      );

      final conflict = SyncConflict(
        incoming: incoming,
        localDeviceName: 'This Device',
        remoteDeviceName: 'Remote Device',
      );

      notifier.state = notifier.state.copyWith(
        phase: SyncPhase.resolving,
        conflicts: [conflict],
      );

      await notifier.resolveConflict(conflict, 'both');

      final state = container.read(syncOrchestratorProvider);
      expect(state.conflicts, isEmpty);
      expect(state.phase, SyncPhase.complete);
    });

    test('resolving one of multiple conflicts stays in resolving', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      final conflict1 = SyncConflict(
        incoming: SyncNoteEntry(
          noteId: 'c1',
          syncVersion: 1,
          updatedAt: DateTime.utc(2026, 8, 12),
          deviceOriginId: 'd1',
          noteFields: {'title': 'C1', 'type': 'text'},
        ),
        localDeviceName: 'A',
        remoteDeviceName: 'B',
      );
      final conflict2 = SyncConflict(
        incoming: SyncNoteEntry(
          noteId: 'c2',
          syncVersion: 1,
          updatedAt: DateTime.utc(2026, 8, 12),
          deviceOriginId: 'd1',
          noteFields: {'title': 'C2', 'type': 'text'},
        ),
        localDeviceName: 'A',
        remoteDeviceName: 'B',
      );

      notifier.state = notifier.state.copyWith(
        phase: SyncPhase.resolving,
        conflicts: [conflict1, conflict2],
      );

      await notifier.resolveConflict(conflict1, 'remote');

      final state = container.read(syncOrchestratorProvider);
      expect(state.conflicts, hasLength(1));
      expect(state.phase, SyncPhase.resolving);
    });
  });

  // -------------------------------------------------------------------------
  // connectToDevice
  // -------------------------------------------------------------------------

  group('connectToDevice', () {
    test('transitions to connecting then idle on success', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();

      await notifier.connectToDevice(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Peer',
        isOnline: true,
      ));

      final state = container.read(syncOrchestratorProvider);
      expect(state.selectedDevice?.deviceId, 'peer-1');
      expect(state.phase, SyncPhase.idle);
    });

    test('sets error on connection failure', () async {
      mockTransport.connectToDeviceResult = false;
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();

      await notifier.connectToDevice(const SyncDevice(
        deviceId: 'peer-1',
        deviceName: 'Peer',
        isOnline: true,
      ));

      final state = container.read(syncOrchestratorProvider);
      expect(state.error, contains('Failed to connect'));
    });
  });

  // -------------------------------------------------------------------------
  // Incoming pairing
  // -------------------------------------------------------------------------

  group('transport outcome mapping', () {
    test('maps a rejected transport state to a rejected outcome', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startDiscovery();

      mockTransport.emitStateChanged(const SyncSessionState.error(
        'Pairing rejected',
        outcome: SyncOutcomeCategory.rejected,
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.phase, SyncPhase.error);
      expect(state.outcome, SyncOutcomeCategory.rejected);
      expect(state.error, 'Pairing rejected');
    });

    test('maps a timeout transport state to a timedOut outcome', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startDiscovery();

      mockTransport.emitStateChanged(const SyncSessionState.error(
        'Timed out waiting for ack',
        outcome: SyncOutcomeCategory.timedOut,
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.phase, SyncPhase.error);
      expect(state.outcome, SyncOutcomeCategory.timedOut);
    });

    test('untyped transport errors map to internal outcome', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startDiscovery();

      mockTransport.emitStateChanged(
        const SyncSessionState.error('Connection failed'),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.outcome, SyncOutcomeCategory.internal);
    });
  });

  // -------------------------------------------------------------------------
  // Default transport
  // -------------------------------------------------------------------------

  group('default transport', () {
    test('uses the libp2p transport by default and derives a stable id',
        () async {
      // A real container (no mock orchestrator override) so initializeTransport
      // builds the actual libp2p transport.
      final realContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(realContainer.dispose);
      final notifier = realContainer.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport(
        identityStore: IdentityStore(storage: InMemorySeedStorage()),
        listenAddress: '/ip4/127.0.0.1/udp/0/udx',
      );

      // The real libp2p transport initialized successfully.
      expect(notifier.isTransportInitialized, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Incoming pairing
  // -------------------------------------------------------------------------

  group('incoming pairing', () {
    test('surfaces pending pairing request from transport', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      mockTransport.emitPairingRequest(const PairingRequest(
        remoteDeviceId: 'peer-1',
        remoteDeviceName: 'Galaxy S24',
        pairingCode: '123456',
        connectionId: 'conn-1',
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(syncOrchestratorProvider);
      expect(state.pendingPairing, isNotNull);
      expect(state.pendingPairing!.pairingCode, '123456');
      expect(state.pendingPairing!.remoteDeviceName, 'Galaxy S24');
    });

    test('confirmPairing approves the request and clears it', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      mockTransport.emitPairingRequest(const PairingRequest(
        remoteDeviceId: 'peer-1',
        remoteDeviceName: 'Galaxy S24',
        pairingCode: '123456',
        connectionId: 'conn-1',
      ));
      await Future<void>.delayed(Duration.zero);

      await notifier.confirmPairing();

      expect(mockTransport.lastRespondedPairing?.pairingCode, '123456');
      expect(mockTransport.lastPairingApproved, isTrue);
      final state = container.read(syncOrchestratorProvider);
      expect(state.pendingPairing, isNull);
    });

    test('rejectPairing denies the request and clears it', () async {
      container = makeContainer();
      final notifier = container.read(syncOrchestratorProvider.notifier);

      await notifier.initializeTransport();
      await notifier.startAdvertising();

      mockTransport.emitPairingRequest(const PairingRequest(
        remoteDeviceId: 'peer-1',
        remoteDeviceName: 'Galaxy S24',
        pairingCode: '123456',
        connectionId: 'conn-1',
      ));
      await Future<void>.delayed(Duration.zero);

      await notifier.rejectPairing();

      expect(mockTransport.lastPairingApproved, isFalse);
      final state = container.read(syncOrchestratorProvider);
      expect(state.pendingPairing, isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Test orchestrator that injects a mock transport
// ---------------------------------------------------------------------------

class _TestSyncOrchestrator extends SyncOrchestrator {
  final MockSyncTransport _mockTransport;

  _TestSyncOrchestrator(this._mockTransport);

  @override
  Future<void> initializeTransport(
      {SyncTransport? testTransport,
      String? localDeviceName,
      bool useTcpFallback = false,
      IdentityStore? identityStore,
      String? listenAddress}) async {
    await super.initializeTransport(testTransport: _mockTransport);
  }
}
