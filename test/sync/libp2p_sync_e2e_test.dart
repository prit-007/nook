import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/libp2p_sync_transport.dart';
import 'package:nook/sync/transport/sync_transport.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

/// Polls [condition] until it returns true or [timeout] elapses. Throws on
/// timeout so a failing async pipeline fails the test loudly.
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue, reason: 'condition never became true');
}

/// Writes a note with an image + a doodle layer (real files on disk) into
/// [db]. The delta references the on-disk paths, matching how a real device
/// serialises a document, so the receiver must restore the bytes and re-point
/// the delta at its own local files.
Future<String> seedSenderMediaNote(AppDatabase db, Directory mediaDir) async {
  await mediaDir.create(recursive: true);
  final imageBytes = Uint8List.fromList(List.generate(512, (i) => i % 251));
  final imageThumbBytes =
      Uint8List.fromList(List.generate(64, (i) => (i * 5) % 251));
  final doodleBytes =
      Uint8List.fromList(List.generate(300, (i) => (i * 7) % 251));
  final doodleThumbBytes =
      Uint8List.fromList(List.generate(48, (i) => (i * 3) % 251));

  final imagePath = '${mediaDir.path}/photo.png';
  final imageThumbPath = '${mediaDir.path}/photo_thumb.png';
  final doodleSidecar = '${mediaDir.path}/sketch.doodle.json';
  final doodleThumbPath = '${mediaDir.path}/sketch_thumb.png';

  await File(imagePath).writeAsBytes(imageBytes, flush: true);
  await File(imageThumbPath).writeAsBytes(imageThumbBytes, flush: true);
  await File(doodleSidecar).writeAsBytes(doodleBytes, flush: true);
  await File(doodleThumbPath).writeAsBytes(doodleThumbBytes, flush: true);

  final deltaContent = jsonEncode({
    'document': {
      'type': 'page',
      'children': [
        {
          'type': 'image',
          'data': {'url': imagePath, 'align': 'center'},
        },
        {
          'type': 'doodle',
          'data': {
            'attachment_id': 'doodle-1',
            'thumbnail_path': doodleThumbPath,
            'aspect_ratio': 1.333,
            'background_template': 'dotted',
          },
        },
      ],
    },
  });

  final note = await NoteRepository(db).createNote(
    id: 'e2e-note-1',
    title: 'E2E Media Note',
    type: NoteType.text,
    deviceOriginId: 'device-windows',
    deltaContent: deltaContent,
    plainText: 'Body from the sender device',
  );

  final attachmentRepo = AttachmentRepository(db);
  await attachmentRepo.addImage(
    noteId: note.id,
    filePath: imagePath,
    id: 'img-1',
    thumbnailPath: imageThumbPath,
    sortOrder: 0,
  );
  await attachmentRepo.addDoodle(
    noteId: note.id,
    filePath: doodleSidecar,
    id: 'doodle-1',
    sortOrder: 1,
  );
  await attachmentRepo.updateThumbnail('doodle-1', doodleThumbPath);

  return note.id;
}

/// An orchestrator backed by a real [Libp2pSyncTransport] on loopback, with
/// mDNS disabled (no multicast) and attachments restored into [restoreDir].
class E2ESyncOrchestrator extends SyncOrchestrator {
  E2ESyncOrchestrator(this.restoreDir);

  final Directory restoreDir;

