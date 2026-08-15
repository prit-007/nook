import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
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

  Future<
      ({
        Uint8List imageBytes,
        Uint8List doodleBytes,
        Uint8List doodleThumbBytes,
        String notebookId,
        String sourceDelta,
      })> seedSourceDb() async {
    final noteRepo = NoteRepository(sourceDb);
    final checklistRepo = ChecklistItemRepository(sourceDb);
    final attachmentRepo = AttachmentRepository(sourceDb);
    final notebookRepo = NotebookRepository(sourceDb);

    final attachmentsDir = Directory('${tempRoot.path}/source-attachments');
    await attachmentsDir.create(recursive: true);

    final notebook = await notebookRepo.createNotebook(
      name: 'Work',
      colorSeed: '#6750A4',
    );

    final note = await noteRepo.createNote(
      id: 'note-vault-1',
      title: 'Ship It',
      type: NoteType.text,
      deviceOriginId: 'device-a',
      colorSeed: '#6750A4',
      notebookId: notebook.id,
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
    final doodleThumbBytes = Uint8List.fromList(
      List.generate(96, (i) => (i * 3 + 9) % 251),
    );
    final imagePath = '${attachmentsDir.path}/hero.png';
    final imageThumbPath = '${attachmentsDir.path}/hero_thumb.png';
    final doodlePath = '${attachmentsDir.path}/strokes.drawn';
    final doodleThumbPath = '${attachmentsDir.path}/strokes_thumb.png';
    await File(imagePath).writeAsBytes(imageBytes);
    await File(imageThumbPath).writeAsBytes(imageBytes);
    await File(doodlePath).writeAsBytes(doodleBytes);
    await File(doodleThumbPath).writeAsBytes(doodleThumbBytes);

    final imageId = await attachmentRepo.addImage(
      noteId: note.id,
      filePath: imagePath,
      sortOrder: 0,
    );
    await attachmentRepo.updateThumbnail(imageId, imageThumbPath);
    final doodleId = await attachmentRepo.addDoodle(
      noteId: note.id,
      filePath: doodlePath,
      sortOrder: 1,
    );
    await attachmentRepo.updateThumbnail(doodleId, doodleThumbPath);

    // Realistic delta referencing the media files by absolute path, exactly
    // like the editor stores them.
    final sourceDelta = jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': 'This is the body.'}
              ]
            },
          },
          {
            'type': 'image',
            'data': {'url': imagePath, 'align': 'center'}
          },
          {
            'type': 'doodle',
            'data': {
              'attachment_id': doodleId,
              'thumbnail_path': doodleThumbPath,
              'aspect_ratio': 1.333,
              'background_template': 'dotted',
            },
          },
        ],
      },
    });
    await noteRepo.updateContent(
      note.id,
      deltaContent: sourceDelta,
      plainText: 'This is the body.',
    );

    return (
      imageBytes: imageBytes,
      doodleBytes: doodleBytes,
      doodleThumbBytes: doodleThumbBytes,
      notebookId: notebook.id,
      sourceDelta: sourceDelta,
    );
  }

  test('exports a .nook zip with manifest, notebooks, markdown, and json',
      () async {
    final seeded = await seedSourceDb();

    final exporter = NookExporter(
      noteRepository: NoteRepository(sourceDb),
      checklistItemRepository: ChecklistItemRepository(sourceDb),
      attachmentRepository: AttachmentRepository(sourceDb),
      notebookRepository: NotebookRepository(sourceDb),
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

    final notebooksFile = zip.findFile('notebooks.json');
    expect(notebooksFile, isNotNull);
    final notebooks = jsonDecode(
      utf8.decode(notebooksFile!.content as List<int>),
    ) as List<dynamic>;
    expect(notebooks, hasLength(1));
    expect((notebooks.single as Map)['id'], seeded.notebookId);
    expect((notebooks.single as Map)['name'], 'Work');

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
    expect((noteJson['noteFields'] as Map)['notebookId'], seeded.notebookId);
    expect(noteJson['checklistItems'], hasLength(2));
    expect(noteJson['attachments'], hasLength(2));

    // Lossless extras: original paths + thumbnail bytes serialized so an
    // import can re-point the delta and restore thumbnails.
    final attachments = noteJson['attachments'] as List<dynamic>;
    for (final a in attachments) {
      expect((a as Map).containsKey('filePath'), isTrue);
      expect(a.containsKey('thumbnailPath'), isTrue);
      expect(a.containsKey('thumbnailBytes'), isTrue);
    }

    // Raw attachment binaries present for human-readable archive: 2 media
    // files + 2 thumbnails.
    final zipAttachments = zip.files
        .where((f) => f.name.startsWith('notes/note-vault-1/attachments/'))
        .toList();
    expect(zipAttachments, hasLength(4));
  });

  test('import restores notebooks, notes, checklists, and attachments',
      () async {
    final seeded = await seedSourceDb();

    final exporter = NookExporter(
      noteRepository: NoteRepository(sourceDb),
      checklistItemRepository: ChecklistItemRepository(sourceDb),
      attachmentRepository: AttachmentRepository(sourceDb),
      notebookRepository: NotebookRepository(sourceDb),
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
    expect(result.notebooksRestored, 1);

    final notebooks = await NotebookRepository(targetDb).getAllNotebooks();
    expect(notebooks, hasLength(1));
    expect(notebooks.single.id, seeded.notebookId);
    expect(notebooks.single.name, 'Work');

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
    expect(restored.notebookId, seeded.notebookId);

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

    // The delta's media paths are re-pointed at the restored files so images
    // and doodles render on the target device.
    final restoredDelta = restored.deltaContent!;
    expect(restoredDelta, isNot(contains(seeded.sourceDelta)));
    expect(restoredDelta, contains(restoredImage.filePath));
    expect(restoredDelta, contains(restoredDoodle.thumbnailPath!));
    expect(
      await File(restoredDoodle.thumbnailPath!).readAsBytes(),
      orderedEquals(seeded.doodleThumbBytes),
    );

    // Restored files live in the app's canonical layout so the doodle stays
    // editable (DoodleStorage looks for <id>.doodle.json next to <id>_thumb.png).
    expect(restoredImage.filePath, contains('${restoreDir.path}/attachments/'));
    expect(
        restoredDoodle.filePath, endsWith('${restoredDoodle.id}.doodle.json'));
    expect(restoredDoodle.thumbnailPath,
        endsWith('${restoredDoodle.id}_thumb.png'));
  });

  test(
      'import creates the referenced notebook when the vault has no '
      'notebooks.json (legacy archive)', () async {
    final seeded = await seedSourceDb();

    final exporter = NookExporter(
      noteRepository: NoteRepository(sourceDb),
      checklistItemRepository: ChecklistItemRepository(sourceDb),
      attachmentRepository: AttachmentRepository(sourceDb),
      notebookRepository: NotebookRepository(sourceDb),
      outputDirectory: tempRoot,
      clock: () => DateTime(2026, 8, 12, 14, 30, 0),
    );
    final zipPath = await exporter.exportAll();

    // Strip notebooks.json to emulate an archive exported before notebooks
    // were bundled — the note still references notebookId.
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final legacy = Archive();
    for (final f in archive.files.where((f) => f.name != 'notebooks.json')) {
      legacy.addFile(f);
    }
    final legacyPath = '${tempRoot.path}/legacy.nook';
    await File(legacyPath).writeAsBytes(ZipEncoder().encode(legacy)!);

    final importer = NookImporter(
      database: targetDb,
      restoredAttachmentsDirectory:
          Directory('${tempRoot.path}/restored-legacy'),
    );
    final result = await importer.importFrom(File(legacyPath));

    expect(result.isSuccessful, isTrue);
    expect(result.notesImported, 1);
    // Placeholder notebook created so the foreign key resolves.
    final notes = await NoteRepository(targetDb).getAllNotes();
    expect(notes.single.notebookId, seeded.notebookId);
    final notebooks = await NotebookRepository(targetDb).getAllNotebooks();
    expect(notebooks.single.id, seeded.notebookId);
    expect(notebooks.single.name, 'Imported Notebook');
  });

  test('import never clobbers existing notes (id collision -> fresh copy)',
      () async {
    await seedSourceDb();

    final exporter = NookExporter(
      noteRepository: NoteRepository(sourceDb),
      checklistItemRepository: ChecklistItemRepository(sourceDb),
      attachmentRepository: AttachmentRepository(sourceDb),
      notebookRepository: NotebookRepository(sourceDb),
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

  test('import rewrites Windows image/doodle paths onto the target device',
      () async {
    // A vault exported from a Windows device: attachments reference
    // `C:\Users\...` paths that exist only there. When imported on Android
    // (or any other platform) every reference must be re-pointed at the
    // restored files, and the doodle's strokes must survive byte-for-byte.
    const winImagePath = r'C:\Users\Me\Pictures\photo.png';
    const winImageThumb = r'C:\Users\Me\Pictures\photo_thumb.png';
    const winDoodlePath = r'C:\Users\Me\Doodles\sketch.doodle.json';
    const winDoodleThumb = r'C:\Users\Me\Doodles\sketch_thumb.png';

    final imageBytes = Uint8List.fromList(List.generate(64, (i) => i % 251));
    final imageThumbBytes =
        Uint8List.fromList(List.generate(32, (i) => (i * 2) % 251));
    final doodleBytes = Uint8List.fromList(List.generate(48, (i) => i + 1));
    final doodleThumbBytes =
        Uint8List.fromList(List.generate(24, (i) => (i * 3 + 7) % 251));

    final delta = jsonEncode({
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'image',
            'data': {'url': winImagePath, 'align': 'center'}
          },
          {
            'type': 'doodle',
            'data': {
              'attachment_id': 'doodle-1',
              'thumbnail_path': winDoodleThumb,
              'aspect_ratio': 1.333,
              'background_template': 'dotted',
            },
          },
        ],
      },
    });

    final archive = Archive()
      ..addFile(ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'formatVersion': 1,
          'exportedAt': DateTime.utc(2026, 8, 12).toIso8601String(),
          'deviceOriginId': 'windows-pc',
          'noteCount': 1,
        }),
      ))
      ..addFile(ArchiveFile.string(
        'notes/win-note/note.json',
        jsonEncode({
          'noteId': 'win-note',
          'syncVersion': 1,
          'updatedAt': DateTime.utc(2026, 8, 12).millisecondsSinceEpoch,
          'deviceOriginId': 'windows-pc',
          'noteFields': {
            'title': 'From Windows',
            'type': 'text',
            'colorSeed': '#6750A4',
            'notebookId': 'nb-windows',
            'deltaContent': delta,
            'plainText': 'Windows body',
          },
          'checklistItems': <dynamic>[],
          'attachments': [
            {
              'id': 'img-1',
              'type': 'image',
              'sortOrder': 0,
              'fileName': 'img-1.png',
              'filePath': winImagePath,
              'thumbnailPath': winImageThumb,
              'bytes': base64Encode(imageBytes),
              'thumbnailBytes': base64Encode(imageThumbBytes),
            },
            {
              'id': 'doodle-1',
              'type': 'doodleLayer',
              'sortOrder': 1,
              'fileName': 'doodle-1.drawn',
              'filePath': winDoodlePath,
              'thumbnailPath': winDoodleThumb,
              'bytes': base64Encode(doodleBytes),
              'thumbnailBytes': base64Encode(doodleThumbBytes),
            },
          ],
        }),
      ));

    final winZipPath = '${tempRoot.path}/windows.nook';
    await File(winZipPath).writeAsBytes(ZipEncoder().encode(archive)!);

    final restoreDir = Directory('${tempRoot.path}/restored-win');
    final importer = NookImporter(
      database: targetDb,
      restoredAttachmentsDirectory: restoreDir,
    );
    final result = await importer.importFrom(File(winZipPath));

    expect(result.isSuccessful, isTrue);
    expect(result.notesImported, 1);
    expect(result.attachmentsRestored, 2);
    // No notebooks.json in this legacy-style archive, but the referenced
    // notebook is still created so the foreign key never aborts the import.
    expect(result.notebooksRestored, 0);
    final notebooks = await NotebookRepository(targetDb).getAllNotebooks();
    expect(notebooks.single.id, 'nb-windows');

    final notes = await NoteRepository(targetDb).getAllNotes();
    final restored = notes.single;
    expect(restored.title, 'From Windows');
    expect(restored.plainText, 'Windows body');

    // No Windows path may survive in the delta.
    expect(restored.deltaContent, isNot(contains('C:')));

    // The image url and the doodle thumbnail are re-pointed at the restored
    // files on this device (Android-style absolute paths).
    final restoredDoc =
        jsonDecode(restored.deltaContent!) as Map<String, dynamic>;
    final children =
        ((restoredDoc['document'] as Map)['children'] as List).cast<Map>();
    final imageNode = children[0];
    final doodleNode = children[1];
    expect(imageNode['data']['url'], startsWith(restoreDir.path));
    expect(doodleNode['data']['thumbnail_path'], startsWith(restoreDir.path));
    expect(doodleNode['data']['attachment_id'], 'doodle-1');

    // The restored files carry the exact source bytes (image + doodle strokes +
    // thumbnails), and the doodle sidecar sits where DoodleStorage looks for it.
    final attachments =
        await AttachmentRepository(targetDb).getAllForNote('win-note');
    expect(attachments, hasLength(2));
    final restoredImage = attachments.firstWhere((a) => a.type.name == 'image');
    final restoredDoodle =
        attachments.firstWhere((a) => a.type.name == 'doodleLayer');
    expect(
      await File(restoredImage.filePath).readAsBytes(),
      orderedEquals(imageBytes),
    );
    expect(
      await File(restoredImage.thumbnailPath!).readAsBytes(),
      orderedEquals(imageThumbBytes),
    );
    expect(restoredDoodle.filePath, endsWith('doodle-1.doodle.json'));
    expect(
      await File(restoredDoodle.filePath).readAsBytes(),
      orderedEquals(doodleBytes),
    );
    expect(restoredDoodle.thumbnailPath, endsWith('doodle-1_thumb.png'));
    expect(
      await File(restoredDoodle.thumbnailPath!).readAsBytes(),
      orderedEquals(doodleThumbBytes),
    );
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
