import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/providers/vault_stats_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NoteRepository noteRepo;
  late AttachmentRepository attachmentRepo;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    attachmentRepo = AttachmentRepository(db);
    tempDir = await Directory.systemTemp.createTemp('vault_stats_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
      'vaultStatsProvider accurately counts live notes, attachments, and file bytes',
      () async {
    // 1. Create a live note
    final note = await noteRepo.createNote(
      title: 'Test Note',
      type: NoteType.text,
      deviceOriginId: 'test-device',
    );

    // 2. Create physical files for attachment and thumbnail
    final doodleFile = File('${tempDir.path}/test_doodle.json');
    await doodleFile.writeAsString('{"strokes": [1, 2, 3, 4, 5]}');
    final thumbFile = File('${tempDir.path}/test_thumb.png');
    await thumbFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);

    // 3. Add an active attachment with thumbnail
    final attId = await attachmentRepo.addDoodle(
      noteId: note.id,
      filePath: doodleFile.path,
    );
    await attachmentRepo.updateThumbnail(attId, thumbFile.path);

    // 4. Add a deleted attachment (should be excluded from active count)
    final deletedAttId = await attachmentRepo.addImage(
      noteId: note.id,
      filePath: '${tempDir.path}/deleted.png',
    );
    await attachmentRepo.softDelete(deletedAttId);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    final stats = await container.read(vaultStatsProvider.future);

    expect(stats.noteCount, 1);
    expect(stats.attachmentCount, 1);
    final expectedBytes = await doodleFile.length() + await thumbFile.length();
    expect(stats.mediaBytes, expectedBytes);
    expect(stats.totalBytes, greaterThanOrEqualTo(expectedBytes));
  });

  test('formatBytes formats units properly', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(1024), '1.0 kB');
    expect(formatBytes(1536), '1.5 kB');
    expect(formatBytes(1024 * 1024), '1.0 MB');
  });
}
