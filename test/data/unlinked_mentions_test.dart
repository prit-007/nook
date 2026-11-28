import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  group('Unlinked mentions (Phase 5)', () {
    test('finds live notes mentioning target title without existing link',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final linkRepo = NoteLinkRepository(db);

      final target = await noteRepo.createNote(
        id: 'target-1',
        title: 'Project Atlas',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );

      await noteRepo.createNote(
        id: 'unlinked-1',
        title: 'Meeting Notes',
        plainText: 'Discussed Project Atlas milestones today.',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );

      final linked = await noteRepo.createNote(
        id: 'linked-1',
        title: 'Linked Summary',
        plainText: 'See Project Atlas for details.',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.updateContent(
        linked.id,
        deltaContent: jsonEncode({
          'document': {
            'children': [
              {
                'type': 'paragraph',
                'data': {
                  'delta': [
                    {
                      'insert': 'Project Atlas',
                      'attributes': {'href': 'nook://note/${target.id}'},
                    },
                  ],
                },
              },
            ],
          },
        }),
        plainText: 'See Project Atlas for details.',
      );

      final mentions = await linkRepo.findUnlinkedMentions(target.id);
      expect(mentions.map((n) => n.id), equals(['unlinked-1']));
    });
  });
}
