import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late NoteLinkRepository linkRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    linkRepo = NoteLinkRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  String deltaWithLinks(List<String> noteIds) {
    return jsonEncode({
      'document': {
        'children': [
          for (final id in noteIds)
            {
              'type': 'paragraph',
              'delta': [
                {'insert': 'See '},
                {
                  'insert': 'this note',
                  'attributes': {'href': noteLinkUri(id)},
                },
              ],
            },
        ],
      },
    });
  }

  group('extractNoteLinkIds / parseNoteLinkUri', () {
    test('parses nook://note/<id>', () {
      expect(parseNoteLinkUri('nook://note/abc-123'), 'abc-123');
      expect(parseNoteLinkUri('https://example.com'), isNull);
      expect(parseNoteLinkUri('nook://note/'), isNull);
    });

    test('extracts ids from AppFlowy-like JSON', () {
      final ids = extractNoteLinkIds(deltaWithLinks(['n1', 'n2']));
      expect(ids, {'n1', 'n2'});
    });

    test('returns empty for null/invalid JSON', () {
      expect(extractNoteLinkIds(null), isEmpty);
      expect(extractNoteLinkIds('not-json'), isEmpty);
    });
  });

  group('NoteLinkRepository', () {
    test('rebuildForNote creates outgoing links from delta hrefs', () async {
      final a = await noteRepo.createNote(
        title: 'A',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final b = await noteRepo.createNote(
        title: 'B',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await noteRepo.updateContent(
        a.id,
        deltaContent: deltaWithLinks([b.id]),
        plainText: 'See this note',
      );

      final outgoing = await linkRepo.outgoingFrom(a.id);
      expect(outgoing, hasLength(1));
      expect(outgoing.single.linkedNoteId, b.id);
      expect(outgoing.single.linkedTitle, 'B');

      final incoming = await linkRepo.incomingTo(b.id);
      expect(incoming, hasLength(1));
      expect(incoming.single.noteId, a.id);
    });

    test('removing hrefs clears the link cache', () async {
      final a = await noteRepo.createNote(
        title: 'A',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final b = await noteRepo.createNote(
        title: 'B',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await noteRepo.updateContent(
        a.id,
        deltaContent: deltaWithLinks([b.id]),
        plainText: 'linked',
      );
      expect(await linkRepo.outgoingFrom(a.id), hasLength(1));

      await noteRepo.updateContent(
        a.id,
        deltaContent: deltaWithLinks([]),
        plainText: 'unlinked',
      );
      expect(await linkRepo.outgoingFrom(a.id), isEmpty);
      expect(await linkRepo.incomingTo(b.id), isEmpty);
    });

    test('self-links are ignored', () async {
      final a = await noteRepo.createNote(
        title: 'A',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await noteRepo.updateContent(
        a.id,
        deltaContent: deltaWithLinks([a.id]),
        plainText: 'self',
      );
      expect(await linkRepo.outgoingFrom(a.id), isEmpty);
    });

    test('sync receive path (updateContent) rebuilds links', () async {
      final a = await noteRepo.createNote(
        title: 'A',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      final b = await noteRepo.createNote(
        title: 'B',
        type: NoteType.text,
        deviceOriginId: 'remote',
      );
      // Simulate merge/sync writing content.
      await noteRepo.updateContent(
        a.id,
        deltaContent: deltaWithLinks([b.id]),
        plainText: 'from sync',
        updatedAt: DateTime.now(),
      );
      expect(await linkRepo.incomingTo(b.id), hasLength(1));
    });

    test('picker search returns live notes by title', () async {
      await noteRepo.createNote(
        title: 'Passport renewal',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final results = await linkRepo.searchNotesForLinkPicker('passport');
      expect(results.single.title, 'Passport renewal');
    });

    test('schemaVersion is 5', () {
      expect(db.schemaVersion, 5);
    });
  });
}
