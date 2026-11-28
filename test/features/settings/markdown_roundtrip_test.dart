import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/importers/joplin_importer.dart';
import 'package:nook/features/importers/obsidian_importer.dart';
import 'package:nook/features/settings/widgets/bulk_export.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Markdown round-trip & importers (Phase 4.3)', () {
    test(
        'BulkExporter Markdown -> ObsidianImporter round-trip preserves content',
        () async {
      final srcDb = createTestDatabase();
      addTearDown(srcDb.close);
      final noteRepo = NoteRepository(srcDb);
      final checklistRepo = ChecklistItemRepository(srcDb);
      final tagRepo = TagRepository(srcDb);

      final note = await noteRepo.createNote(
        title: 'Round Trip Note',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Body paragraph line',
      );
      await tagRepo.assignTagByName(note.id, 'journal');

      final tempDir =
          await Directory.systemTemp.createTemp('nook_md_roundtrip');
      addTearDown(() => tempDir.delete(recursive: true));

      final exporter = BulkExporter(
        noteRepository: noteRepo,
        checklistItemRepository: checklistRepo,
        attachmentRepository: AttachmentRepository(srcDb),
        outputDirectory: tempDir,
      );
      final zipPath = await exporter.exportAll(BulkExportFormat.markdown);
      final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());

      final vaultDir = Directory(p.join(tempDir.path, 'vault'))..createSync();
      for (final file in archive.files) {
        if (file.isFile && file.name.endsWith('.md')) {
          File(p.join(vaultDir.path, p.basename(file.name)))
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content as List<int>);
        }
      }

      final dstDb = createTestDatabase();
      addTearDown(dstDb.close);
      final imported = await ObsidianImporter(dstDb).importDirectory(vaultDir);
      expect(imported, 1);

      final notes = await NoteRepository(dstDb).getAllNotes();
      expect(notes, hasLength(1));
      expect(notes.first.title, 'Round Trip Note');
      expect(notes.first.plainText, contains('Body paragraph line'));
    });

    test('ObsidianImporter imports frontmatter tags and checklists', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final dir = await Directory.systemTemp.createTemp('nook_obsidian_test');
      addTearDown(() => dir.delete(recursive: true));

      File(p.join(dir.path, 'Daily.md')).writeAsStringSync('''---
tags: [work, planning]
---
# Daily Plan

- [x] Ship Phase 4
- [ ] Write docs
''');

      final count = await ObsidianImporter(db).importDirectory(dir);
      expect(count, 1);

      final notes = await NoteRepository(db).getAllNotes();
      expect(notes.first.title, 'Daily Plan');
      expect(notes.first.type, NoteType.checklist);

      final items = await ChecklistItemRepository(db).getItems(notes.first.id);
      expect(items, hasLength(2));
      expect(items.first.checked, isTrue);

      final tags = await TagRepository(db).getTagsForNote(notes.first.id);
      expect(tags.map((t) => t.name).toSet(), {'work', 'planning'});
    });

    test('JoplinImporter imports .jex tar archive', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final dir = await Directory.systemTemp.createTemp('nook_joplin_test');
      addTearDown(() => dir.delete(recursive: true));

      final jexContent = '''Joplin Note Title

Body from Joplin

id: abc123
type_: 1
''';
      final archive = Archive()
        ..addFile(
          ArchiveFile.string('abc123.md', jexContent),
        );
      final tarBytes = TarEncoder().encode(archive);
      final jexFile = File(p.join(dir.path, 'export.jex'))
        ..writeAsBytesSync(tarBytes);

      final count = await JoplinImporter(db).importJexFile(jexFile);
      expect(count, 1);

      final notes = await NoteRepository(db).getAllNotes();
      expect(notes.first.title, 'Joplin Note Title');
      expect(utf8.encode(notes.first.plainText ?? ''), isNotEmpty);
      expect(notes.first.plainText, contains('Body from Joplin'));
    });
  });
}
