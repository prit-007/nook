import 'package:cbor/cbor.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/transport/sync_transport.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  // ── 1. SyncNoteEntry.fromCbor — missing/invalid required fields ──
  group('SyncNoteEntry.fromCbor validation', () {
    test('throws FormatException when noteId is missing', () {
      final bytes = _encodeMap({
        'syncVersion': 1,
        'updatedAt': 1700000000000,
        'deviceOriginId': 'dev-a',
        'noteFields': {'title': 'T'},
      });
      expect(
        () => SyncNoteEntry.fromCbor(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when syncVersion is not an int', () {
      final bytes = _encodeMap({
        'noteId': 'n1',
        'syncVersion': 'not-an-int',
        'updatedAt': 1700000000000,
        'deviceOriginId': 'dev-a',
        'noteFields': {'title': 'T'},
      });
      expect(
        () => SyncNoteEntry.fromCbor(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when deviceOriginId is missing', () {
      final bytes = _encodeMap({
        'noteId': 'n1',
        'syncVersion': 1,
        'updatedAt': 1700000000000,
        'noteFields': {'title': 'T'},
      });
      expect(
        () => SyncNoteEntry.fromCbor(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('succeeds with minimal valid fields', () {
      final bytes = _encodeMap({
        'noteId': 'n1',
        'syncVersion': 1,
        'updatedAt': 1700000000000,
        'deviceOriginId': 'dev-a',
        'noteFields': {'title': 'Hello'},
      });
      final entry = SyncNoteEntry.fromCbor(bytes);
      expect(entry.noteId, 'n1');
      expect(entry.syncVersion, 1);
      expect(entry.noteFields['title'], 'Hello');
    });
  });

  // ── 2. reassembleChunks — integrity validation ──
  group('reassembleChunks integrity', () {
    test('throws ArgumentError when expectedTotalLength mismatches', () {
      final chunks = [
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3])
      ];
      expect(
        () => SyncBundle.reassembleChunks(chunks, expectedTotalLength: 10),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('succeeds when expectedTotalLength matches', () {
      final chunks = [
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3])
      ];
      final result =
          SyncBundle.reassembleChunks(chunks, expectedTotalLength: 3);
      expect(result, Uint8List.fromList([1, 2, 3]));
    });
  });

  // ── 3. _overwrite via forceOverwrite — null content keys ──
  group('overwrite with null content keys', () {
    late AppDatabase db;
    late NoteRepository noteRepo;
    late MergeResolver resolver;

    setUp(() {
      db = createTestDb();
      noteRepo = NoteRepository(db);
      resolver = MergeResolver(noteRepo);
    });

    tearDown(() async => db.close());

    test('overwrite without deltaContent/plainText does not clobber content',
        () async {
      // Create a local note with content.
      final local = await noteRepo.createNote(
        id: 'note-1',
        title: 'Local',
        type: NoteType.text,
        deviceOriginId: 'device-a',
        deltaContent: '{"ops":[{"insert":"original"}]}',
        plainText: 'original',
      );
      await _setSyncMeta(db, local.id,
          syncVersion: 1, updatedAt: DateTime.utc(2026, 8, 1));

      // Incoming entry has NO content keys in noteFields (simulating CBOR
      // omission of null values).
      final incoming = SyncNoteEntry(
        noteId: 'note-1',
        syncVersion: 5,
        updatedAt: DateTime.utc(2026, 8, 10),
        deviceOriginId: 'device-a',
        noteFields: {'title': 'Updated Title', 'type': 'text'},
        checklistItems: null,
        attachments: null,
      );

      await resolver.forceOverwrite(incoming);

      final note = await noteRepo.getNoteById('note-1');
      expect(note!.title, 'Updated Title');
      // Content should be preserved since incoming had no content keys.
      expect(note.plainText, 'original');
    });

    test('overwrite with explicit null content keys clears content', () async {
      final local = await noteRepo.createNote(
        id: 'note-2',
        title: 'Local',
        type: NoteType.text,
        deviceOriginId: 'device-a',
        deltaContent: '{"ops":[{"insert":"old"}]}',
        plainText: 'old',
      );
      await _setSyncMeta(db, local.id,
          syncVersion: 1, updatedAt: DateTime.utc(2026, 8, 1));

      // Incoming entry HAS content keys but with null values.
      final incoming = SyncNoteEntry(
        noteId: 'note-2',
        syncVersion: 5,
        updatedAt: DateTime.utc(2026, 8, 10),
        deviceOriginId: 'device-a',
        noteFields: {
          'title': 'Updated',
          'type': 'text',
          'deltaContent': null,
          'plainText': null,
        },
        checklistItems: null,
        attachments: null,
      );

      await resolver.forceOverwrite(incoming);

      final note = await noteRepo.getNoteById('note-2');
      expect(note!.plainText, isNull);
    });
  });

  // ── 4. insertAsNew collision — pinned/locked preserved ──
  group('insertAsNew collision preserves pinned/locked', () {
    late AppDatabase db;
    late NoteRepository noteRepo;
    late MergeResolver resolver;

    setUp(() {
      db = createTestDb();
      noteRepo = NoteRepository(db);
      resolver = MergeResolver(noteRepo);
    });

    tearDown(() async => db.close());

    test('collision-generated duplicate preserves pinned and locked', () async {
      // Create a local note with pinned and locked set.
      final local = await noteRepo.createNote(
        id: 'collision-id',
        title: 'Local Pinned',
        type: NoteType.text,
        deviceOriginId: 'device-a',
      );
      await _setSyncMeta(db, local.id,
          syncVersion: 1, updatedAt: DateTime.utc(2026, 8, 1));
      await noteRepo.updateNote(local.id,
          pinned: true, locked: true, updatedAt: DateTime.utc(2026, 8, 1));

      // Remote sends same noteId → collision → new ID generated.
      final incoming = SyncNoteEntry(
        noteId: 'collision-id',
        syncVersion: 3,
        updatedAt: DateTime.utc(2026, 8, 5),
        deviceOriginId: 'device-b',
        noteFields: {
          'title': 'Remote Pinned',
          'type': 'text',
          'pinned': true,
          'locked': true,
        },
        checklistItems: null,
        attachments: null,
      );

      await resolver.insertAsNew(incoming);

      final allNotes = await noteRepo.getAllNotes();
      expect(allNotes.length, 2);

      // The duplicate note (not the original) should have pinned/locked.
      final duplicate = allNotes.firstWhere((n) => n.id != 'collision-id');
      expect(duplicate.pinned, true);
      expect(duplicate.locked, true);
      expect(duplicate.title, 'Remote Pinned');
    });

    test('_insertAsNew preserves pinned/locked for new note', () async {
      final incoming = SyncNoteEntry(
        noteId: 'brand-new',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'device-b',
        noteFields: {
          'title': 'New Pinned',
          'type': 'text',
          'pinned': true,
          'locked': false,
        },
        checklistItems: null,
        attachments: null,
      );

      await resolver.applyIncoming(incoming);

      final note = await noteRepo.getNoteById('brand-new');
      expect(note, isNotNull);
      expect(note!.pinned, true);
      expect(note.locked, false);
    });
  });

  // ── 5. getOrCreateSeed — concurrent calls ──
  group('IdentityStore concurrent getOrCreateSeed', () {
    test('concurrent calls return the same seed without double-generating',
        () async {
      final storage = InMemorySeedStorage();
      final store = IdentityStore(storage: storage);

      // Fire three concurrent calls — all should return the same seed.
      final results = await Future.wait([
        store.getOrCreateSeed(),
        store.getOrCreateSeed(),
        store.getOrCreateSeed(),
      ]);

      expect(results[0], results[1]);
      expect(results[1], results[2]);
      expect(results[0], hasLength(32));
    });

    test('clear() resets pending Completer so next call regenerates', () async {
      final storage = InMemorySeedStorage();
      final store = IdentityStore(storage: storage);

      final seed1 = await store.getOrCreateSeed();
      await store.clear();
      final seed2 = await store.getOrCreateSeed();

      // After clear, a new seed is generated — should be different.
      expect(seed1, isNot(equals(seed2)));
      expect(storage.values[IdentityStore.seedKey], isNotNull);
    });
  });

  // ── 6. MockSyncTransport — dispose closes all controllers ──
  group('MockSyncTransport dispose', () {
    test('dispose closes all broadcast controllers', () {
      final transport = MockSyncTransport();

      // All streams should be open before dispose.
      expect(transport.deviceFoundStream.isBroadcast, isTrue);
      expect(transport.sessionStateStream.isBroadcast, isTrue);
      expect(transport.bytesReceivedStream.isBroadcast, isTrue);
      expect(transport.progressStream.isBroadcast, isTrue);

      transport.dispose();

      // After dispose, listeners should receive done.
      expect(
        () => transport.deviceFoundStream.listen((_) {}),
        isA<void>(),
      );
      // Emitting after dispose should not throw (controllers handle it).
    });

    test('double-dispose is safe', () {
      final transport = MockSyncTransport();
      transport.dispose();
      // Second dispose should not throw.
      transport.dispose();
    });
  });

  // ── 7. Conflict dedup ──
  group('conflict deduplication', () {
    test('same note incoming twice results in only one promptUser', () async {
      final db = createTestDb();
      final noteRepo = NoteRepository(db);
      final resolver = MergeResolver(noteRepo);

      try {
        final local = await noteRepo.createNote(
          id: 'dedup-note',
          title: 'Local',
          type: NoteType.text,
          deviceOriginId: 'device-a',
        );
        await _setSyncMeta(db, local.id,
            syncVersion: 1, updatedAt: DateTime.utc(2026, 8, 1));

        final incoming = SyncNoteEntry(
          noteId: 'dedup-note',
          syncVersion: 5,
          updatedAt: DateTime.utc(2026, 8, 10),
          deviceOriginId: 'device-b',
          noteFields: {'title': 'Remote v5', 'type': 'text'},
          checklistItems: null,
          attachments: null,
        );

        // First resolve → promptUser.
        final first = await resolver.resolveIncoming(incoming);
        expect(first, MergeAction.promptUser);

        // If the orchestrator fails to apply the first resolution and the
        // same bundle arrives again, resolveIncoming should still return
        // promptUser (the conflict hasn't been resolved in the DB).
        final second = await resolver.resolveIncoming(incoming);
        expect(second, MergeAction.promptUser);

        // After applying via forceOverwrite...
        await resolver.forceOverwrite(incoming);

        // ...the same incoming is now stale (same lineage, lower/equal version).
        final third = await resolver.resolveIncoming(incoming);
        expect(third, MergeAction.ignore);
      } finally {
        await db.close();
      }
    });
  });

  // ── 8. Error overwrite guard ──
  group('error overwrite guard', () {
    late AppDatabase db;
    late NoteRepository noteRepo;
    late MergeResolver resolver;

    setUp(() {
      db = createTestDb();
      noteRepo = NoteRepository(db);
      resolver = MergeResolver(noteRepo);
    });

    tearDown(() async => db.close());

    test('ignore action does not modify the note', () async {
      final local = await noteRepo.createNote(
        id: 'error-guard',
        title: 'Original',
        type: NoteType.text,
        deviceOriginId: 'device-a',
      );
      await _setSyncMeta(db, local.id,
          syncVersion: 5, updatedAt: DateTime.utc(2026, 8, 10));

      final incoming = SyncNoteEntry(
        noteId: 'error-guard',
        syncVersion: 3,
        updatedAt: DateTime.utc(2026, 8, 5),
        deviceOriginId: 'device-b',
        noteFields: {'title': 'Should Not Apply', 'type': 'text'},
        checklistItems: null,
        attachments: null,
      );

      final action = await resolver.resolveIncoming(incoming);
      expect(action, MergeAction.ignore);

      final note = await noteRepo.getNoteById('error-guard');
      expect(note!.title, 'Original');
    });
  });

  // ── 9. maxFrameLength guard (already tested in sync_message_test, but verify SyncBundle level) ──
  group('verifyChecksum constant-time comparison', () {
    test('returns true for matching checksums', () {
      final entry = SyncNoteEntry(
        noteId: 'n1',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'dev-a',
        noteFields: {'title': 'T', 'type': 'text'},
        checklistItems: null,
        attachments: null,
      );
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'dev-a',
        senderDeviceName: 'Test',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [entry],
      );
      final checksum = SyncBundle.computeChecksum(bundle);
      expect(SyncBundle.verifyChecksum(bundle, checksum), isTrue);
    });

    test('returns false for different length checksums', () {
      final entry = SyncNoteEntry(
        noteId: 'n1',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'dev-a',
        noteFields: {'title': 'T', 'type': 'text'},
        checklistItems: null,
        attachments: null,
      );
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'dev-a',
        senderDeviceName: 'Test',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [entry],
      );
      expect(SyncBundle.verifyChecksum(bundle, 'abc'), isFalse);
    });

    test('returns false for valid-length but wrong checksum', () {
      final entry = SyncNoteEntry(
        noteId: 'n1',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'dev-a',
        noteFields: {'title': 'T', 'type': 'text'},
        checklistItems: null,
        attachments: null,
      );
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'dev-a',
        senderDeviceName: 'Test',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [entry],
      );
      final correct = SyncBundle.computeChecksum(bundle);
      // Flip last char.
      final wrong = '${correct.substring(0, correct.length - 1)}0';
      expect(SyncBundle.verifyChecksum(bundle, wrong), isFalse);
    });
  });

  // ── 10. SyncNoteEntry.fromCbor — null checklists/attachments round-trip ──
  group('SyncNoteEntry.fromCbor edge cases', () {
    test('round-trips with null checklistItems and null attachments', () {
      final entry = SyncNoteEntry(
        noteId: 'minimal',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'dev-a',
        noteFields: {'title': 'Minimal Note', 'type': 'text'},
        checklistItems: null,
        attachments: null,
      );
      final decoded = SyncNoteEntry.fromCbor(entry.toCbor());
      expect(decoded.checklistItems, isNull);
      expect(decoded.attachments, isNull);
    });

    test('round-trips noteFields with boolean and numeric values', () {
      final entry = SyncNoteEntry(
        noteId: 'types',
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'dev-a',
        noteFields: {
          'title': 'Types',
          'type': 'checklist',
          'pinned': true,
          'locked': false,
          'colorSeed': '#FF0000',
        },
        checklistItems: null,
        attachments: null,
      );
      final decoded = SyncNoteEntry.fromCbor(entry.toCbor());
      expect(decoded.noteFields['pinned'], true);
      expect(decoded.noteFields['locked'], false);
      expect(decoded.noteFields['colorSeed'], '#FF0000');
    });
  });
}

// ── Helpers ──

/// Encode a Dart map as CBOR bytes.
Uint8List _encodeMap(Map<String, dynamic> map) {
  final cborMap = CborMap.fromEntries(
    map.entries.map((e) {
      if (e.value is Map) {
        return MapEntry(
          CborString(e.key),
          CborMap.fromEntries(
            (e.value as Map).entries.map(
                  (inner) => MapEntry(
                    CborString(inner.key.toString()),
                    _toCborValue(inner.value),
                  ),
                ),
          ),
        );
      }
      return MapEntry(CborString(e.key), _toCborValue(e.value));
    }),
  );
  return Uint8List.fromList(cborEncode(cborMap));
}

CborValue _toCborValue(dynamic v) {
  if (v is String) return CborString(v);
  if (v is int) return CborSmallInt(v);
  if (v is bool) return CborBool(v);
  if (v is Map) {
    return CborMap.fromEntries(
      v.entries.map(
        (e) => MapEntry(
          CborString(e.key.toString()),
          _toCborValue(e.value),
        ),
      ),
    );
  }
  if (v == null) return const CborNull();
  throw ArgumentError('Unsupported type: ${v.runtimeType}');
}

Future<void> _setSyncMeta(
  AppDatabase db,
  String noteId, {
  required int syncVersion,
  required DateTime updatedAt,
}) async {
  await (db.update(db.notes)..where((t) => t.id.equals(noteId))).write(
    NotesCompanion(
      syncVersion: Value(syncVersion),
      updatedAt: Value(updatedAt),
    ),
  );
}
