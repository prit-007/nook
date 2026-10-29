import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/protocol/sync_digest.dart';
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

  group('Two-Way Sync Reconciliation (TDD)', () {
    test(
        'buildLocalDigest constructs entries with accurate hashes and versions',
        () async {
      final noteRepo = NoteRepository(db);
      final note1 = await noteRepo.createNote(
        title: 'Meeting Notes',
        plainText: 'Discuss Q4 roadmap',
        type: NoteType.text,
        deviceOriginId: 'test-device',
      );
      final note2 = await noteRepo.createNote(
        title: 'Groceries',
        plainText: 'Apples, Milk',
        type: NoteType.text,
        deviceOriginId: 'test-device',
      );

      final notifier = container.read(syncOrchestratorProvider.notifier);
      await notifier.initializeTransport();

      final digest = await notifier.buildLocalDigest();
      expect(digest.entries.length, 2);

      final d1 = digest.entries.firstWhere((e) => e.noteId == note1.id);
      expect(d1.syncVersion, 0);
      expect(d1.deleted, isFalse);
      expect(d1.contentHash, isNotNull);

      // Verify contentHash matches sha256 of title + plainText
      final expectedHash = sha256
          .convert(utf8.encode('${note1.title}:${note1.plainText ?? ''}:'))
          .toString();
      expect(d1.contentHash, expectedHash);

      final d2 = digest.entries.firstWhere((e) => e.noteId == note2.id);
      expect(d2.noteId, note2.id);
    });

    test(
        'reconcileWithRemote computes minimal push list and skips identical notes',
        () async {
      final noteRepo = NoteRepository(db);
      final localNote = await noteRepo.createNote(
        title: 'Local Only',
        plainText: 'Created locally',
        type: NoteType.text,
        deviceOriginId: 'test-device',
      );
      final sharedNote = await noteRepo.createNote(
        title: 'Shared Note',
        plainText: 'Both devices have this',
        type: NoteType.text,
        deviceOriginId: 'test-device',
      );

      final notifier = container.read(syncOrchestratorProvider.notifier);
      await notifier.initializeTransport();
      final localDigest = await notifier.buildLocalDigest();

      final sharedEntry =
          localDigest.entries.firstWhere((e) => e.noteId == sharedNote.id);

      final remoteDigest = SyncDigest(
        deviceId: 'remote-device',
        entries: [
          // Remote has identical sharedNote
          sharedEntry,
          // Remote has a note that local does not have
          NoteDigestEntry(
            noteId: 'remote-only-id',
            updatedAt: DateTime.now().toUtc(),
            syncVersion: 1,
            contentHash: 'hash-remote',
          ),
        ],
      );

      final plan = notifier.reconcile(remoteDigest, localDigest: localDigest);
      expect(plan.notesToPush, [localNote.id]);
      expect(plan.notesToPull, ['remote-only-id']);
      expect(plan.identicalNotes, [sharedNote.id]);
      expect(plan.conflicts, isEmpty);
    });
  });
}
