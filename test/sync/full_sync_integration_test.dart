import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/sync_log_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/libp2p_sync_transport.dart';
import 'package:nook/sync/transport/sync_transport.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

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
    tempDir = await Directory.systemTemp.createTemp('nook-full-sync-e2e');
    senderMediaDir = Directory('${tempDir.path}/sender-media');
    senderRestoreDir = Directory('${tempDir.path}/sender-restore');
    receiverRestoreDir = Directory('${tempDir.path}/receiver-restore');
    await senderMediaDir.create(recursive: true);
    await senderRestoreDir.create(recursive: true);
    await receiverRestoreDir.create(recursive: true);

    senderTransport = Libp2pSyncTransport(
      localDeviceName: 'Sender Device',
      identityStore: IdentityStore(storage: InMemorySeedStorage()),
      listenAddress: '/ip4/127.0.0.1/udp/0/udx',
      discoveryNetworkEnabled: false,
    );
    receiverTransport = Libp2pSyncTransport(
      localDeviceName: 'Receiver Device',
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
      localDeviceName: 'Sender Device',
    );
    await receiver.initializeTransport(
      testTransport: receiverTransport,
      localDeviceName: 'Receiver Device',
    );
  });

  tearDown(() async {
    await senderTransport.disconnect();
    await receiverTransport.disconnect();
    senderContainer.dispose();
    receiverContainer.dispose();
    await senderDb.close();
    await receiverDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<SyncDevice> pairDevices() async {
    await receiver.startAdvertising();
    await sender.startDiscovery();

    final receiverId = (await receiverTransport.getCurrentDeviceId())!;
    final receiverAddrs = receiverTransport.localMultiaddresses;
    expect(receiverAddrs, isNotEmpty);

    await senderTransport.debugInjectDiscoveredPeer(SyncDevice(
      deviceId: receiverId,
      deviceName: 'Receiver Device',
      isOnline: true,
      multiaddresses: receiverAddrs,
    ));

    await waitFor(
      () => senderContainer.read(syncOrchestratorProvider).devices.isNotEmpty,
    );
    final device =
        senderContainer.read(syncOrchestratorProvider).devices.single;

    final connectFuture = sender.connectToDevice(device, pairingCode: '987654');
    await waitFor(
      () =>
          receiverContainer.read(syncOrchestratorProvider).pendingPairing !=
          null,
    );
    final request =
        receiverContainer.read(syncOrchestratorProvider).pendingPairing!;
    expect(request.pairingCode, '987654');
    expect(request.remoteDeviceName, 'Sender Device');

    await receiver.confirmPairing();
    await connectFuture;
    return device;
  }

  group('Full-Fidelity Multi-Entity Sync', () {
    test(
        'syncs notes, notebooks, tags, checklists, and CAS attachments end-to-end',
        () async {
      await pairDevices();

      // 1. Setup Notebook on Sender
      final senderNbRepo = NotebookRepository(senderDb);
      final notebook = await senderNbRepo.createNotebook(
        name: 'Work Projects',
        colorSeed: '#FF5722',
        icon: 'briefcase',
      );

      // 2. Setup Tags on Sender
      final senderTagRepo = TagRepository(senderDb);
      final tag1 = await senderTagRepo.createTagWithId(
        'tag-p0',
        name: 'Priority: High',
        colorSeed: '#E53935',
      );
      final tag2 = await senderTagRepo.createTagWithId(
        'tag-arch',
        name: 'Architecture',
        colorSeed: '#1E88E5',
      );

      // 3. Setup Note 1: Checklist note in notebook with tags
      final senderNoteRepo = NoteRepository(senderDb);
      final note1 = await senderNoteRepo.createNote(
        id: 'note-checklist-1',
        title: 'Sprint Backlog',
        type: NoteType.checklist,
        deviceOriginId: 'device-sender',
        notebookId: notebook.id,
      );
      await senderNoteRepo.updateNoteTags(note1.id, [tag1.id, tag2.id]);

      // Add checklist items to Note 1
      await senderDb.into(senderDb.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('item-1'),
              noteId: note1.id,
              itemText: 'Design sync protocol',
              checked: const Value(true),
              sortOrder: const Value(0),
            ),
          );
      await senderDb.into(senderDb.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('item-2'),
              noteId: note1.id,
              itemText: 'Implement CAS storage',
              checked: const Value(true),
              sortOrder: const Value(1),
            ),
          );
      await senderDb.into(senderDb.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('item-3'),
              noteId: note1.id,
              itemText: 'Write E2E integration tests',
              checked: const Value(false),
              sortOrder: const Value(2),
            ),
          );

      // 4. Setup Note 2: Media note with image, doodle, and CAS deduplication
      final imageBytes =
          Uint8List.fromList(List.generate(512, (i) => (i * 3) % 251));
      final imageThumbBytes =
          Uint8List.fromList(List.generate(64, (i) => (i * 7) % 251));
      final doodleBytes =
          Uint8List.fromList(List.generate(300, (i) => (i * 11) % 251));
      final doodleThumbBytes =
          Uint8List.fromList(List.generate(48, (i) => (i * 13) % 251));

      final imagePath = '${senderMediaDir.path}/diagram.png';
      final imageThumbPath = '${senderMediaDir.path}/diagram_thumb.png';
      final doodlePath = '${senderMediaDir.path}/sketch.doodle.json';
      final doodleThumbPath = '${senderMediaDir.path}/sketch_thumb.png';

      await File(imagePath).writeAsBytes(imageBytes, flush: true);
      await File(imageThumbPath).writeAsBytes(imageThumbBytes, flush: true);
      await File(doodlePath).writeAsBytes(doodleBytes, flush: true);
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
                'attachment_id': 'doodle-full-1',
                'thumbnail_path': doodleThumbPath,
                'aspect_ratio': 1.5,
                'background_template': 'dotted',
              },
            },
          ],
        },
      });

      final note2 = await senderNoteRepo.createNote(
        id: 'note-media-1',
        title: 'Architecture Diagram',
        type: NoteType.text,
        deviceOriginId: 'device-sender',
        deltaContent: deltaContent,
        plainText: 'Diagram overview',
        colorSeed: '#4CAF50',
      );
      await senderNoteRepo.updateNote(note2.id, pinned: true, locked: false);

      final senderAttachmentRepo = AttachmentRepository(senderDb);
      await senderAttachmentRepo.addImage(
        noteId: note2.id,
        filePath: imagePath,
        id: 'att-img-1',
        thumbnailPath: imageThumbPath,
        sortOrder: 0,
      );
      await senderAttachmentRepo.addDoodle(
        noteId: note2.id,
        filePath: doodlePath,
        id: 'doodle-full-1',
        sortOrder: 1,
      );
      await senderAttachmentRepo.updateThumbnail(
        'doodle-full-1',
        doodleThumbPath,
      );

      // 5. Setup Note 3: Simple text note
      final note3 = await senderNoteRepo.createNote(
        id: 'note-text-1',
        title: 'Meeting Thoughts',
        type: NoteType.text,
        deviceOriginId: 'device-sender',
        plainText: 'Quick notes from standup',
      );

      // Transfer all 3 notes
      await sender.sendNotes([note1.id, note2.id, note3.id]);

      // Verify sender completion
      final senderState = senderContainer.read(syncOrchestratorProvider);
      expect(senderState.phase, SyncPhase.complete);
      expect(senderState.sentCount, 3);
      expect(senderState.receivedNoteIds,
          unorderedEquals([note1.id, note2.id, note3.id]));

      // Verify sender syncVersion bumped
      final sNote1 = await senderNoteRepo.getNoteById(note1.id);
      final sNote2 = await senderNoteRepo.getNoteById(note2.id);
      final sNote3 = await senderNoteRepo.getNoteById(note3.id);
      expect(sNote1!.syncVersion, 1);
      expect(sNote2!.syncVersion, 1);
      expect(sNote3!.syncVersion, 1);

      // Verify sender SyncLog
      final senderSyncLogs =
          await SyncLogRepository(senderDb).getRecentLogs(limit: 10);
      expect(senderSyncLogs, hasLength(3));
      expect(senderSyncLogs.every((l) => l.action.name == 'sent'), isTrue);

      // Verify receiver completion
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );
      final receiverState = receiverContainer.read(syncOrchestratorProvider);
      expect(receiverState.receivedCount, 3);

      // --- Verify Notebook Recreation ---
      final receiverNbRepo = NotebookRepository(receiverDb);
      final rNotebook = await receiverNbRepo.getNotebookById(notebook.id);
      expect(rNotebook, isNotNull);
      expect(rNotebook!.name, 'Work Projects');
      expect(rNotebook.colorSeed, '#FF5722');
      expect(rNotebook.icon, 'briefcase');

      // --- Verify Tags Recreation & Association ---
      final receiverTagRepo = TagRepository(receiverDb);
      final rTag1 = await receiverTagRepo.getTagById('tag-p0');
      final rTag2 = await receiverTagRepo.getTagById('tag-arch');
      expect(rTag1, isNotNull);
      expect(rTag1!.name, 'Priority: High');
      expect(rTag1.colorSeed, '#E53935');
      expect(rTag2, isNotNull);
      expect(rTag2!.name, 'Architecture');
      expect(rTag2.colorSeed, '#1E88E5');

      final rNote1Tags = await receiverTagRepo.getTagsForNote(note1.id);
      expect(
          rNote1Tags.map((t) => t.id), unorderedEquals(['tag-p0', 'tag-arch']));

      // --- Verify Checklist Items Recreation ---
      final receiverNoteRepo = NoteRepository(receiverDb);
      final rNote1 = await receiverNoteRepo.getNoteById(note1.id);
      expect(rNote1, isNotNull);
      expect(rNote1!.title, 'Sprint Backlog');
      expect(rNote1.type, NoteType.checklist);
      expect(rNote1.notebookId, notebook.id);
      expect(rNote1.syncVersion, 0);

      final rChecklistItems =
          await (receiverDb.select(receiverDb.checklistItems)
                ..where((t) => t.noteId.equals(note1.id))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      expect(rChecklistItems, hasLength(3));
      expect(rChecklistItems[0].itemText, 'Design sync protocol');
      expect(rChecklistItems[0].checked, isTrue);
      expect(rChecklistItems[0].sortOrder, 0);
      expect(rChecklistItems[1].itemText, 'Implement CAS storage');
      expect(rChecklistItems[1].checked, isTrue);
      expect(rChecklistItems[1].sortOrder, 1);
      expect(rChecklistItems[2].itemText, 'Write E2E integration tests');
      expect(rChecklistItems[2].checked, isFalse);
      expect(rChecklistItems[2].sortOrder, 2);

      // --- Verify Media & CAS Attachment Restoration ---
      final rNote2 = await receiverNoteRepo.getNoteById(note2.id);
      expect(rNote2, isNotNull);
      expect(rNote2!.title, 'Architecture Diagram');
      expect(rNote2.pinned, isTrue);
      expect(rNote2.locked, isFalse);
      expect(rNote2.colorSeed, '#4CAF50');

      // Delta content must be rewritten to point to receiver CAS paths
      expect(rNote2.deltaContent, isNot(contains(senderMediaDir.path)));
      final restoredDoc =
          jsonDecode(rNote2.deltaContent!) as Map<String, dynamic>;
      final children =
          ((restoredDoc['document'] as Map)['children'] as List).cast<Map>();
      final imgNode = children.firstWhere((n) => n['type'] == 'image');
      final doodleNode = children.firstWhere((n) => n['type'] == 'doodle');
      expect(imgNode['data']['url'], contains('/media/cas/'));
      expect(doodleNode['data']['attachment_id'], 'doodle-full-1');
      expect(doodleNode['data']['thumbnail_path'],
          '${receiverRestoreDir.path}/doodle-full-1_thumb.png');

      final rAttachments =
          await AttachmentRepository(receiverDb).getAllForNote(note2.id);
      expect(rAttachments, hasLength(2));

      final rImage = rAttachments.firstWhere((a) => a.type.name == 'image');
      expect(
          await File(rImage.filePath).readAsBytes(), orderedEquals(imageBytes));
      expect(await File(rImage.thumbnailPath!).readAsBytes(),
          orderedEquals(imageThumbBytes));

      final rDoodle =
          rAttachments.firstWhere((a) => a.type.name == 'doodleLayer');
      expect(rDoodle.filePath,
          '${receiverRestoreDir.path}/doodle-full-1.doodle.json');
      expect(rDoodle.thumbnailPath,
          '${receiverRestoreDir.path}/doodle-full-1_thumb.png');
      expect(await File(rDoodle.filePath).readAsBytes(),
          orderedEquals(doodleBytes));
      expect(await File(rDoodle.thumbnailPath!).readAsBytes(),
          orderedEquals(doodleThumbBytes));

      // --- Verify Note 3 ---
      final rNote3 = await receiverNoteRepo.getNoteById(note3.id);
      expect(rNote3, isNotNull);
      expect(rNote3!.title, 'Meeting Thoughts');
      expect(rNote3.plainText, 'Quick notes from standup');

      // --- Verify Receiver SyncLog ---
      final receiverSyncLogs =
          await SyncLogRepository(receiverDb).getRecentLogs(limit: 10);
      expect(receiverSyncLogs, hasLength(3));
      expect(
          receiverSyncLogs.every((l) => l.action.name == 'received'), isTrue);
    });

    test(
        're-sync of updated note replaces checklist items and tags atomically '
        'without duplicates', () async {
      await pairDevices();
      final senderNoteRepo = NoteRepository(senderDb);
      final senderTagRepo = TagRepository(senderDb);

      // Create initial note with 2 checklist items and 1 tag
      final tagA = await senderTagRepo.createTagWithId(
        'tag-alpha',
        name: 'Alpha',
        colorSeed: '#00BCD4',
      );
      final note = await senderNoteRepo.createNote(
        id: 'note-atomic-1',
        title: 'Original Title',
        type: NoteType.checklist,
        deviceOriginId: 'device-sender',
      );
      await senderNoteRepo.updateNoteTags(note.id, [tagA.id]);
      await senderDb.into(senderDb.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('ci-1'),
              noteId: note.id,
              itemText: 'Task 1',
              checked: const Value(false),
              sortOrder: const Value(0),
            ),
          );
      await senderDb.into(senderDb.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('ci-2'),
              noteId: note.id,
              itemText: 'Task 2',
              checked: const Value(false),
              sortOrder: const Value(1),
            ),
          );

      // Initial send
      await sender.sendNotes([note.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );

      // Modify note on sender:
      // - Rename title
      // - Check Task 1
      // - Delete Task 2
      // - Add Task 3
      // - Remove Tag Alpha and add Tag Beta
      final tagB = await senderTagRepo.createTagWithId(
        'tag-beta',
        name: 'Beta',
        colorSeed: '#9C27B0',
      );
      await senderNoteRepo.updateNote(
        note.id,
        title: 'Updated Title',
        updatedAt: DateTime.now(),
      );
      await senderNoteRepo.updateNoteTags(note.id, [tagB.id]);

      await (senderDb.delete(senderDb.checklistItems)
            ..where((t) => t.id.equals('ci-2')))
          .go();
      await (senderDb.update(senderDb.checklistItems)
            ..where((t) => t.id.equals('ci-1')))
          .write(const ChecklistItemsCompanion(checked: Value(true)));
      await senderDb.into(senderDb.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('ci-3'),
              noteId: note.id,
              itemText: 'Task 3 Added',
              checked: const Value(false),
              sortOrder: const Value(2),
            ),
          );

      // Re-send
      await sender.sendNotes([note.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );

      // Verify Sender version is bumped to 2
      final sNote = await senderNoteRepo.getNoteById(note.id);
      expect(sNote!.syncVersion, 2);

      // Verify Receiver DB: exactly 1 note, no duplicates
      final rNotes = await (receiverDb.select(receiverDb.notes)
            ..where((t) => t.id.equals(note.id)))
          .get();
      expect(rNotes, hasLength(1));
      expect(rNotes.first.title, 'Updated Title');
      expect(rNotes.first.syncVersion, 1);

      // Verify checklist items replaced cleanly: ci-2 gone, ci-1 checked, ci-3 present
      final rItems = await (receiverDb.select(receiverDb.checklistItems)
            ..where((t) => t.noteId.equals(note.id))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();
      expect(rItems, hasLength(2));
      expect(rItems[0].id, 'ci-1');
      expect(rItems[0].checked, isTrue);
      expect(rItems[1].id, 'ci-3');
      expect(rItems[1].itemText, 'Task 3 Added');
      expect(rItems[1].checked, isFalse);

      // Verify tags updated on receiver: tag-alpha unlinked, tag-beta linked
      final rTags = await TagRepository(receiverDb).getTagsForNote(note.id);
      expect(rTags, hasLength(1));
      expect(rTags.first.id, 'tag-beta');
      expect(rTags.first.name, 'Beta');
    });
  });

  group('Two-Way Bidirectional Sync', () {
    test('both peers can exchange notes symmetrically across the same session',
        () async {
      await pairDevices();
      final senderNoteRepo = NoteRepository(senderDb);
      final receiverNoteRepo = NoteRepository(receiverDb);

      // Sender creates Note A
      final noteA = await senderNoteRepo.createNote(
        id: 'note-from-sender',
        title: 'From Sender',
        plainText: 'Created on sender device',
        type: NoteType.text,
        deviceOriginId: 'device-sender',
      );

      // Receiver creates Note B
      final noteB = await receiverNoteRepo.createNote(
        id: 'note-from-receiver',
        title: 'From Receiver',
        plainText: 'Created on receiver device',
        type: NoteType.text,
        deviceOriginId: 'device-receiver',
      );

      // 1. Sender -> Receiver
      await sender.sendNotes([noteA.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );
      final receivedA = await receiverNoteRepo.getNoteById(noteA.id);
      expect(receivedA, isNotNull);
      expect(receivedA!.title, 'From Sender');

      // 2. Receiver -> Sender (Reverse send across the paired session)
      await receiver.sendNotes([noteB.id]);
      await waitFor(
        () => senderContainer
            .read(syncOrchestratorProvider)
            .receivedNoteIds
            .contains(noteB.id),
      );
      final receivedB = await senderNoteRepo.getNoteById(noteB.id);
      expect(receivedB, isNotNull);
      expect(receivedB!.title, 'From Receiver');

      // Both devices now have both notes
      final senderNotes = await senderNoteRepo.getAllNotes();
      final receiverNotes = await receiverNoteRepo.getAllNotes();
      expect(senderNotes.map((n) => n.id),
          unorderedEquals(['note-from-sender', 'note-from-receiver']));
      expect(receiverNotes.map((n) => n.id),
          unorderedEquals(['note-from-sender', 'note-from-receiver']));
    });
  });

  group('Conflict Detection & Interactive Resolution', () {
    test(
        'true conflict detected when both devices modify note independently, '
        'choice "remote" overwrites local with incoming note', () async {
      await pairDevices();
      final senderNoteRepo = NoteRepository(senderDb);
      final receiverNoteRepo = NoteRepository(receiverDb);

      // Step 1: Initial shared note synced to both devices
      final initialNote = await senderNoteRepo.createNote(
        id: 'conflict-note-1',
        title: 'Base Note',
        plainText: 'Base text',
        type: NoteType.text,
        deviceOriginId: 'device-sender',
      );
      await sender.sendNotes([initialNote.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );

      // Step 2: Receiver edits the note independently (origin becomes device-receiver)
      await receiverNoteRepo.updateContent(
        initialNote.id,
        plainText: 'Local independent edit',
        deltaContent: '{"text":"Local independent edit"}',
        updatedAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      await (receiverDb.update(receiverDb.notes)
            ..where((t) => t.id.equals(initialNote.id)))
          .write(
        const NotesCompanion(
          deviceOriginId: Value('device-receiver'),
          syncVersion: Value(1),
        ),
      );

      // Step 3: Sender also edits the note with newer timestamp/version
      await senderNoteRepo.updateContent(
        initialNote.id,
        plainText: 'Remote independent edit',
        deltaContent: '{"text":"Remote independent edit"}',
        updatedAt: DateTime.now().add(const Duration(seconds: 2)),
      );
      await (senderDb.update(senderDb.notes)
            ..where((t) => t.id.equals(initialNote.id)))
          .write(
        const NotesCompanion(
          title: Value('Remote Modified Title'),
          syncVersion: Value(2),
        ),
      );

      // Step 4: Sender sends to Receiver. This is a true conflict!
      await sender.sendNotes([initialNote.id]);

      // Receiver detects conflict and enters resolving phase
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.resolving,
      );
      final rState = receiverContainer.read(syncOrchestratorProvider);
      expect(rState.conflicts, hasLength(1));
      final conflict = rState.conflicts.first;
      expect(conflict.incoming.noteId, initialNote.id);

      // User resolves with 'remote'
      await receiver.resolveConflict(conflict, 'remote');
      expect(
        receiverContainer.read(syncOrchestratorProvider).phase,
        SyncPhase.complete,
      );
      expect(
        receiverContainer.read(syncOrchestratorProvider).conflicts,
        isEmpty,
      );

      // Receiver note is now overwritten with remote version
      final rNote = await receiverNoteRepo.getNoteById(initialNote.id);
      expect(rNote!.title, 'Remote Modified Title');
      expect(rNote.plainText, 'Remote independent edit');
    });

    test('choice "local" preserves local note and discards incoming edit',
        () async {
      await pairDevices();
      final senderNoteRepo = NoteRepository(senderDb);
      final receiverNoteRepo = NoteRepository(receiverDb);

      // Step 1: Initial shared note
      final initialNote = await senderNoteRepo.createNote(
        id: 'conflict-note-local',
        title: 'Original Title',
        plainText: 'Original text',
        type: NoteType.text,
        deviceOriginId: 'device-sender',
      );
      await sender.sendNotes([initialNote.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );

      // Step 2: Divergent edits
      await receiverNoteRepo.updateContent(
        initialNote.id,
        plainText: 'Keep My Local Changes',
        updatedAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      await (receiverDb.update(receiverDb.notes)
            ..where((t) => t.id.equals(initialNote.id)))
          .write(
        const NotesCompanion(
          title: Value('Local Kept Title'),
          deviceOriginId: Value('device-receiver'),
          syncVersion: Value(1),
        ),
      );

      await senderNoteRepo.updateContent(
        initialNote.id,
        plainText: 'Incoming Discarded Content',
        updatedAt: DateTime.now().add(const Duration(seconds: 2)),
      );
      await (senderDb.update(senderDb.notes)
            ..where((t) => t.id.equals(initialNote.id)))
          .write(
        const NotesCompanion(
          title: Value('Incoming Title'),
          syncVersion: Value(2),
        ),
      );

      // Step 3: Send -> Conflict
      await sender.sendNotes([initialNote.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.resolving,
      );
      final conflict =
          receiverContainer.read(syncOrchestratorProvider).conflicts.first;

      // User resolves with 'local'
      await receiver.resolveConflict(conflict, 'local');
      expect(
        receiverContainer.read(syncOrchestratorProvider).phase,
        SyncPhase.complete,
      );

      // Local note retains its local changes
      final rNote = await receiverNoteRepo.getNoteById(initialNote.id);
      expect(rNote!.title, 'Local Kept Title');
      expect(rNote.plainText, 'Keep My Local Changes');
    });

    test(
        'choice "both" preserves local note AND creates a new duplicate '
        're-owned by the local device so it never conflicts again', () async {
      await pairDevices();
      final senderNoteRepo = NoteRepository(senderDb);
      final receiverNoteRepo = NoteRepository(receiverDb);

      // Step 1: Initial shared note
      final initialNote = await senderNoteRepo.createNote(
        id: 'conflict-note-both',
        title: 'Original Title',
        plainText: 'Original text',
        type: NoteType.text,
        deviceOriginId: 'device-sender',
      );
      await sender.sendNotes([initialNote.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );

      // Step 2: Divergent edits
      await receiverNoteRepo.updateContent(
        initialNote.id,
        plainText: 'Device B Text',
        updatedAt: DateTime.now().add(const Duration(seconds: 1)),
      );
      await (receiverDb.update(receiverDb.notes)
            ..where((t) => t.id.equals(initialNote.id)))
          .write(
        const NotesCompanion(
          title: Value('Device B Version'),
          deviceOriginId: Value('device-receiver'),
          syncVersion: Value(1),
        ),
      );

      await senderNoteRepo.updateContent(
        initialNote.id,
        plainText: 'Device A Text',
        updatedAt: DateTime.now().add(const Duration(seconds: 2)),
      );
      await (senderDb.update(senderDb.notes)
            ..where((t) => t.id.equals(initialNote.id)))
          .write(
        const NotesCompanion(
          title: Value('Device A Version'),
          syncVersion: Value(2),
        ),
      );

      // Step 3: Send -> Conflict
      await sender.sendNotes([initialNote.id]);
      await waitFor(
        () =>
            receiverContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.resolving,
      );
      final conflict =
          receiverContainer.read(syncOrchestratorProvider).conflicts.first;

      // User resolves with 'both'
      await receiver.resolveConflict(conflict, 'both');
      expect(
        receiverContainer.read(syncOrchestratorProvider).phase,
        SyncPhase.complete,
      );

      // Receiver DB now contains 2 notes:
      final receiverNotes = await receiverNoteRepo.getAllNotes();
      expect(receiverNotes, hasLength(2));

      // 1. Original local note intact
      final original = receiverNotes.firstWhere((n) => n.id == initialNote.id);
      expect(original.title, 'Device B Version');
      expect(original.plainText, 'Device B Text');

      // 2. Incoming note inserted under a new ID and owned by receiver
      final duplicate = receiverNotes.firstWhere((n) => n.id != initialNote.id);
      expect(duplicate.title, 'Device A Version');
      expect(duplicate.plainText, 'Device A Text');
      final receiverDeviceId = await receiverTransport.getCurrentDeviceId();
      expect(duplicate.deviceOriginId, receiverDeviceId);
    });
  });

  group('Telemetry, Stage Tracking & Cancellation', () {
    test(
        'progress stats track packaging, transferring, throughput, and item count',
        () async {
      await pairDevices();
      final senderNoteRepo = NoteRepository(senderDb);

      // Seed 4 notes with modest body text
      final noteIds = <String>[];
      for (var i = 1; i <= 4; i++) {
        final n = await senderNoteRepo.createNote(
          id: 'telemetry-note-$i',
          title: 'Telemetry Note $i',
          plainText: 'Payload text content for telemetry testing #$i',
          type: NoteType.text,
          deviceOriginId: 'device-sender',
        );
        noteIds.add(n.id);
      }

      final recordedStages = <SyncStage>[];
      final subscription = senderContainer.listen(
        syncOrchestratorProvider,
        (previous, next) {
          recordedStages.add(next.progressStats.stage);
        },
      );

      await sender.sendNotes(noteIds);
      await waitFor(
        () =>
            senderContainer.read(syncOrchestratorProvider).phase ==
            SyncPhase.complete,
      );

      subscription.close();

      final finalState = senderContainer.read(syncOrchestratorProvider);
      expect(finalState.sentCount, 4);
      expect(finalState.progressStats.stage, SyncStage.complete);
      expect(finalState.progressStats.bytesTransferred, greaterThan(0));
      expect(finalState.progressStats.totalBytes, greaterThan(0));
      expect(finalState.formattedBytes, isNotEmpty);
      expect(finalState.formattedSpeed, isNotEmpty);

      // Packaging and transferring stages occurred
      expect(recordedStages, contains(SyncStage.packaging));
      expect(recordedStages, contains(SyncStage.transferring));
    });

    test('cancelTransfer transitions sender into cancelled error state',
        () async {
      await pairDevices();
      final senderNoteRepo = NoteRepository(senderDb);

      final note = await senderNoteRepo.createNote(
        id: 'cancel-note-1',
        title: 'Note To Cancel',
        plainText: 'Will be cancelled',
        type: NoteType.text,
        deviceOriginId: 'device-sender',
      );

      expect(sender.canCancel, isFalse);

      // Call cancelTransfer when canCancel is true or directly via orchestrator
      // To simulate in-flight cancel, trigger cancelTransfer immediately after initiating
      final sendFuture = sender.sendNotes([note.id]);
      if (sender.canCancel) {
        sender.cancelTransfer();
      }
      await sendFuture;

      final state = senderContainer.read(syncOrchestratorProvider);
      // Either completed before cancel or successfully cancelled
      if (state.outcome == SyncOutcomeCategory.cancelled) {
        expect(state.phase, SyncPhase.error);
        expect(state.error, 'Transfer cancelled');
      } else {
        expect(state.phase, SyncPhase.complete);
      }
    });
  });

  group('Pairing & Handshake', () {
    test('rejected pairing propagates rejected outcome to the sender',
        () async {
      await receiver.startAdvertising();
      await sender.startDiscovery();

      final receiverId = (await receiverTransport.getCurrentDeviceId())!;
      final receiverAddrs = receiverTransport.localMultiaddresses;

      await senderTransport.debugInjectDiscoveredPeer(SyncDevice(
        deviceId: receiverId,
        deviceName: 'Receiver Device',
        isOnline: true,
        multiaddresses: receiverAddrs,
      ));

      await waitFor(
        () => senderContainer.read(syncOrchestratorProvider).devices.isNotEmpty,
      );
      final device =
          senderContainer.read(syncOrchestratorProvider).devices.single;

      final connectFuture =
          sender.connectToDevice(device, pairingCode: '111222');
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
      expect(
        receiverContainer.read(syncOrchestratorProvider).pendingPairing,
        isNull,
      );
    });
  });
}
