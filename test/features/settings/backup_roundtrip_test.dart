import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/reminder_repository.dart';
import 'package:nook/data/repositories/revision_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/repositories/template_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/backup_handler.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
      'Full lossless backup -> wipe -> restore preserves all tables & attachments',
      () async {
    final srcDb = createTestDatabase();
    addTearDown(srcDb.close);

    final tempDir = await Directory.systemTemp.createTemp('nook_full_rt_');
    addTearDown(() => tempDir.delete(recursive: true));

    final nbRepo = NotebookRepository(srcDb);
    final noteRepo = NoteRepository(srcDb);
    final tagRepo = TagRepository(srcDb);
    final checklistRepo = ChecklistItemRepository(srcDb);
    final attachRepo = AttachmentRepository(srcDb);
    final reminderRepo =
        ReminderRepository(srcDb, scheduler: const NoopReminderScheduler());
    final revRepo = RevisionRepository(srcDb);
    final tmplRepo = TemplateRepository(srcDb);

    final nb = await nbRepo.createNotebook(name: 'Vault', colorSeed: '#4CAF50');
    final target = await noteRepo.createNote(
      title: 'Target Note',
      type: NoteType.text,
      deviceOriginId: 'dev-1',
    );
    final note = await noteRepo.createNote(
      title: 'Full Note',
      type: NoteType.checklist,
      deviceOriginId: 'dev-1',
      notebookId: nb.id,
      deltaContent:
          '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Link","attributes":{"href":"nook://note/${target.id}"}}]}}]}}',
      plainText: 'Full note text',
    );
    await noteRepo.updateContent(
      note.id,
      deltaContent:
          '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Link","attributes":{"href":"nook://note/${target.id}"}}]}}]}}',
      plainText: 'Full note text',
    );
    await checklistRepo.addItem(noteId: note.id, text: 'Item 1', checked: true);
    await tagRepo.assignTagByName(note.id, 'lossless');

    final doodleFile = File(p.join(tempDir.path, 'stroke.doodle.json'))
      ..writeAsStringSync('{"strokes":[]}');
    await attachRepo.addDoodle(noteId: note.id, filePath: doodleFile.path);

    await reminderRepo.create(
      noteId: note.id,
      title: 'Backup Reminder',
      fireAt: DateTime.now().add(const Duration(days: 3)),
    );
    await revRepo.maybeSnapshot(
      noteId: note.id,
      title: 'Full Note',
      deltaContent: '{}',
      plainText: 'Rev 1',
      source: RevisionSource.manual,
    );
    await tmplRepo.seedBuiltinsIfEmpty();

    final handler = BackupHandler(
      srcDb,
      argon2Memory: 1024,
      argon2Iterations: 1,
    );
    final backupFile = await handler.createEncryptedBackup(
      password: 'lossless-password',
      outputDirectory: tempDir,
    );

    final dstDb = createTestDatabase();
    addTearDown(dstDb.close);
    final restoreDir = Directory(p.join(tempDir.path, 'restored_att'))
      ..createSync();
    final dstHandler = BackupHandler(
      dstDb,
      argon2Memory: 1024,
      argon2Iterations: 1,
      attachmentsDirectory: restoreDir,
    );
    final count = await dstHandler.restoreEncryptedBackup(
      backupFile: backupFile,
      password: 'lossless-password',
    );
    expect(count, 2);

    // Assert every table restored cleanly.
    expect(
        await AttachmentRepository(dstDb).getAllForNote(note.id), hasLength(1));
    final restoredAtt =
        (await AttachmentRepository(dstDb).getAllForNote(note.id)).first;
    expect(File(restoredAtt.filePath).existsSync(), isTrue);
    expect(File(restoredAtt.filePath).readAsStringSync(), '{"strokes":[]}');

    expect(
      await ReminderRepository(dstDb, scheduler: const NoopReminderScheduler())
          .forNote(note.id),
      hasLength(1),
    );
    expect(await RevisionRepository(dstDb).listForNote(note.id), hasLength(1));
    expect(await TemplateRepository(dstDb).all(), hasLength(4));
    expect(await NoteLinkRepository(dstDb).incomingTo(target.id), hasLength(1));
  });
}
