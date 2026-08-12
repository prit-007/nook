import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late MergeResolver resolver;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    resolver = MergeResolver(noteRepo);
  });

  tearDown(() async {
    await db.close();
  });

  /// Directly set syncVersion and updatedAt on a note via Drift's update API.
  Future<void> setSyncMeta(
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

  group('MergeResolver', () {
    group('insertAsNew', () {
      test('note does not exist locally → insertAsNew', () async {
        final incoming = SyncNoteEntry(
          noteId: 'remote-note-1',
          syncVersion: 1,
          updatedAt: DateTime.utc(2026, 8, 11),
          deviceOriginId: 'device-b',
          noteFields: {
            'title': 'Remote Note',
            'type': 'text',
          },
          checklistItems: null,
          attachmentBytes: null,
        );

        final action = await resolver.resolveIncoming(incoming);
        expect(action, MergeAction.insertAsNew);
      });
    });

    group('ignore', () {
      test(
        'incoming is older or same version AND older updatedAt → ignore',
        () async {
          final local = await noteRepo.createNote(
            title: 'Local Version',
            type: NoteType.text,
            deviceOriginId: 'device-a',
          );

          await setSyncMeta(
            local.id,
            syncVersion: 5,
            updatedAt: DateTime.utc(2026, 8, 12),
          );

          final incoming = SyncNoteEntry(
            noteId: local.id,
            syncVersion: 3,
            updatedAt: DateTime.utc(2026, 8, 10),
            deviceOriginId: 'device-b',
            noteFields: {
              'title': 'Stale Remote Version',
              'type': 'text',
            },
            checklistItems: null,
            attachmentBytes: null,
          );

          final action = await resolver.resolveIncoming(incoming);
          expect(action, MergeAction.ignore);
        },
      );

      test(
        'incoming is same version AND same or older updatedAt → ignore',
        () async {
          final local = await noteRepo.createNote(
            title: 'Same Version',
            type: NoteType.text,
            deviceOriginId: 'device-a',
          );

          await setSyncMeta(
            local.id,
            syncVersion: 3,
            updatedAt: DateTime.utc(2026, 8, 12),
          );

          final incoming = SyncNoteEntry(
            noteId: local.id,
            syncVersion: 3,
            updatedAt: DateTime.utc(2026, 8, 11),
            deviceOriginId: 'device-b',
            noteFields: {
              'title': 'Same Version Remote',
              'type': 'text',
            },
            checklistItems: null,
            attachmentBytes: null,
          );

          final action = await resolver.resolveIncoming(incoming);
          expect(action, MergeAction.ignore);
        },
      );
    });

    group('overwrite', () {
      test(
        'same deviceOriginId AND incoming is newer → overwrite',
        () async {
          final local = await noteRepo.createNote(
            title: 'Older Local',
            type: NoteType.text,
            deviceOriginId: 'device-a',
          );

          await setSyncMeta(
            local.id,
            syncVersion: 2,
            updatedAt: DateTime.utc(2026, 8, 10),
          );

          final incoming = SyncNoteEntry(
            noteId: local.id,
            syncVersion: 5,
            updatedAt: DateTime.utc(2026, 8, 12),
            deviceOriginId: 'device-a',
            noteFields: {
              'title': 'Newer Version Same Device',
              'type': 'text',
            },
            checklistItems: null,
            attachmentBytes: null,
          );

          final action = await resolver.resolveIncoming(incoming);
          expect(action, MergeAction.overwrite);
        },
      );
    });

    group('promptUser', () {
      test(
        'different deviceOriginId AND incoming is newer → promptUser',
        () async {
          final local = await noteRepo.createNote(
            title: 'Edited Locally',
            type: NoteType.text,
            deviceOriginId: 'device-a',
          );

          await setSyncMeta(
            local.id,
            syncVersion: 2,
            updatedAt: DateTime.utc(2026, 8, 10),
          );

          final incoming = SyncNoteEntry(
            noteId: local.id,
            syncVersion: 5,
            updatedAt: DateTime.utc(2026, 8, 12),
            deviceOriginId: 'device-b',
            noteFields: {
              'title': 'Edited Remotely',
              'type': 'text',
            },
            checklistItems: null,
            attachmentBytes: null,
          );

          final action = await resolver.resolveIncoming(incoming);
          expect(action, MergeAction.promptUser);
        },
      );

      test(
        'different deviceOriginId AND same version but newer updatedAt → promptUser',
        () async {
          final local = await noteRepo.createNote(
            title: 'Edited Locally',
            type: NoteType.text,
            deviceOriginId: 'device-a',
          );

          await setSyncMeta(
            local.id,
            syncVersion: 3,
            updatedAt: DateTime.utc(2026, 8, 10),
          );

          final incoming = SyncNoteEntry(
            noteId: local.id,
            syncVersion: 3,
            updatedAt: DateTime.utc(2026, 8, 12),
            deviceOriginId: 'device-b',
            noteFields: {
              'title': 'Edited Remotely Same Version',
              'type': 'text',
            },
            checklistItems: null,
            attachmentBytes: null,
          );

          final action = await resolver.resolveIncoming(incoming);
          expect(action, MergeAction.promptUser);
        },
      );
    });

    group('edge cases', () {
      test('soft-deleted note still exists in DB → merge logic applies',
          () async {
        final local = await noteRepo.createNote(
          title: 'Deleted Note',
          type: NoteType.text,
          deviceOriginId: 'device-a',
        );
        await noteRepo.softDelete(local.id);

        final incoming = SyncNoteEntry(
          noteId: local.id,
          syncVersion: 1,
          updatedAt: DateTime.utc(2026, 8, 11),
          deviceOriginId: 'device-b',
          noteFields: {
            'title': 'Restored From Remote',
            'type': 'text',
          },
          checklistItems: null,
          attachmentBytes: null,
        );

        final action = await resolver.resolveIncoming(incoming);
        expect(action, MergeAction.promptUser);
      });
    });
  });

  group('applyIncoming', () {
    test('insertAsNew creates the note in the database', () async {
      final incoming = SyncNoteEntry(
        noteId: 'remote-note-new',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'device-b',
        noteFields: {
          'title': 'New From Remote',
          'type': 'text',
          'colorSeed': '#6750A4',
        },
        checklistItems: null,
        attachmentBytes: null,
      );

      final result = await resolver.applyIncoming(incoming);
      expect(result, MergeAction.insertAsNew);

      final allNotes = await noteRepo.getAllNotes();
      expect(allNotes.length, 1);
      expect(allNotes.first.title, 'New From Remote');
      expect(allNotes.first.deviceOriginId, 'device-b');
      expect(allNotes.first.colorSeed, '#6750A4');
    });

    test('insertAsNew preserves remote noteId', () async {
      final incoming = SyncNoteEntry(
        noteId: 'remote-preserved-id',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'device-b',
        noteFields: {
          'title': 'Preserve My ID',
          'type': 'text',
        },
        checklistItems: null,
        attachmentBytes: null,
      );

      await resolver.applyIncoming(incoming);

      final note = await noteRepo.getNoteById('remote-preserved-id');
      expect(note, isNotNull);
      expect(note!.title, 'Preserve My ID');
    });

    test('overwrite updates the local note with remote data', () async {
      final local = await noteRepo.createNote(
        title: 'Old Title',
        type: NoteType.text,
        deviceOriginId: 'device-a',
      );

      await setSyncMeta(
        local.id,
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 8, 10),
      );

      final incoming = SyncNoteEntry(
        noteId: local.id,
        syncVersion: 5,
        updatedAt: DateTime.utc(2026, 8, 12),
        deviceOriginId: 'device-a',
        noteFields: {
          'title': 'Updated Title',
          'type': 'text',
        },
        checklistItems: null,
        attachmentBytes: null,
      );

      final result = await resolver.applyIncoming(incoming);
      expect(result, MergeAction.overwrite);

      final note = await noteRepo.getNoteById(local.id);
      expect(note!.title, 'Updated Title');
      expect(note.syncVersion, 5);
    });
  });

  group('forceOverwrite', () {
    test('overwrites local even with different deviceOriginId', () async {
      final local = await noteRepo.createNote(
        title: 'Local Version',
        type: NoteType.text,
        deviceOriginId: 'device-a',
      );

      await setSyncMeta(
        local.id,
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 8, 10),
      );

      final incoming = SyncNoteEntry(
        noteId: local.id,
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 9),
        deviceOriginId: 'device-b',
        noteFields: {
          'title': 'Force Overwritten',
          'type': 'text',
        },
        checklistItems: null,
        attachmentBytes: null,
      );

      final result = await resolver.forceOverwrite(incoming);
      expect(result, MergeAction.overwrite);

      final note = await noteRepo.getNoteById(local.id);
      expect(note!.title, 'Force Overwritten');
    });
  });

  group('public insertAsNew', () {
    test('inserts note with new ID when local with same ID exists', () async {
      await noteRepo.createNote(
        id: 'shared-id',
        title: 'Local Version',
        type: NoteType.text,
        deviceOriginId: 'device-a',
      );

      final incoming = SyncNoteEntry(
        noteId: 'shared-id',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'device-b',
        noteFields: {
          'title': 'Remote Version',
          'type': 'text',
        },
        checklistItems: null,
        attachmentBytes: null,
      );

      final result = await resolver.insertAsNew(incoming);
      expect(result, MergeAction.insertAsNew);

      final allNotes = await noteRepo.getAllNotes();
      expect(allNotes.length, 2);

      final localNote = await noteRepo.getNoteById('shared-id');
      expect(localNote!.title, 'Local Version');

      final remoteNote =
          allNotes.firstWhere((n) => n.id != 'shared-id');
      expect(remoteNote.title, 'Remote Version');
      expect(remoteNote.deviceOriginId, 'device-b');
    });
  });
}
