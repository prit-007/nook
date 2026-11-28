import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/folder_mirror.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FolderMirrorService (Phase 4.2)', () {
    test(
        'mirrors unlocked notes as Markdown, excludes locked notes, prunes deleted',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);

      final pub = await noteRepo.createNote(
        title: 'Public Mirror',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Hello Syncthing',
      );
      final secret = await noteRepo.createNote(
        title: 'Locked Secret',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Never mirror me',
      );
      await noteRepo.updateNote(secret.id, locked: true);

      final mirrorDir =
          await Directory.systemTemp.createTemp('nook_folder_mirror');
      addTearDown(() => mirrorDir.delete(recursive: true));

      final service = FolderMirrorService(db);
      final count1 = await service.mirrorToDirectory(mirrorDir);
      expect(count1, 1);

      final files1 = mirrorDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(files1, hasLength(1));
      expect(files1.first.readAsStringSync(), contains('Hello Syncthing'));
      expect(
        files1.any((f) => p.basename(f.path).contains(secret.id)),
        isFalse,
      );

      // Soft-delete public note and re-mirror -> file should be pruned.
      await noteRepo.softDelete(pub.id);
      final count2 = await service.mirrorToDirectory(mirrorDir);
      expect(count2, 0);
      final files2 = mirrorDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(files2, isEmpty);
    });
  });
}
