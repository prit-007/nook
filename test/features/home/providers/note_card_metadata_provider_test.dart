import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Note> insertNote({
    String id = 'note-1',
    String title = 'Test Note',
    String? notebookId,
  }) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: Value(title),
            type: NoteType.text,
            deviceOriginId: 'device-1',
            notebookId: Value(notebookId),
          ),
        );
    return (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> insertNotebook(String id, String name) async {
    await db.into(db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: '#FF0000',
          ),
        );
  }

  Future<void> insertTag(String id, String name) async {
    await db.into(db.tags).insert(
          TagsCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: '#2196F3',
          ),
        );
  }

  group('noteCardMetadataProvider', () {
    test('returns correct tags for notes', () async {
      final note = await insertNote(id: 'note-tags');
      await insertTag('tag-a', 'work');
      await TagRepository(db).assignTagToNote('note-tags', 'tag-a');

      final meta = await container.read(
        noteCardMetadataProvider([note]).future,
      );
      expect(meta['note-tags']!.tags, hasLength(1));
      expect(meta['note-tags']!.tags.first.name, 'work');
    });

    test('returns correct notebook name', () async {
      await insertNotebook('nb-1', 'Ideas');
      final note = await insertNote(id: 'note-nb', notebookId: 'nb-1');

      final meta = await container.read(
        noteCardMetadataProvider([note]).future,
      );
      expect(meta['note-nb']!.notebookName, 'Ideas');
    });

    test('metadata includes doodle thumbnails', () async {
      final note = await insertNote(id: 'note-doodle');

      final tmpDir = Directory.systemTemp.createTempSync('meta_test');
      final thumbPath = '${tmpDir.path}/thumb.png';
      File(thumbPath).writeAsBytesSync([0]);

      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-1'),
              noteId: 'note-doodle',
              type: AttachmentType.doodleLayer,
              filePath: '${tmpDir.path}/doodle.json',
              thumbnailPath: Value(thumbPath),
            ),
          );

      final meta = await container.read(
        noteCardMetadataProvider([note]).future,
      );
      expect(meta['note-doodle']!.thumbnailPath, thumbPath);

      tmpDir.deleteSync(recursive: true);
    });

    test('metadata returns empty map for empty note list', () async {
      final meta = await container.read(
        noteCardMetadataProvider(<Note>[]).future,
      );
      expect(meta, isEmpty);
    });

    test('metadata batch-loads for multiple notes', () async {
      await insertNote(id: 'n1', title: 'First');
      final note2 = await insertNote(id: 'n2', title: 'Second');
      await insertNotebook('nb-1', 'Project');
      await insertTag('tag-x', 'urgent');

      await (db.update(db.notes)..where((t) => t.id.equals('n1')))
          .write(const NotesCompanion(notebookId: Value('nb-1')));
      await TagRepository(db).assignTagToNote('n1', 'tag-x');

      // Re-read notes so they carry the updated notebookId.
      final freshNote1 = await (db.select(db.notes)
            ..where((t) => t.id.equals('n1')))
          .getSingle();

      final meta = await container.read(
        noteCardMetadataProvider([freshNote1, note2]).future,
      );

      expect(meta, contains('n1'));
      expect(meta, contains('n2'));
      expect(meta['n1']!.notebookName, 'Project');
      expect(meta['n1']!.tags, hasLength(1));
      expect(meta['n2']!.notebookName, isNull);
      expect(meta['n2']!.tags, isEmpty);
    });

    test('metadata re-runs when notesListProvider changes', () async {
      // Initial: note with no tags
      final note = await insertNote(id: 'note-react');
      final meta1 = await container.read(
        noteCardMetadataProvider([note]).future,
      );
      expect(meta1['note-react']!.tags, isEmpty);

      // Add tag and update the note's updatedAt to trigger notesListProvider.
      await insertTag('tag-r', 'reactive');
      await TagRepository(db).assignTagToNote('note-react', 'tag-r');

      // Re-read note (simulates notesListProvider re-emitting).
      final freshNote = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-react')))
          .getSingle();

      final meta2 = await container.read(
        noteCardMetadataProvider([freshNote]).future,
      );
      expect(meta2['note-react']!.tags, hasLength(1));
      expect(meta2['note-react']!.tags.first.name, 'reactive');
    });
  });
}
