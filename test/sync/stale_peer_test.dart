import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

void main() {
  group('Stale peer tombstone non-resurrection', () {
    test('soft-deleted & purged on Peer A is not resurrected by stale Peer B',
        () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final dbA = AppDatabase(NativeDatabase.memory());
      final dbB = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await dbA.close();
        await dbB.close();
      });

      final repoA = NoteRepository(dbA);
      final repoB = NoteRepository(dbB);
      final resolverA = MergeResolver(repoA, NotebookRepository(dbA));

      // Peer A creates a note and Peer B receives it.
      final created = await repoA.createNote(
        id: 'stale-note-1',
        title: 'Shared Note',
        type: NoteType.text,
        deviceOriginId: 'peer-a',
      );
      await repoB.createNote(
        id: created.id,
        title: 'Shared Note',
        type: NoteType.text,
        deviceOriginId: 'peer-a',
      );

      // Peer A soft-deletes the note (tombstone).
      await repoA.softDelete(created.id);

      // Peer B sends a stale bundle with higher syncVersion & later timestamp.
      final staleIncoming = SyncNoteEntry(
        noteId: created.id,
        syncVersion: 10,
        updatedAt: DateTime.utc(2026, 12, 31),
        deviceOriginId: 'peer-a',
        noteFields: const {
          'title': 'Stale Title',
          'type': 'text',
          'deleted': false,
        },
      );

      final action = await resolverA.applyIncoming(staleIncoming);
      expect(action, MergeAction.ignore);

      final storedA = await repoA.getNoteById(created.id);
      expect(storedA?.deleted, isTrue);
    });

    test('incoming tombstone propagates deletion to live peer', () async {
      final dbB = AppDatabase(NativeDatabase.memory());
      addTearDown(dbB.close);

      final repoB = NoteRepository(dbB);
      final resolverB = MergeResolver(repoB, NotebookRepository(dbB));

      await repoB.createNote(
        id: 'stale-note-2',
        title: 'Live on B',
        type: NoteType.text,
        deviceOriginId: 'peer-a',
      );

      final tombstoneIncoming = SyncNoteEntry(
        noteId: 'stale-note-2',
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 12, 1),
        deviceOriginId: 'peer-a',
        noteFields: {
          'title': 'Live on B',
          'type': 'text',
          'deleted': true,
          'deletedAt': DateTime.utc(2026, 12, 1).toIso8601String(),
        },
      );

      await resolverB.applyIncoming(tombstoneIncoming);
      final storedB = await repoB.getNoteById('stale-note-2');
      expect(storedB?.deleted, isTrue);
    });
  });
}
