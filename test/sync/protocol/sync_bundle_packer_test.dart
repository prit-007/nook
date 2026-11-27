import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/protocol/sync_bundle_packer.dart';

void main() {
  group('SyncBundlePacker protocol export', () {
    late AppDatabase db;
    late NoteRepository noteRepo;
    late AttachmentRepository attachmentRepo;
    late TagRepository tagRepo;
    late NotebookRepository notebookRepo;
    late SyncBundlePacker packer;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
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
    });

    test(
        'packs notebookParentId for nested sub-notebook notes via protocol export',
        () async {
      final parent = await notebookRepo.createNotebook(
        name: 'Parent Collection',
        colorSeed: '#2196F3',
      );
      final child = await notebookRepo.createNotebook(
        name: 'Nested Sub-Collection',
        colorSeed: '#4CAF50',
        parentId: parent.id,
      );

      final note = await noteRepo.createNote(
        id: 'note-proto-1',
        title: 'Child Note',
        type: NoteType.text,
        notebookId: child.id,
        deviceOriginId: 'device-1',
      );

      final bundle = await packer.pack(
        noteIds: [note.id],
        senderDeviceId: 'device-1',
        senderDeviceName: 'Device 1',
      );

      expect(bundle.notes.length, 1);
      final entry = bundle.notes.first;
      expect(entry.noteFields['notebookName'], 'Nested Sub-Collection');
      expect(entry.noteFields['notebookParentId'], parent.id);
    });
  });
}
