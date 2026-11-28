import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/importers/plain_text_importer.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;
  late PlainTextImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
    importer = PlainTextImporter(repo);
  });

  tearDown(() async {
    await db.close();
  });

  group('PlainTextImporter', () {
    test('imports single text note and derives title from first line',
        () async {
      const text = '''Weekly Meeting Notes
- [ ] Discuss sprint goals
- [x] Assign bug fixes''';

      final summary = await importer.importText(text);
      expect(summary.isSuccessful, isTrue);
      expect(summary.notesImported, 1);

      final notes = await repo.getAllNotes();
      expect(notes.length, 1);
      expect(notes.first.title, 'Weekly Meeting Notes');
      expect(notes.first.type, NoteType.checklist);
      expect(notes.first.plainText, contains('Discuss sprint goals'));
    });

    test('splits multi-note string by delimiter', () async {
      const multi = '''First Note Title
Some content here for note 1.
---
Second Note Title
Some other content for note 2.
---
Third Note Title
Final content.
''';

      final summary = await importer.importText(multi, delimiter: r'\n---\n');
      expect(summary.notesImported, 3);

      final notes = await repo.getAllNotes();
      expect(notes.length, 3);
      expect(
        notes.map((n) => n.title).toList(),
        unorderedEquals([
          'First Note Title',
          'Second Note Title',
          'Third Note Title',
        ]),
      );
    });

    test('imports list of files using filename as title', () async {
      final tempDir = await Directory.systemTemp.createTemp('plain_text_test_');
      final file1 = File('${tempDir.path}/Grocery.txt')
        ..writeAsStringSync('Apples\nBananas\nMilk');
      final file2 = File('${tempDir.path}/Ideas.txt')
        ..writeAsStringSync('Build a local-first note app.');

      final summary = await importer.importFiles([file1, file2]);
      expect(summary.notesImported, 2);
      expect(summary.filesProcessed, 2);

      final notes = await repo.getAllNotes();
      expect(notes.length, 2);
      expect(notes.any((n) => n.title == 'Grocery'), isTrue);
      expect(notes.any((n) => n.title == 'Ideas'), isTrue);

      await tempDir.delete(recursive: true);
    });
  });
}
