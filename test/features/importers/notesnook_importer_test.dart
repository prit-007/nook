import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/importers/notesnook_importer.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;
  late NotesnookImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
    importer = NotesnookImporter(repo);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotesnookImporter', () {
    test('imports notes from Notesnook JSON backup object', () async {
      final backup = jsonEncode({
        'notes': [
          {
            'title': 'Design Document',
            'content': '# Overview\nArchitecture notes.',
            'favorite': true,
            'createdAt': '2026-01-15T10:00:00Z',
          },
          {
            'title': 'Todo List',
            'content': '- [ ] First task\n- [x] Done task',
            'createdAt': '2026-01-16T10:00:00Z',
          }
        ]
      });

      final summary = await importer.importJson(backup);
      expect(summary.isSuccessful, isTrue);
      expect(summary.notesImported, 2);

      final notes = await repo.getAllNotes();
      expect(notes.length, 2);

      final doc = notes.firstWhere((n) => n.title == 'Design Document');
      expect(doc.type, NoteType.text);
      expect(doc.plainText, contains('Overview'));

      final todos = notes.firstWhere((n) => n.title == 'Todo List');
      expect(todos.type, NoteType.checklist);
      expect(todos.plainText, contains('First task'));
    });

    test('imports top-level list of notes', () async {
      final list = jsonEncode([
        {'title': 'Quick Thought', 'content': 'Just a quick thought.'}
      ]);

      final summary = await importer.importJson(list);
      expect(summary.notesImported, 1);

      final notes = await repo.getAllNotes();
      expect(notes.first.title, 'Quick Thought');
    });
  });
}
