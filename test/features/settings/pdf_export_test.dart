import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/bulk_export.dart';
import 'package:nook/features/settings/widgets/pdf_renderer.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('nook_pdf_test_');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('renderNotePdf generates valid PDF bytes for rich text and emojis',
      () async {
    final repo = NoteRepository(db);
    var note = await repo.createNote(
      title: 'Meeting Notes 📝',
      type: NoteType.text,
      deviceOriginId: 'd1',
    );
    await repo.updateContent(
      note.id,
      deltaContent: jsonEncode({
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'heading',
              'data': {
                'level': 1,
                'delta': [
                  {'insert': 'Agenda'}
                ],
              },
            },
            {
              'type': 'bulleted_list',
              'data': {
                'delta': [
                  {'insert': 'Review Q4 milestones — key items'}
                ],
              },
            },
            {
              'type': 'todo_list',
              'data': {
                'checked': true,
                'delta': [
                  {'insert': 'Send summary'}
                ],
              },
            },
          ],
        },
      }),
      plainText: 'Agenda\nReview Q4 milestones\nSend summary',
    );
    note = (await repo.getNoteById(note.id))!;

    final bytes = await renderNotePdf(note, const []);
    expect(bytes.length, greaterThan(200));
    expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('BulkExporter.exportNotePdf and exportAll(pdf) write valid PDFs',
      () async {
    final noteRepo = NoteRepository(db);
    final checklistRepo = ChecklistItemRepository(db);
    final attRepo = AttachmentRepository(db);

    final note = await noteRepo.createNote(
      title: 'Packing List',
      type: NoteType.checklist,
      deviceOriginId: 'd1',
    );
    await checklistRepo.addItem(noteId: note.id, text: 'Passport');
    await checklistRepo.addItem(noteId: note.id, text: 'Charger');

    final exporter = BulkExporter(
      noteRepository: noteRepo,
      checklistItemRepository: checklistRepo,
      attachmentRepository: attRepo,
      outputDirectory: tempDir,
      clock: () => DateTime(2026, 11, 26, 9, 0),
    );

    final singlePath = await exporter.exportNotePdf(note);
    final singleFile = File(singlePath);
    expect(singleFile.existsSync(), isTrue);
    final singleBytes = await singleFile.readAsBytes();
    expect(utf8.decode(singleBytes.sublist(0, 5)), '%PDF-');

    final zipPath = await exporter.exportAll(BulkExportFormat.pdf);
    final zipBytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('notes/Packing List.pdf'));
    expect(names, contains('manifest.json'));
  });
}