  @override
  Future<void> initializeTransport({
    SyncTransport? testTransport,
    String? localDeviceName,
    bool useTcpFallback = false,
    IdentityStore? identityStore,
    String? listenAddress,
    bool discoveryNetworkEnabled = true,
  }) async {
    restoredAttachmentsDirectoryOverride = restoreDir;
    await super.initializeTransport(
      testTransport: testTransport,
      localDeviceName: localDeviceName,
      useTcpFallback: useTcpFallback,
      identityStore: identityStore,
      listenAddress: listenAddress ?? '/ip4/127.0.0.1/udp/0/udx',
      discoveryNetworkEnabled: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase senderDb;
  late AppDatabase receiverDb;
  late Directory tempDir;
  late Directory senderMediaDir;
  late Directory senderRestoreDir;
  late Directory receiverRestoreDir;
  late Libp2pSyncTransport senderTransport;
  late Libp2pSyncTransport receiverTransport;
  late ProviderContainer senderContainer;
  late ProviderContainer receiverContainer;
  late SyncOrchestrator sender;
  late SyncOrchestrator receiver;

  setUp(() async {
    senderDb = createTestDb();
    receiverDb = createTestDb();
    tempDir = await Directory.systemTemp.createTemp('nook-e2e');
    senderMediaDir = Directory('${tempDir.path}/sender-media');
    senderRestoreDir = Directory('${tempDir.path}/sender-restore');
    receiverRestoreDir = Directory('${tempDir.path}/receiver-restore');

    senderTransport = Libp2pSyncTransport(
      localDeviceName: 'Sender Phone',
      identityStore: IdentityStore(storage: InMemorySeedStorage()),
      listenAddress: '/ip4/127.0.0.1/udp/0/udx',
      discoveryNetworkEnabled: false,
    );
    receiverTransport = Libp2pSyncTransport(
      localDeviceName: 'Receiver Phone',
      identityStore: IdentityStore(storage: InMemorySeedStorage()),
      listenAddress: '/ip4/127.0.0.1/udp/0/udx',
      discoveryNetworkEnabled: false,
    );
    await senderTransport.initialize();
    await receiverTransport.initialize();

    senderContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(senderDb),
        syncOrchestratorProvider.overrideWith(
          () => E2ESyncOrchestrator(senderRestoreDir),
        ),
      ],
    );
    receiverContainer = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(receiverDb),
        syncOrchestratorProvider.overrideWith(
          () => E2ESyncOrchestrator(receiverRestoreDir),
        ),
      ],
    );

    sender = senderContainer.read(syncOrchestratorProvider.notifier);
    receiver = receiverContainer.read(syncOrchestratorProvider.notifier);

