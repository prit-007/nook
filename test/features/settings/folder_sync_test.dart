import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/folder_mirror.dart';

void main() {
  group('Encrypted folder sync mirror', () {
    test(
        'mirrorEncryptedSnapshot and importEncryptedSnapshots converge under duplicate/late snapshots',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('nook_folder_sync_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final dbA = AppDatabase(NativeDatabase.memory());
      final dbB = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await dbA.close();
        await dbB.close();
      });

      final repoA = NoteRepository(dbA);
      final repoB = NoteRepository(dbB);

      await repoA.createNote(
        id: 'folder-note-1',
        title: 'From Device A',
        type: NoteType.text,
        deviceOriginId: 'dev-a',
      );
      await repoA.createNote(
        id: 'folder-note-2',
        title: 'Second Note',
        type: NoteType.text,
        deviceOriginId: 'dev-a',
      );

      final mirrorA = FolderMirrorService(dbA);
      final snapshotFile = await mirrorA.mirrorEncryptedSnapshot(
        tempDir,
        password: 'sync-folder-secret',
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      expect(await snapshotFile.exists(), isTrue);

      // Mirror a second snapshot (simulating duplicate/later write).
      await mirrorA.mirrorEncryptedSnapshot(
        tempDir,
        password: 'sync-folder-secret',
        argon2Memory: 1024,
        argon2Iterations: 1,
      );

      final mirrorB = FolderMirrorService(dbB);
      final imported = await mirrorB.importEncryptedSnapshots(
        tempDir,
        password: 'sync-folder-secret',
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      expect(imported, greaterThanOrEqualTo(2));

      final notesB = await repoB.getAllNotes();
      expect(
        notesB.map((n) => n.id),
        containsAll(['folder-note-1', 'folder-note-2']),
      );
    });
  });
}
