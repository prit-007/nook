import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late TagRepository tagRepo;
  late NoteRepository noteRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tagRepo = TagRepository(db);
    noteRepo = NoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TagRepository', () {
    test('createTag inserts and returns a tag', () async {
      final tag = await tagRepo.createTag(
        name: 'important',
        colorSeed: '#F44336',
      );

      expect(tag.name, 'important');
      expect(tag.colorSeed, '#F44336');
      expect(tag.id, isNotEmpty);
    });

    test('getAllTags returns all tags', () async {
      await tagRepo.createTag(name: 'work', colorSeed: '#2196F3');
      await tagRepo.createTag(name: 'personal', colorSeed: '#4CAF50');

      final all = await tagRepo.getAllTags();
      expect(all.length, 2);
    });

    test('getTagById returns the correct tag', () async {
      final created = await tagRepo.createTag(
        name: 'find-me',
        colorSeed: '#9C27B0',
      );

      final found = await tagRepo.getTagById(created.id);
      expect(found, isNotNull);
      expect(found!.name, 'find-me');
    });

    test('getTagById returns null for nonexistent id', () async {
      final found = await tagRepo.getTagById('nonexistent');
      expect(found, isNull);
    });

    test('updateTag modifies name and colorSeed', () async {
      final tag = await tagRepo.createTag(
        name: 'old-name',
        colorSeed: '#000',
      );

      await tagRepo.updateTag(
        tag.id,
        name: 'new-name',
        colorSeed: '#FFF',
      );

      final updated = await tagRepo.getTagById(tag.id);
      expect(updated!.name, 'new-name');
      expect(updated.colorSeed, '#FFF');
    });

    test('deleteTag removes the tag', () async {
      final tag = await tagRepo.createTag(
        name: 'delete-me',
        colorSeed: '#123',
      );

      await tagRepo.deleteTag(tag.id);

      final found = await tagRepo.getTagById(tag.id);
      expect(found, isNull);
    });

    test('assignTagToNote creates the association', () async {
      final tag = await tagRepo.createTag(
        name: 'tagged',
        colorSeed: '#ABC',
      );
      final note = await noteRepo.createNote(
        title: 'Tagged Note',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await tagRepo.assignTagToNote(note.id, tag.id);

      final tags = await tagRepo.getTagsForNote(note.id);
      expect(tags.length, 1);
      expect(tags.first.name, 'tagged');
    });

    test('removeTagFromNote removes the association', () async {
      final tag = await tagRepo.createTag(
        name: 'removable',
        colorSeed: '#DEF',
      );
      final note = await noteRepo.createNote(
        title: 'Un-tag Me',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await tagRepo.assignTagToNote(note.id, tag.id);
      await tagRepo.removeTagFromNote(note.id, tag.id);

      final tags = await tagRepo.getTagsForNote(note.id);
      expect(tags, isEmpty);
    });

    test('getNotesForTag returns correct notes', () async {
      final tag = await tagRepo.createTag(
        name: 'shared',
        colorSeed: '#111',
      );
      final note1 = await noteRepo.createNote(
        title: 'Note A',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      final note2 = await noteRepo.createNote(
        title: 'Note B',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await tagRepo.assignTagToNote(note1.id, tag.id);
      await tagRepo.assignTagToNote(note2.id, tag.id);

      final notes = await tagRepo.getNotesForTag(tag.id);
      expect(notes.length, 2);
    });

    test('getTagsForNote returns multiple tags', () async {
      final tag1 = await tagRepo.createTag(
        name: 'tag-a',
        colorSeed: '#AAA',
      );
      final tag2 = await tagRepo.createTag(
        name: 'tag-b',
        colorSeed: '#BBB',
      );
      final note = await noteRepo.createNote(
        title: 'Multi-tagged',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await tagRepo.assignTagToNote(note.id, tag1.id);
      await tagRepo.assignTagToNote(note.id, tag2.id);

      final tags = await tagRepo.getTagsForNote(note.id);
      expect(tags.length, 2);
    });

    test('softDelete marks tag as deleted', () async {
      final tag = await tagRepo.createTag(
        name: 'soft-delete-me',
        colorSeed: '#FF0000',
      );

      await tagRepo.softDelete(tag.id);

      final all = await tagRepo.getAllTags();
      expect(all, isEmpty);

      final deleted = await tagRepo.getDeletedTags();
      expect(deleted, hasLength(1));
      expect(deleted.first.id, tag.id);
      expect(deleted.first.deleted, true);
      expect(deleted.first.deletedAt, isNotNull);
    });

    test('restore brings tag back from soft-delete', () async {
      final tag = await tagRepo.createTag(
        name: 'restored-tag',
        colorSeed: '#00FF00',
      );

      await tagRepo.softDelete(tag.id);
      expect(await tagRepo.getAllTags(), isEmpty);

      await tagRepo.restore(tag.id);

      final all = await tagRepo.getAllTags();
      expect(all, hasLength(1));
      expect(all.first.id, tag.id);
      expect(all.first.deleted, false);
      expect(all.first.deletedAt, isNull);
    });

    test('softDelete preserves NoteTags associations', () async {
      final tag = await tagRepo.createTag(
        name: 'associated',
        colorSeed: '#0000FF',
      );
      final note = await noteRepo.createNote(
        title: 'Note With Tag',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await tagRepo.assignTagToNote(note.id, tag.id);
      await tagRepo.softDelete(tag.id);

      // NoteTags row should still exist
      final noteTags = await (db.select(db.noteTags)
            ..where((t) => t.tagId.equals(tag.id)))
          .get();
      expect(noteTags, hasLength(1));
    });

    test('getAllTags excludes soft-deleted tags', () async {
      await tagRepo.createTag(name: 'active-tag', colorSeed: '#111');
      final tag2 = await tagRepo.createTag(
        name: 'deleted-tag',
        colorSeed: '#222',
      );
      await tagRepo.softDelete(tag2.id);

      final all = await tagRepo.getAllTags();
      expect(all, hasLength(1));
      expect(all.first.name, 'active-tag');
    });

    test('getDeletedTags returns most recently deleted first', () async {
      final tag1 = await tagRepo.createTag(
        name: 'first',
        colorSeed: '#AAA',
      );
      final tag2 = await tagRepo.createTag(
        name: 'second',
        colorSeed: '#BBB',
      );

      // Use direct DB updates with explicit timestamps to guarantee ordering.
      final t1 = DateTime(2025, 1, 1, 10, 0, 0);
      final t2 = DateTime(2025, 1, 1, 12, 0, 0);
      await (db.update(db.tags)..where((t) => t.id.equals(tag1.id))).write(
        TagsCompanion(
          deleted: const Value(true),
          deletedAt: Value(t1),
        ),
      );
      await (db.update(db.tags)..where((t) => t.id.equals(tag2.id))).write(
        TagsCompanion(
          deleted: const Value(true),
          deletedAt: Value(t2),
        ),
      );

      final deleted = await tagRepo.getDeletedTags();
      expect(deleted.length, 2);
      expect(deleted.first.id, tag2.id);
      expect(deleted.last.id, tag1.id);
    });

    test('permanentlyDelete removes tag and associations from DB', () async {
      final tag = await tagRepo.createTag(
        name: 'to-destroy',
        colorSeed: '#FF0000',
      );
      final note = await noteRepo.createNote(
        title: 'Note',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await tagRepo.assignTagToNote(note.id, tag.id);
      await tagRepo.softDelete(tag.id);

      await tagRepo.permanentlyDelete(tag.id);

      final deleted = await tagRepo.getDeletedTags();
      expect(deleted, isEmpty);
      final byId = await tagRepo.getTagById(tag.id);
      expect(byId, isNull);
      // NoteTags should also be removed.
      final noteTags = await (db.select(db.noteTags)
            ..where((t) => t.tagId.equals(tag.id)))
          .get();
      expect(noteTags, isEmpty);
    });

    test('permanentlyDeleteAllDeleted removes all soft-deleted tags', () async {
      await tagRepo.createTag(name: 'keep', colorSeed: '#111');
      final tag1 = await tagRepo.createTag(name: 'gone1', colorSeed: '#222');
      final tag2 = await tagRepo.createTag(name: 'gone2', colorSeed: '#333');
      await tagRepo.softDelete(tag1.id);
      await tagRepo.softDelete(tag2.id);

      await tagRepo.permanentlyDeleteAllDeleted();

      final remaining = await tagRepo.getAllTags();
      expect(remaining, hasLength(1));
      expect(remaining.first.name, 'keep');
      final deleted = await tagRepo.getDeletedTags();
      expect(deleted, isEmpty);
    });
  });
}