    await sender.initializeTransport(
      testTransport: senderTransport,
      localDeviceName: 'Sender Phone',
    );
    await receiver.initializeTransport(
      testTransport: receiverTransport,
      localDeviceName: 'Receiver Phone',
    );
  });

  tearDown(() async {
    // Close hosts first (awaited, single close), then dispose the containers
    // which only closes the transport's stream controllers.
    await senderTransport.disconnect();
    await receiverTransport.disconnect();
    senderContainer.dispose();
    receiverContainer.dispose();
    await senderDb.close();
    await receiverDb.close();
    await tempDir.delete(recursive: true);
  });

  /// Common setup: receiver advertises, sender discovers and "finds" the
  /// receiver through the discovery pipeline (no multicast in tests).
  Future<SyncDevice> discoverReceiver() async {
    await receiver.startAdvertising();
    await sender.startDiscovery();

    final receiverId = (await receiverTransport.getCurrentDeviceId())!;
    final receiverAddrs = receiverTransport.localMultiaddresses;
    expect(receiverAddrs, isNotEmpty,
        reason: 'receiver must expose a listen addr');

    await senderTransport.debugInjectDiscoveredPeer(SyncDevice(
      deviceId: receiverId,
      deviceName: 'Receiver Phone',
      isOnline: true,
      multiaddresses: receiverAddrs,
    ));

    await waitFor(
      () => senderContainer.read(syncOrchestratorProvider).devices.isNotEmpty,
    );
    final device =
        senderContainer.read(syncOrchestratorProvider).devices.single;
    expect(device.deviceId, receiverId);
    expect(device.deviceName, 'Receiver Phone');
    expect(device.multiaddresses, receiverAddrs);
    return device;
  }

  /// Pairs sender->receiver and confirms the pairing on the receiver side.
  Future<void> pairWith(SyncDevice device, String code) async {
    final connectFuture = sender.connectToDevice(device, pairingCode: code);
    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).pendingPairing !=
          null,
    );
    final request =
        receiverContainer.read(syncOrchestratorProvider).pendingPairing!;
    expect(request.pairingCode, code);
    expect(request.remoteDeviceName, 'Sender Phone');
    await receiver.confirmPairing();
    await connectFuture;
  }

  test(
      'sender finds the receiver, pairs, and syncs a media note byte-for-byte '
      'on both sides', () async {
    final device = await discoverReceiver();

    final noteId = await seedSenderMediaNote(senderDb, senderMediaDir);

    // Pair.
    await pairWith(device, '246810');
    expect(
      senderContainer.read(syncOrchestratorProvider).selectedDevice?.deviceId,
      device.deviceId,
    );

    // Transfer. The receiver auto-restores media + rewrites the delta + acks.
    await sender.sendNotes([noteId]);

    // --- Sender side ---
    final senderState = senderContainer.read(syncOrchestratorProvider);
    expect(senderState.phase, SyncPhase.complete);
    expect(senderState.sentCount, 1);
    expect(senderState.receivedNoteIds, ['e2e-note-1']);
    final senderNote = await NoteRepository(senderDb).getNoteById(noteId);
    expect(senderNote!.syncVersion, 1,
        reason: 'an accepted note bumps syncVersion');

    // --- Receiver side ---
    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).phase ==
          SyncPhase.complete,
    );
    final receiverNote = await NoteRepository(receiverDb).getNoteById(noteId);
    expect(receiverNote, isNotNull, reason: 'receiver must insert the note');
    expect(receiverNote!.title, 'E2E Media Note');
    expect(receiverNote.plainText, 'Body from the sender device');
    expect(receiverNote.deviceOriginId, 'device-windows');
    expect(receiverNote.syncVersion, 0,
        reason: 'receiver stores the version that was transmitted (the sender '
            'bumps its own copy after the ack)');

    // The delta must reference the receiver's restored files now, never the
    // sender's on-disk paths.
    expect(receiverNote.deltaContent, isNot(contains(senderMediaDir.path)));
    final restoredDoc =
        jsonDecode(receiverNote.deltaContent!) as Map<String, dynamic>;
    final children =
        ((restoredDoc['document'] as Map)['children'] as List).cast<Map>();
    final imageNode = children.firstWhere((n) => n['type'] == 'image');
    final doodleNode = children.firstWhere((n) => n['type'] == 'doodle');
    expect(imageNode['data']['url'],
        '${receiverRestoreDir.path}/sync/attachments/e2e-note-1_img-1.img');
    expect(doodleNode['data']['attachment_id'], 'doodle-1');
    expect(doodleNode['data']['thumbnail_path'],
        '${receiverRestoreDir.path}/doodle-1_thumb.png');

    // Media bytes must be identical, and the doodle sidecar must sit at the
    // canonical DoodleStorage location so strokes stay editable.
    final attachments =
        await AttachmentRepository(receiverDb).getAllForNote(noteId);
    expect(attachments, hasLength(2));

    final doodle = attachments.firstWhere((a) => a.type.name == 'doodleLayer');
    expect(doodle.id, 'doodle-1');
    expect(doodle.filePath, '${receiverRestoreDir.path}/doodle-1.doodle.json');
    expect(
        doodle.thumbnailPath, '${receiverRestoreDir.path}/doodle-1_thumb.png');
    expect(
      await File(doodle.filePath).readAsBytes(),
      orderedEquals(
          File('${senderMediaDir.path}/sketch.doodle.json').readAsBytesSync()),
    );
    expect(
      await File(doodle.thumbnailPath!).readAsBytes(),
      orderedEquals(
          File('${senderMediaDir.path}/sketch_thumb.png').readAsBytesSync()),
    );

    final image = attachments.firstWhere((a) => a.type.name == 'image');
    expect(image.id, 'img-1');
    expect(
      await File(image.filePath).readAsBytes(),
      orderedEquals(File('${senderMediaDir.path}/photo.png').readAsBytesSync()),
    );
    expect(
      await File(image.thumbnailPath!).readAsBytes(),
      orderedEquals(
          File('${senderMediaDir.path}/photo_thumb.png').readAsBytesSync()),
    );
  });

  test('re-sync of a locally edited note overwrites without duplicating',
      () async {
    final device = await discoverReceiver();
    final noteId = await seedSenderMediaNote(senderDb, senderMediaDir);
    await pairWith(device, '135790');
    await sender.sendNotes([noteId]);
    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).phase ==
          SyncPhase.complete,
    );

    // Edit the note on the sender and sync again.
    final editedDelta = jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'children': [
              {'type': 'text', 'text': 'edited'},
            ],
          },
        ],
      },
    });
    await NoteRepository(senderDb).updateContent(
      noteId,
      deltaContent: editedDelta,
      plainText: 'Edited on the sender',
      updatedAt: DateTime.now(),
    );

    await sender.sendNotes([noteId]);
    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).phase ==
          SyncPhase.complete,
    );

    final senderNote = await NoteRepository(senderDb).getNoteById(noteId);
    expect(senderNote!.syncVersion, 2, reason: 'two successful sends');

    // Still exactly one note on the receiver — overwritten, not duplicated.
    final rows = await (receiverDb.select(receiverDb.notes)
          ..where((t) => t.id.equals(noteId)))
        .get();
    expect(rows, hasLength(1));
    expect(rows.first.plainText, 'Edited on the sender');
    expect(rows.first.deltaContent, editedDelta);
    expect(rows.first.syncVersion, 1,
        reason: 'receiver mirrors the sent version');

    // No lingering attachment rows from the first sync either.
    final attachments =
        await AttachmentRepository(receiverDb).getAllForNote(noteId);
    expect(attachments, hasLength(2));
  });

  test('rejected pairing propagates a rejected outcome to the sender',
      () async {
    final device = await discoverReceiver();

    final connectFuture = sender.connectToDevice(device, pairingCode: '000000');
    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).pendingPairing !=
          null,
    );
    await receiver.rejectPairing();
    await connectFuture;

    await waitFor(
      () =>
          senderContainer.read(syncOrchestratorProvider).outcome ==
          SyncOutcomeCategory.rejected,
    );
    final state = senderContainer.read(syncOrchestratorProvider);
    expect(state.phase, SyncPhase.error);
    expect(state.error, 'Pairing rejected');

    // Receiver cleaned up its pending pairing.
    expect(
      receiverContainer.read(syncOrchestratorProvider).pendingPairing,
      isNull,
    );
  });

  test(
      'acceptor (PC) can send data to the dialer (mobile) after approving '
      'pairing — the ShareIt-style reverse send', () async {
    // Both devices are in receive/advertise mode: the mobile scans the PC's QR
    // and dials it; the PC accepts, then pushes notes back to the mobile.
    await receiver.startAdvertising();
    await sender.startAdvertising();

    // The mobile "scans the PC's QR" = dials the PC's local address directly.
    final pcDevice = SyncDevice(
      deviceId: (await receiverTransport.getCurrentDeviceId())!,
      deviceName: 'PC',
      isOnline: true,
      multiaddresses: receiverTransport.localMultiaddresses,
    );
    final connectFuture =
        sender.connectToDevice(pcDevice, pairingCode: '112233');
    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).pendingPairing !=
          null,
    );
    await receiver.confirmPairing();
    await connectFuture;

    // The PC (which was dialed) sends a note back to the mobile (which
    // dialed). This is the exact reverse of the normal send.
    final noteId = await seedSenderMediaNote(receiverDb, senderMediaDir);
    await receiver.sendNotes([noteId]);

    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).phase ==
          SyncPhase.complete,
    );

    // The mobile side must have received the note.
    await waitFor(
      () =>
          senderContainer.read(syncOrchestratorProvider).phase ==
          SyncPhase.complete,
    );
    final receivedNote = await NoteRepository(senderDb).getNoteById(noteId);
    expect(receivedNote, isNotNull);
    expect(receivedNote!.title, 'E2E Media Note');
    expect(receivedNote.plainText, 'Body from the sender device');
  });
}
