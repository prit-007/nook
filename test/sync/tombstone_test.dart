import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/pipeline/sync_bundle_packer.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

void main() {
  group('Tombstones & resumable chunking (Phase 2.5)', () {
    test('soft-deleted local note is never resurrected by incoming sync',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final resolver = MergeResolver(noteRepo, NotebookRepository(db));

      final note = await noteRepo.createNote(
        id: 'tombstone-note-1',
        title: 'Deleted on this device',
        type: NoteType.text,
        deviceOriginId: 'dev-a',
      );
      await noteRepo.softDelete(note.id);

      final incoming = SyncNoteEntry(
        noteId: note.id,
        syncVersion: 99,
        updatedAt: DateTime.utc(2026, 12, 31),
        deviceOriginId: 'dev-a',
        noteFields: const {'title': 'Resurrected?', 'type': 'text'},
      );

      final action = await resolver.applyIncoming(incoming);
      expect(action, MergeAction.ignore);

      final stored = await noteRepo.getNoteById(note.id);
      expect(stored!.deleted, isTrue);
    });

    test('chunkPayload and reassembleChunks support resume and verify SHA-256',
        () {
      final payload = Uint8List.fromList(
        List<int>.generate(2500, (i) => i % 251),
      );
      final chunks = SyncBundlePacker.chunkPayload(payload, chunkSize: 600);
      expect(chunks, hasLength(5));

      // Simulate out-of-order / resumed delivery.
      final resumed = [chunks[3], chunks[0], chunks[4], chunks[1], chunks[2]];
      final reassembled = SyncBundlePacker.reassembleChunks(resumed);
      expect(reassembled, equals(payload));

      // Tampering with a chunk fails SHA-256 verification.
      final tampered = PayloadChunk(
        index: chunks[2].index,
        totalChunks: chunks[2].totalChunks,
        data: Uint8List.fromList([0, 1, 2]),
        sha256Hex: chunks[2].sha256Hex,
      );
      expect(
        () => SyncBundlePacker.reassembleChunks(
          [chunks[0], chunks[1], tampered, chunks[3], chunks[4]],
        ),
        throwsFormatException,
      );
    });
  });
}
