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
  });
}
