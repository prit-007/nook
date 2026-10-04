import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/bulk_export.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late NoteRepository noteRepo;
  late ChecklistItemRepository checklistRepo;
  late AttachmentRepository attachmentRepo;
  late BulkExporter exporter;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nook-bulk-export');
    db = createTestDatabase();
    noteRepo = NoteRepository(db);
    checklistRepo = ChecklistItemRepository(db);
    attachmentRepo = AttachmentRepository(db);
    exporter = BulkExporter(
      noteRepository: noteRepo,
      checklistItemRepository: checklistRepo,
      attachmentRepository: attachmentRepo,
      outputDirectory: tempDir,
      clock: () => DateTime(2026, 10, 4, 12, 30),
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<Uint8List> writeBytes(String name) async {
    final file = File('${tempDir.path}/$name');
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
    await file.writeAsBytes(bytes);
    return bytes;
  }

  group('renderNoteMarkdown / renderNoteHtml attachments', () {
    test('markdown lists image and doodle refs when provided', () async {
      final note = await noteRepo.createNote(
        title: 'With media',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'body',
      );
      await writeBytes('img.png');
      await writeBytes('doodle.json');
      await writeBytes('thumb.png');
      await attachmentRepo.addImage(
        noteId: note.id,
        filePath: '${tempDir.path}/img.png',
      );
      await attachmentRepo.addDoodle(
        noteId: note.id,
        filePath: '${tempDir.path}/doodle.json',
      );
      final doodle = (await attachmentRepo.getAllForNote(note.id)).firstWhere(
        (a) => a.type == AttachmentType.doodleLayer,
      );
      await attachmentRepo.updateThumbnail(
        doodle.id,
        '${tempDir.path}/thumb.png',
      );

      final atts = await exporter.loadAttachmentsForTesting(note.id);
      expect(atts, hasLength(2));
      final refs = {
        for (final a in atts) a.attachment.id: 'attachments/${a.archiveName}',
      };
      final md = renderNoteMarkdown(
        note,
        [],
        attachmentRefs: refs,
        attachments: atts,
      );
      expect(md, contains('Attachments:'));
      expect(md, contains('![image](attachments/'));
      expect(md, contains('[doodle:'));
    });
    test('html embeds base64 when embedAttachments=true', () async {
      final note = await noteRepo.createNote(
        title: 'Share media',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'hi',
      );
      await writeBytes('embed.png');
      await attachmentRepo.addImage(
        noteId: note.id,
        filePath: '${tempDir.path}/embed.png',
      );
      final atts = await exporter.loadAttachmentsForTesting(note.id);
      final html = renderNoteHtml(
        note,
        [],
        attachments: atts,
        embedAttachments: true,
      );
      expect(html, contains('data:image/'));
      expect(html, contains('base64,'));
      expect(html, contains('class="attachment"'));
    });
  });

  group('BulkExporter with attachments', () {
    test('markdown zip includes note file and attachment binaries', () async {
      final note = await noteRepo.createNote(
        title: 'Media note',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'hello',
      );
      await writeBytes('photo.png');
      await attachmentRepo.addImage(
        noteId: note.id,
        filePath: '${tempDir.path}/photo.png',
      );

      final path = await exporter.exportAll(BulkExportFormat.markdown);
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final names = archive.files.map((f) => f.name).toList();

      expect(names.where((n) => n.endsWith('.md')), hasLength(1));
      expect(
        names.any((n) => n.contains('attachments/') && n.endsWith('.png')),
        isTrue,
      );
      final manifest =
          archive.files.firstWhere((f) => f.name == 'manifest.json');
      final manifestText = String.fromCharCodes(manifest.content as List<int>);
      expect(manifestText, contains('"attachmentCount":1'));
    });

    test('html zip includes attachment files for relative img src', () async {
      final note = await noteRepo.createNote(
        title: 'Html media',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'x',
      );
      await writeBytes('pic.jpg');
      await attachmentRepo.addImage(
        noteId: note.id,
        filePath: '${tempDir.path}/pic.jpg',
      );

      final path = await exporter.exportAll(BulkExportFormat.html);
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final names = archive.files.map((f) => f.name).toList();
      expect(names.any((n) => n.endsWith('.html')), isTrue);
      expect(
        names.any((n) => n.contains('attachments/') && n.endsWith('.jpg')),
        isTrue,
      );
    });

    test('exportNoteHtml embeds doodle thumbnail when present', () async {
      final note = await noteRepo.createNote(
        title: 'Doodle note',
        type: NoteType.doodle,
        deviceOriginId: 'd1',
      );
      await writeBytes('doodle.json');
      await writeBytes('doodle.png');
      await attachmentRepo.addDoodle(
        noteId: note.id,
        filePath: '${tempDir.path}/doodle.json',
      );
      final doodle = (await attachmentRepo.getAllForNote(note.id)).first;
      await attachmentRepo.updateThumbnail(
        doodle.id,
        '${tempDir.path}/doodle.png',
      );

      final path = await exporter.exportNoteHtml(note);
      final html = await File(path).readAsString();
      expect(html, contains('data:image/png;base64,'));
    });

    test('doodle without thumbnail is skipped in portable zip', () async {
      final note = await noteRepo.createNote(
        title: 'Bare doodle',
        type: NoteType.doodle,
        deviceOriginId: 'd1',
      );
      await writeBytes('strokes.json');
      await attachmentRepo.addDoodle(
        noteId: note.id,
        filePath: '${tempDir.path}/strokes.json',
      );

      final path = await exporter.exportAll(BulkExportFormat.markdown);
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final names = archive.files.map((f) => f.name).toList();
      expect(names.any((n) => n.contains('attachments/')), isFalse);
      expect(names.where((n) => n.endsWith('.md')), hasLength(1));
    });

    test('doodle with thumbnail is exported as PNG in zip', () async {
      final note = await noteRepo.createNote(
        title: 'Thumb doodle',
        type: NoteType.doodle,
        deviceOriginId: 'd1',
      );
      await writeBytes('strokes.json');
      await writeBytes('rendered.png');
      await attachmentRepo.addDoodle(
        noteId: note.id,
        filePath: '${tempDir.path}/strokes.json',
      );
      final doodle = (await attachmentRepo.getAllForNote(note.id)).first;
      await attachmentRepo.updateThumbnail(
        doodle.id,
        '${tempDir.path}/rendered.png',
      );

      final path = await exporter.exportAll(BulkExportFormat.markdown);
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final names = archive.files.map((f) => f.name).toList();
      expect(
        names.any((n) => n.contains('attachments/') && n.endsWith('.png')),
        isTrue,
      );
      final mdFile = archive.files.firstWhere((f) => f.name.endsWith('.md'));
      final md = String.fromCharCodes(mdFile.content as List<int>);
      expect(md, contains('[doodle:'));
    });
  });
}
