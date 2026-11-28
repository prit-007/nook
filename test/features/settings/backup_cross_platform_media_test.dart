import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/backup_handler.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Cross-platform backup media path recovery', () {
    test(
        'rewrites source-device image & doodle paths to target attachmentsDirectory on restore',
        () async {
      final srcDir = await Directory.systemTemp.createTemp('nook_src_media_');
      final dstDir = await Directory.systemTemp.createTemp('nook_dst_media_');
      final backupDir = await Directory.systemTemp.createTemp('nook_bak_');
      addTearDown(() async {
        for (final d in [srcDir, dstDir, backupDir]) {
          if (await d.exists()) await d.delete(recursive: true);
        }
      });

      final dbSrc = AppDatabase(NativeDatabase.memory());
      final dbDst = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await dbSrc.close();
        await dbDst.close();
      });

      // Create real media + doodle thumbnail on source device.
      final imgFile = File(p.join(srcDir.path, 'vacation.png'));
      await imgFile.writeAsBytes([137, 80, 78, 71, 1, 2, 3, 4]);
      final doodleFile = File(p.join(srcDir.path, 'sketch_1.doodle.json'));
      await doodleFile.writeAsString('{"strokes":[]}');
      final thumbFile = File(p.join(srcDir.path, 'sketch_1_thumb.png'));
      await thumbFile.writeAsBytes([137, 80, 78, 71, 9, 8, 7, 6]);

      final noteRepo = NoteRepository(dbSrc);
      final attRepo = AttachmentRepository(dbSrc);

      const windowsOldImg = r'C:\Users\Alice\Documents\nook\vacation.png';
      const windowsOldThumb =
          r'C:\Users\Alice\Documents\nook\sketch_1_thumb.png';

      final note = await noteRepo.createNote(
        id: 'cross-os-note-1',
        title: 'Cross-OS Media Note',
        type: NoteType.text,
        deviceOriginId: 'win-device',
        deltaContent: jsonEncode({
          'document': {
            'children': [
              {
                'type': 'image',
                'data': {'url': windowsOldImg},
              },
              {
                'type': 'doodle',
                'data': {
                  'attachment_id': 'doodle-att-1',
                  'thumbnail_path': windowsOldThumb,
                },
              },
            ],
          },
        }),
      );

      await attRepo.addImage(
        id: 'img-att-1',
        noteId: note.id,
        filePath: imgFile.path,
      );
      await dbSrc.into(dbSrc.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('doodle-att-1'),
              noteId: note.id,
              type: AttachmentType.doodleLayer,
              filePath: doodleFile.path,
              thumbnailPath: Value(thumbFile.path),
            ),
          );

      final srcHandler = BackupHandler(
        dbSrc,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      final backupFile = await srcHandler.createEncryptedBackup(
        password: 'cross-os-password',
        outputDirectory: backupDir,
      );

      final dstHandler = BackupHandler(
        dbDst,
        attachmentsDirectory: dstDir,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      final restoredCount = await dstHandler.restoreEncryptedBackup(
        backupFile: backupFile,
        password: 'cross-os-password',
      );
      expect(restoredCount, 1);

      final restoredNote = await NoteRepository(dbDst).getNoteById(note.id);
      expect(restoredNote, isNotNull);

      final decoded = jsonDecode(restoredNote!.deltaContent!) as Map;
      final children = (decoded['document'] as Map)['children'] as List;
      final restoredImgUrl =
          ((children[0] as Map)['data'] as Map)['url'] as String;
      final restoredThumbPath =
          ((children[1] as Map)['data'] as Map)['thumbnail_path'] as String;

      expect(restoredImgUrl, startsWith(dstDir.path));
      expect(File(restoredImgUrl).existsSync(), isTrue);
      expect(restoredThumbPath, startsWith(dstDir.path));
      expect(File(restoredThumbPath).existsSync(), isTrue);
    });
  });
}
