import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/importers/keep_importer.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;
  late KeepImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
    importer = KeepImporter(repo);
  });

  tearDown(() async {
    await db.close();
  });

  group('KeepImporter', () {
    test('imports text note from Keep JSON', () async {
      final json = jsonEncode({
        'title': 'Project Roadmap',
        'textContent': 'Phase 1: Foundations\nPhase 2: Sync',
        'isPinned': true,
        'userEditedTimestampUsec': 1672531199000000,
      });

      final summary = await importer.importJson(json);
      expect(summary.isSuccessful, isTrue);
      expect(summary.notesImported, 1);

      final notes = await repo.getAllNotes();
      expect(notes.length, 1);
      final note = notes.first;
      expect(note.title, 'Project Roadmap');
      expect(note.type, NoteType.text);
      expect(note.plainText, contains('Phase 1: Foundations'));
    });

    test('imports checklist note from Keep listContent', () async {
      final json = jsonEncode({
        'title': 'Weekly Shopping',
        'listContent': [
          {'text': 'Sourdough Bread', 'isChecked': true},
          {'text': 'Almond Milk', 'isChecked': false},
        ],
      });

      final summary = await importer.importJson(json);
      expect(summary.notesImported, 1);

      final notes = await repo.getAllNotes();
      expect(notes.length, 1);
      final note = notes.first;
      expect(note.title, 'Weekly Shopping');
      expect(note.type, NoteType.checklist);
      expect(note.plainText, contains('Sourdough Bread'));
      expect(note.plainText, contains('Almond Milk'));
    });

    test('skips trashed notes by default', () async {
      final json = jsonEncode([
        {'title': 'Active Note', 'textContent': 'Keep this'},
        {
          'title': 'Trashed Note',
          'textContent': 'Delete this',
          'isTrashed': true
        },
      ]);

      final summary = await importer.importJson(json);
      expect(summary.notesImported, 1);

      final notes = await repo.getAllNotes();
      expect(notes.length, 1);
      expect(notes.first.title, 'Active Note');
    });

    test('imports from Takeout zip archive', () async {
      final archive = Archive();
      final noteJson1 = utf8.encode(
          jsonEncode({'title': 'Takeout 1', 'textContent': 'Zip note 1'}));
      final noteJson2 = utf8.encode(
          jsonEncode({'title': 'Takeout 2', 'textContent': 'Zip note 2'}));

      archive.addFile(
          ArchiveFile('Takeout/Keep/note1.json', noteJson1.length, noteJson1));
      archive.addFile(
          ArchiveFile('Takeout/Keep/note2.json', noteJson2.length, noteJson2));

      final zipBytes = ZipEncoder().encode(archive)!;
      final summary = await importer.importZip(zipBytes);
      expect(summary.notesImported, 2);

      final notes = await repo.getAllNotes();
      expect(notes.length, 2);
    });
  });
}
