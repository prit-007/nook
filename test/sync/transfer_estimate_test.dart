import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/transfer_estimate.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = createTestDb();
    tempDir = await Directory.systemTemp.createTemp('transfer_estimate_test_');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  group('estimateTransferSize', () {
    test('returns zero for empty note list', () async {
      final estimate = await estimateTransferSize(db, []);
      expect(estimate.totalBytes, 0);
      expect(estimate.noteCount, 0);
      expect(estimate.hasLargeAttachments, isFalse);
    });

    test('estimates notes without attachments from delta content length',
        () async {
      final content = 'x' * 1000;
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-1'),
              type: NoteType.text,
              title: const Value('Test Note'),
              deltaContent: Value(content),
              deviceOriginId: 'device-1',
            ),
          );

      final estimate = await estimateTransferSize(db, ['note-1']);

      expect(estimate.noteCount, 1);
      // The estimate includes the content bytes plus CBOR/protocol overhead.
      expect(estimate.totalBytes, greaterThanOrEqualTo(content.length));
      expect(estimate.hasLargeAttachments, isFalse);
    });

    test('sums attachment file sizes', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-with-attachment'),
              type: NoteType.text,
              title: const Value('Image Note'),
              deviceOriginId: 'device-1',
            ),
          );

      // Create a temp file to act as an attachment.
      final attachmentFile = File('${tempDir.path}/photo.jpg');
      await attachmentFile.writeAsBytes(List.filled(500 * 1024, 0xFF));

      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-1'),
              noteId: 'note-with-attachment',
              type: AttachmentType.image,
              filePath: attachmentFile.path,
            ),
          );

      final estimate = await estimateTransferSize(db, ['note-with-attachment']);

      expect(estimate.noteCount, 1);
      expect(estimate.totalBytes, greaterThanOrEqualTo(500 * 1024));
    });

    test('includes thumbnail bytes in estimate', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-thumb'),
              type: NoteType.text,
              title: const Value('Thumb Note'),
              deviceOriginId: 'device-1',
            ),
          );

      final mainFile = File('${tempDir.path}/photo.jpg');
      await mainFile.writeAsBytes(List.filled(100 * 1024, 0xFF));
      final thumbFile = File('${tempDir.path}/thumb.jpg');
      await thumbFile.writeAsBytes(List.filled(10 * 1024, 0xFF));

      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-thumb'),
              noteId: 'note-thumb',
              type: AttachmentType.image,
              filePath: mainFile.path,
              thumbnailPath: Value(thumbFile.path),
            ),
          );

      final estimate = await estimateTransferSize(db, ['note-thumb']);

      // Should include main + thumbnail (110 KB total minimum).
      expect(estimate.totalBytes, greaterThanOrEqualTo(110 * 1024));
    });

    test('marks hasLargeAttachments for files over 1 MB', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-big'),
              type: NoteType.text,
              title: const Value('Big Note'),
              deviceOriginId: 'device-1',
            ),
          );

      final bigFile = File('${tempDir.path}/big_photo.jpg');
      await bigFile.writeAsBytes(List.filled(2 * 1024 * 1024, 0xFF));

      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-big'),
              noteId: 'note-big',
              type: AttachmentType.image,
              filePath: bigFile.path,
            ),
          );

      final estimate = await estimateTransferSize(db, ['note-big']);
      expect(estimate.hasLargeAttachments, isTrue);
    });

    test('aggregates multiple notes', () async {
      for (var i = 0; i < 3; i++) {
        await db.into(db.notes).insert(
              NotesCompanion.insert(
                id: Value('note-$i'),
                type: NoteType.text,
                title: Value('Note $i'),
                deltaContent: Value('content-$i'),
                deviceOriginId: 'device-1',
              ),
            );
      }

      final estimate =
          await estimateTransferSize(db, ['note-0', 'note-1', 'note-2']);
      expect(estimate.noteCount, 3);
    });

    test('skips missing notes gracefully', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-real'),
              type: NoteType.text,
              title: const Value('Real'),
              deviceOriginId: 'device-1',
            ),
          );

      final estimate = await estimateTransferSize(
          db, ['note-real', 'note-ghost', 'note-phantom']);
      expect(estimate.noteCount, 1);
    });

    test('skips attachments whose files are missing on disk', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-missing-file'),
              type: NoteType.text,
              title: const Value('Missing File'),
              deviceOriginId: 'device-1',
            ),
          );

      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-missing'),
              noteId: 'note-missing-file',
              type: AttachmentType.image,
              filePath: '/nonexistent/path/photo.jpg',
            ),
          );

      // Should not throw — missing files are just skipped in the estimate.
      final estimate = await estimateTransferSize(db, ['note-missing-file']);
      expect(estimate.noteCount, 1);
      // Only note metadata overhead, no attachment bytes.
      expect(estimate.totalBytes, lessThan(1024));
    });

    test('formatBytes produces human-readable strings', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(1024 * 1024 * 1024), '1.0 GB');
    });

    test('estimateDuration returns reasonable durations', () {
      // 1 MB on Wi-Fi (~5 MB/s) -> ~0.2s -> rounds to at least 1s.
      final small = estimateDuration(1024 * 1024);
      expect(small.inSeconds, greaterThanOrEqualTo(1));

      // 100 MB -> ~20s.
      final medium = estimateDuration(100 * 1024 * 1024);
      expect(medium.inSeconds, greaterThanOrEqualTo(10));
      expect(medium.inSeconds, lessThanOrEqualTo(120));
    });
  });
}
