import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/pipeline/sync_bundle_packer.dart';

void main() {
  group('SyncBundlePacker', () {
    late AppDatabase db;
    late Directory tempDir;
    late NoteRepository noteRepo;
    late AttachmentRepository attachmentRepo;
    late TagRepository tagRepo;
    late NotebookRepository notebookRepo;
    late SyncBundlePacker packer;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('nook_packer_test_');
      noteRepo = NoteRepository(db);
      attachmentRepo = AttachmentRepository(db);
      tagRepo = TagRepository(db);
      notebookRepo = NotebookRepository(db);

      packer = SyncBundlePacker(
        db: db,
        noteRepo: noteRepo,
        attachmentRepo: attachmentRepo,
        tagRepo: tagRepo,
        notebookRepo: notebookRepo,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('packs notes with notebook metadata, tags, checklist items, and files',
        () async {
      // 1. Create notebook
      final notebook = await notebookRepo.createNotebook(
        name: 'Work Projects',
        colorSeed: '#4CAF50',
        icon: 'briefcase',
      );

      // 2. Create note
      final note = await noteRepo.createNote(
        id: 'test-note-1',
        title: 'Sprint Planning',
        type: NoteType.mixed,
        notebookId: notebook.id,
        plainText: 'Sprint items to complete',
        deltaContent: '{"ops":[{"insert":"Sprint items\\n"}]}',
        deviceOriginId: 'device-test-1',
      );

      // 3. Create tag and assign
      final tag = await tagRepo.createTag(name: 'urgent', colorSeed: '#F44336');
      await tagRepo.assignTagToNote(note.id, tag.id);

      // 4. Create checklist item
      await db.into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('item-1'),
              noteId: note.id,
              itemText: 'Review PRs',
              checked: const Value(true),
              sortOrder: const Value(0),
            ),
          );

      // 5. Create attachment file on disk and add to DB
      final imageFile = File('${tempDir.path}/test_img.png');
      await imageFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
      await attachmentRepo.addImage(
        noteId: note.id,
        filePath: imageFile.path,
        id: 'att-1',
      );

      // Pack bundle
      final progressEvents = <String>[];
      final bundle = await packer.pack(
        noteIds: [note.id],
        senderDeviceId: 'local-phone',
        senderDeviceName: 'Prit Phone',
        onProgress: (packed, total, title) {
          progressEvents.add('$packed/$total: $title');
        },
      );

      expect(bundle.protocolVersion, '1.0');
      expect(bundle.senderDeviceId, 'local-phone');
      expect(bundle.senderDeviceName, 'Prit Phone');
      expect(bundle.notes.length, 1);

      final entry = bundle.notes.first;
      expect(entry.noteId, note.id);
      expect(entry.noteFields['title'], 'Sprint Planning');
      expect(entry.noteFields['notebookName'], 'Work Projects');
      expect(entry.noteFields['notebookColorSeed'], '#4CAF50');
      expect(entry.noteFields['notebookIcon'], 'briefcase');

      // Tags
      final tags = entry.noteFields['tags'] as List?;
      expect(tags, isNotNull);
      expect(tags!.length, 1);
      expect((tags.first as Map)['name'], 'urgent');

      // Checklist items
      expect(entry.checklistItems, isNotNull);
      expect(entry.checklistItems!.length, 1);
      expect(entry.checklistItems!.first['itemText'], 'Review PRs');
      expect(entry.checklistItems!.first['checked'], true);

      // Attachments
      expect(entry.attachments, isNotNull);
      expect(entry.attachments!.length, 1);
      expect(entry.attachments!.first.bytes, [1, 2, 3, 4, 5]);

      // Progress callback
      expect(progressEvents, ['1/1: Sprint Planning']);
    });

    test('ignores non-existent note IDs and returns empty notes list',
        () async {
      final bundle = await packer.pack(
        noteIds: ['does-not-exist'],
        senderDeviceId: 'device-1',
        senderDeviceName: 'Device 1',
      );
      expect(bundle.notes, isEmpty);
    });
  });
}
