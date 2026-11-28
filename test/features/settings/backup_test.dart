import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/backup_handler.dart';
import 'package:nook/features/settings/widgets/backup_screen.dart';

void main() {
  group('Encrypted .nookbackup (Phase 4.1)', () {
    test(
        'backup -> wipe -> restore preserves notes, notebooks, tags, checklists',
        () async {
      final sourceDb = createTestDatabase();
      addTearDown(sourceDb.close);

      final nbRepo = NotebookRepository(sourceDb);
      final noteRepo = NoteRepository(sourceDb);
      final tagRepo = TagRepository(sourceDb);
      final checklistRepo = ChecklistItemRepository(sourceDb);

      final nb = await nbRepo.createNotebook(
        name: 'Research',
        colorSeed: '#4CAF50',
      );
      final note = await noteRepo.createNote(
        title: 'Quantum Notes',
        type: NoteType.checklist,
        deviceOriginId: 'dev-1',
        notebookId: nb.id,
        plainText: 'Checklist summary',
      );
      await checklistRepo.addItem(noteId: note.id, text: 'Verify Argon2id');
      await tagRepo.assignTagByName(note.id, 'security');

      final tempDir = await Directory.systemTemp.createTemp('nook_backup_test');
      addTearDown(() => tempDir.delete(recursive: true));

      final handler = BackupHandler(
        sourceDb,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      final backupFile = await handler.createEncryptedBackup(
        password: 'correct-horse-battery-staple',
        outputDirectory: tempDir,
      );
      expect(backupFile.existsSync(), isTrue);
      expect(backupFile.path.endsWith('.nookbackup'), isTrue);

      // Verify raw file does not contain plaintext note title.
      final rawText = await backupFile.readAsString();
      expect(rawText, isNot(contains('Quantum Notes')));
      expect(rawText, contains('v2\$argon2id\$'));

      // Restore into a brand-new empty DB ("wiped").
      final targetDb = createTestDatabase();
      addTearDown(targetDb.close);
      final targetHandler = BackupHandler(
        targetDb,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );

      final restoredCount = await targetHandler.restoreEncryptedBackup(
        backupFile: backupFile,
        password: 'correct-horse-battery-staple',
      );
      expect(restoredCount, 1);

      final restoredNotes = await NoteRepository(targetDb).getAllNotes();
      expect(restoredNotes, hasLength(1));
      expect(restoredNotes.first.title, 'Quantum Notes');
      expect(restoredNotes.first.notebookId, nb.id);

      final restoredItems =
          await ChecklistItemRepository(targetDb).getItems(note.id);
      expect(restoredItems.map((i) => i.itemText), ['Verify Argon2id']);

      final restoredTags =
          await TagRepository(targetDb).getTagsForNote(note.id);
      expect(restoredTags.map((t) => t.name), ['security']);
    });

    test(
        'wrong password throws BackupAuthenticationException without mutating DB',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      await NoteRepository(db).createNote(
        title: 'Existing Note',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );

      final tempDir = await Directory.systemTemp.createTemp('nook_backup_auth');
      addTearDown(() => tempDir.delete(recursive: true));

      final handler = BackupHandler(
        db,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      final backupFile = await handler.createEncryptedBackup(
        password: 'right-password',
        outputDirectory: tempDir,
      );

      final targetDb = createTestDatabase();
      addTearDown(targetDb.close);
      final targetHandler = BackupHandler(
        targetDb,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );

      await expectLater(
        () => targetHandler.restoreEncryptedBackup(
          backupFile: backupFile,
          password: 'wrong-password',
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );
      expect(await NoteRepository(targetDb).getAllNotes(), isEmpty);
    });

    testWidgets('BackupScreen renders create and restore controls',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: BackupScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Encrypted Backup'), findsOneWidget);
      expect(find.text('Create .nookbackup'), findsOneWidget);
      expect(find.text('Restore .nookbackup'), findsOneWidget);
    });
  });
}
