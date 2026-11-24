import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/importers/evernote_importer.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;
  late EvernoteImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
    importer = EvernoteImporter(repo);
  });

  tearDown(() async {
    await db.close();
  });

  group('EvernoteImporter', () {
    test('imports ENEX XML note with formatting and checkboxes', () async {
      const enex = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-export SYSTEM "http://xml.evernote.com/pub/evernote-export4.dtd">
<en-export export-date="20260201T120000Z">
  <note>
    <title>Meeting Agenda</title>
    <content>
      <![CDATA[<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/en-note.dtd">
      <en-note>
        <div><b>Important</b> discussion items:</div>
        <div><en-todo checked="false"/>Review pull requests</div>
        <div><en-todo checked="true"/>Deploy to staging</div>
      </en-note>]]>
    </content>
    <created>20260115T093000Z</created>
    <updated>20260115T114500Z</updated>
    <tag>Work</tag>
  </note>
</en-export>''';

      final summary = await importer.importEnex(enex);
      expect(summary.isSuccessful, isTrue);
      expect(summary.notesImported, 1);

      final notes = await repo.getAllNotes();
      expect(notes.length, 1);
      final note = notes.first;
      expect(note.title, 'Meeting Agenda');
      expect(note.type, NoteType.checklist);
      expect(note.plainText, contains('Review pull requests'));
      expect(note.plainText, contains('Deploy to staging'));
      expect(note.createdAt.toUtc(), DateTime.utc(2026, 1, 15, 9, 30));
    });

    test('imports plain ENEX note without checklists', () async {
      const enex = '''<?xml version="1.0" encoding="UTF-8"?>
<en-export>
  <note>
    <title>Architecture Decisions</title>
    <content>
      <![CDATA[
      <en-note>
        <div>We decided to use local SQLite with SQLCipher encryption.</div>
      </en-note>]]>
    </content>
  </note>
</en-export>''';

      final summary = await importer.importEnex(enex);
      expect(summary.notesImported, 1);

      final notes = await repo.getAllNotes();
      expect(notes.first.title, 'Architecture Decisions');
      expect(notes.first.type, NoteType.text);
      expect(notes.first.plainText, contains('local SQLite'));
    });
  });
}
