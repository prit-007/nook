import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/export_handler.dart';
import 'package:nook/features/settings/widgets/import_handler.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase sourceDb;
  late AppDatabase targetDb;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('nook-export-test');
    sourceDb = createTestDatabase();
    targetDb = createTestDatabase();
  });

  tearDown(() async {
    await sourceDb.close();
    await targetDb.close();
    await tempRoot.delete(recursive: true);
  });

  Future<({Uint8List imageBytes, Uint8List doodleBytes})> seedSourceDb() async {
    final noteRepo = NoteRepository(sourceDb);
    final checklistRepo = ChecklistItemRepository(sourceDb);
    final attachmentRepo = AttachmentRepository(sourceDb);

    final attachmentsDir = Directory('${tempRoot.path}/source-attachments');
    await attachmentsDir.create(recursive: true);

    final note = await noteRepo.createNote(
      id: 'note-vault-1',
      title: 'Ship It',
      type: NoteType.text,
      deviceOriginId: 'device-a',
      colorSeed: '#6750A4',
      deltaContent: '{"ops":[{"insert":"This is the body."}]}',
      plainText: 'This is the body.',
      syncVersion: 3,
    );

    await checklistRepo.addItem(
      noteId: note.id,
      text: 'Buy milk',
      sortOrder: 0,
    );
    final dog = await checklistRepo.addItem(
      noteId: note.id,
      text: 'Walk dog',
      sortOrder: 1,
    );
    await checklistRepo.toggleChecked(dog.id);

    final imageBytes = Uint8List.fromList(
      List.generate(256, (i) => i % 251),
    );
    final doodleBytes = Uint8List.fromList(
      List.generate(192, (i) => (i * 7 + 3) % 251),
    );
    final imagePath = '${attachmentsDir.path}/hero.img';
    final doodlePath = '${attachmentsDir.path}/strokes.drawn';
    await File(imagePath).writeAsBytes(imageBytes);
    await File(doodlePath).writeAsBytes(doodleBytes);

    await attachmentRepo.addImage(
      noteId: note.id,
      filePath: imagePath,
      sortOrder: 0,
    );
    await attachmentRepo.addDoodle(
      noteId: note.id,
      filePath: doodlePath,
      sortOrder: 1,
    );

    return (
      imageBytes: imageBytes,
      doodleBytes: doodleBytes,
    );
  }

  test('exports a .nook zip with manifest, markdown, and lossless json',
      () async {
    await seedSourceDb();

    final exporter = NookExporter(
      noteRepository: NoteRepository(sourceDb),
      checklistItemRepository: ChecklistItemRepository(sourceDb),
      attachmentRepository: AttachmentRepository(sourceDb),
      outputDirectory: tempRoot,
      clock: () => DateTime(2026, 8, 12, 14, 30, 0),
    );

    final path = await exporter.exportAll();
    expect(path, '${tempRoot.path}/nook-export-20260812-143000.nook');

    final zip = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    expect(zip.findFile('manifest.json'), isNotNull);

    final manifest = jsonDecode(
      utf8.decode(zip.findFile('manifest.json')!.content as List<int>),
    ) as Map<String, dynamic>;
    expect(manifest['formatVersion'], 1);
    expect(manifest['noteCount'], 1);
    expect(manifest['deviceOriginId'], isA<String>());

    final markdownFile = zip.findFile('notes/note-vault-1/note.md');
    expect(markdownFile, isNotNull);
    final markdown = utf8.decode(markdownFile!.content as List<int>);
    expect(markdown, contains('# Ship It'));
    expect(markdown, contains('This is the body.'));
    expect(markdown, contains('- [ ] Buy milk'));
    expect(markdown, contains('- [x] Walk dog'));

    final jsonFile = zip.findFile('notes/note-vault-1/note.json');
    expect(jsonFile, isNotNull);
    final noteJson = jsonDecode(utf8.decode(jsonFile!.content as List<int>))
        as Map<String, dynamic>;
    expect(noteJson['noteId'], 'note-vault-1');
    expect((noteJson['noteFields'] as Map)['title'], 'Ship It');
    expect((noteJson['noteFields'] as Map)['colorSeed'], '#6750A4');
    expect(noteJson['checklistItems'], hasLength(2));
    expect(noteJson['attachments'], hasLength(2));

    // Raw attachment binaries present for human-readable archive.
    final zipAttachments = zip.files
        .where((f) => f.name.startsWith('notes/note-vault-1/attachments/'))
        .toList();
    expect(zipAttachments, hasLength(2));
  });

  test('import restores notes, checklists, and attachments into a fresh db',
      () async {
    final seeded = await seedSourceDb();

    final exporter = NookExporter(
      noteRepository: NoteRepository(sourceDb),
      checklistItemRepository: ChecklistItemRepository(sourceDb),
      attachmentRepository: AttachmentRepository(sourceDb),
      outputDirectory: tempRoot,
      clock: () => DateTime(2026, 8, 12, 14, 30, 0),
    );
    final zipPath = await exporter.exportAll();

    final restoreDir = Directory('${tempRoot.path}/restored');
    final importer = NookImporter(
      database: targetDb,
      restoredAttachmentsDirectory: restoreDir,
    );
    final result = await importer.importFrom(File(zipPath));

    expect(result.isSuccessful, isTrue);
    expect(result.notesImported, 1);
    expect(result.duplicateNotes, 0);
    expect(result.attachmentsRestored, 2);

    final notes = await NoteRepository(targetDb).getAllNotes();
    expect(notes, hasLength(1));
    final restored = notes.single;
    expect(restored.title, 'Ship It');
    expect(restored.id, 'note-vault-1');
    expect(restored.deviceOriginId, 'device-a');
    expect(restored.colorSeed, '#6750A4');
    expect(restored.plainText, 'This is the body.');
    expect(restored.syncVersion, 3);
    expect(restored.type, NoteType.text);

    final items =
        await ChecklistItemRepository(targetDb).getItems('note-vault-1');
    expect(items, hasLength(2));
    expect(items[0].itemText, 'Buy milk');
    expect(items[0].checked, isFalse);
    expect(items[1].itemText, 'Walk dog');
    expect(items[1].checked, isTrue);
    expect(items[1].sortOrder, 1);

    final attachments =
        await AttachmentRepository(targetDb).getAllForNote('note-vault-1');
    expect(attachments, hasLength(2));
    final restoredImage = attachments.firstWhere((a) => a.type.name == 'image');
    final restoredDoodle =
        attachments.firstWhere((a) => a.type.name == 'doodleLayer');
    expect(restoredImage.sortOrder, 0);
    expect(restoredDoodle.sortOrder, 1);
    expect(
      await File(restoredImage.filePath).readAsBytes(),
      orderedEquals(seeded.imageBytes),
    );
    expect(
      await File(restoredDoodle.filePath).readAsBytes(),
      orderedEquals(seeded.doodleBytes),
    );
  });

  test('import never clobbers existing notes (id collision -> fresh copy)',
      () async {
    await seedSourceDb();

    final exporter = NookExporter(
      noteRepository: NoteRepository(sourceDb),
      checklistItemRepository: ChecklistItemRepository(sourceDb),
      attachmentRepository: AttachmentRepository(sourceDb),
      outputDirectory: tempRoot,
      clock: () => DateTime(2026, 8, 12, 14, 30, 0),
    );
    final zipPath = await exporter.exportAll();

    // Target db already has a note with the same id.
    await NoteRepository(targetDb).createNote(
      id: 'note-vault-1',
      title: 'Local Existing Note',
      type: NoteType.text,
      deviceOriginId: 'device-a',
    );

    final importer = NookImporter(
      database: targetDb,
      restoredAttachmentsDirectory: Directory('${tempRoot.path}/restored-2'),
    );
    final result = await importer.importFrom(File(zipPath));

    expect(result.isSuccessful, isTrue);
    expect(result.notesImported, 1);
    expect(result.duplicateNotes, 1);

    final notes = await NoteRepository(targetDb).getAllNotes();
    expect(notes, hasLength(2));
    // Original untouched.
    final local = await NoteRepository(targetDb).getNoteById('note-vault-1');
    expect(local!.title, 'Local Existing Note');
    // Imported copy present under a fresh id.
    final imported = notes.firstWhere((n) => n.id != 'note-vault-1');
    expect(imported.title, 'Ship It');
    expect(imported.plainText, 'This is the body.');
  });

  test('rejects archives without a supported manifest', () async {
    final file = File('${tempRoot.path}/broken.nook');
    final archive = Archive()
      ..addFile(ArchiveFile.string('hello.txt', 'world'));
    await file.writeAsBytes(ZipEncoder().encode(archive)!);

    final importer = NookImporter(database: targetDb);
    final result = await importer.importFrom(file);
    expect(result.isSuccessful, isFalse);
    expect(result.error, contains('manifest.json'));
  });
}
