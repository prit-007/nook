import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/bulk_export.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late NoteRepository noteRepo;
  late ChecklistItemRepository checklistRepo;
  late BulkExporter exporter;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nook-bulk-export');
    db = createTestDatabase();
    noteRepo = NoteRepository(db);
    checklistRepo = ChecklistItemRepository(db);
    exporter = BulkExporter(
      noteRepository: noteRepo,
      checklistItemRepository: checklistRepo,
      outputDirectory: tempDir,
      clock: () => DateTime(2026, 10, 4, 12, 30),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  group('renderNoteMarkdown / renderNoteHtml', () {
    test('markdown includes title, body, checklist', () async {
      final note = await noteRepo.createNote(
        title: 'Ship list',
        type: NoteType.checklist,
        deviceOriginId: 'd1',
        plainText: 'ignored for checklist type',
      );
      await checklistRepo.addItem(noteId: note.id, text: 'buy milk');
      await checklistRepo.toggleChecked(
        (await checklistRepo.getItems(note.id)).first.id,
      );

      final items = await checklistRepo.getItems(note.id);
      final md = renderNoteMarkdown(note, items);
      expect(md, contains('# Ship list'));
      expect(md, contains('- [x] buy milk'));
    });

    test('html escapes entities and includes checklist boxes', () async {
      final note = await noteRepo.createNote(
        title: 'A & B <draft>',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'x < y & z',
      );
      await checklistRepo.addItem(noteId: note.id, text: 'todo <now>');
      final items = await checklistRepo.getItems(note.id);
      final html = renderNoteHtml(note, items);
      expect(html, contains('A &amp; B &lt;draft&gt;'));
      expect(html, contains('x &lt; y &amp; z'));
      expect(html, contains('todo &lt;now&gt;'));
      expect(html, contains('☐'));
    });
  });

  group('BulkExporter', () {
    test('markdown export zips notes with manifest', () async {
      await noteRepo.createNote(
        title: 'Alpha',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'hello alpha',
      );
      await noteRepo.createNote(
        title: 'Beta',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'hello beta',
      );

      final path = await exporter.exportAll(BulkExportFormat.markdown);
      final bytes = await File(path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toSet();

      expect(names, contains('manifest.json'));
      expect(names.where((n) => n.startsWith('notes/') && n.endsWith('.md')),
          hasLength(2));
      expect(path, contains('nook-export-markdown-'));
    });

    test('html export produces .html note files', () async {
      await noteRepo.createNote(
        title: 'Alpha',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'hello',
      );

      final path = await exporter.exportAll(BulkExportFormat.html);
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final names = archive.files.map((f) => f.name).toSet();
      expect(names.where((n) => n.endsWith('.html')), hasLength(1));
      expect(path, contains('nook-export-html-'));
    });

    test('empty vault throws instead of silent empty zip', () async {
      expect(
        () => exporter.exportAll(BulkExportFormat.markdown),
        throwsStateError,
      );
    });

    test('exportNoteHtml writes standalone file', () async {
      final note = await noteRepo.createNote(
        title: 'Share me',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'body text',
      );
      final path = await exporter.exportNoteHtml(note);
      final html = await File(path).readAsString();
      expect(html, contains('Share me'));
      expect(html, contains('body text'));
      expect(path, endsWith('.html'));
    });

    test('soft-deleted notes are excluded', () async {
      final live = await noteRepo.createNote(
        title: 'Live',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'keep',
      );
      final doomed = await noteRepo.createNote(
        title: 'Doomed',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'gone',
      );
      await noteRepo.softDelete(doomed.id);

      final path = await exporter.exportAll(BulkExportFormat.markdown);
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final names = archive.files.map((f) => f.name).toList();
      expect(names.where((n) => n.contains('Live')), isNotEmpty);
      expect(names.where((n) => n.contains('Doomed')), isEmpty);
      expect(live.id, isNotEmpty);
    });
  });
}
