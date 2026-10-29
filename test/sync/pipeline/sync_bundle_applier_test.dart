import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/sync_log_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/pipeline/sync_bundle_applier.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

void main() {
  group('SyncBundleApplier', () {
    late AppDatabase db;
    late Directory tempDir;
    late NoteRepository noteRepo;
    late AttachmentRepository attachmentRepo;
    late TagRepository tagRepo;
    late NotebookRepository notebookRepo;
    late SyncLogRepository syncLog;
    late SyncBundleApplier applier;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('nook_applier_test_');
      noteRepo = NoteRepository(db);
      attachmentRepo = AttachmentRepository(db);
      tagRepo = TagRepository(db);
      notebookRepo = NotebookRepository(db);
      syncLog = SyncLogRepository(db);

      applier = SyncBundleApplier(
        db: db,
        noteRepo: noteRepo,
        attachmentRepo: attachmentRepo,
        tagRepo: tagRepo,
        notebookRepo: notebookRepo,
        syncLog: syncLog,
        restoreDirectoryOverride: tempDir,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'applies new incoming note with attachments, tags, and checklist items',
        () async {
      final imageBytes = Uint8List.fromList([10, 20, 30, 40]);
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'remote-device-1',
        senderDeviceName: 'Remote MacBook',
        sentAt: DateTime.utc(2026, 10, 29),
        notes: [
          SyncNoteEntry(
            noteId: 'remote-note-1',
            syncVersion: 1,
            updatedAt: DateTime.utc(2026, 10, 29, 10),
            deviceOriginId: 'remote-device-1',
            noteFields: {
              'title': 'Remote Meeting Notes',
              'type': 'mixed',
              'plainText': 'Meeting discussion points',
              'deltaContent': jsonEncode({
                'document': {
                  'type': 'page',
                  'children': [
                    {
                      'type': 'image',
                      'data': {'url': '/old/remote/path.png'},
                    },
                  ],
                },
              }),
              'tags': [
                {'id': 'tag-1', 'name': 'work', 'colorSeed': '#2196F3'}
              ],
            },
            checklistItems: [
              {
                'id': 'chk-1',
                'itemText': 'Follow up with design',
                'checked': false,
                'sortOrder': 0,
              }
            ],
            attachments: [
              SyncAttachment(
                id: 'att-remote-1',
                type: 'image',
                sortOrder: 0,
                bytes: imageBytes,
                filePath: '/old/remote/path.png',
              ),
            ],
          ),
        ],
      );

      final progressEvents = <String>[];
      final result = await applier.apply(
        bundle: bundle,
        localDeviceName: 'Local Phone',
        onProgress: (applied, total, title) {
          progressEvents.add('$applied/$total: $title');
        },
      );

      expect(result.receivedNoteIds, ['remote-note-1']);
      expect(result.rejectedNoteIds, isEmpty);
      expect(result.conflicts, isEmpty);
      expect(result.ack.receivedNoteIds, ['remote-note-1']);
      expect(progressEvents, ['1/1: Remote Meeting Notes']);

      // Verify Note exists in DB
      final savedNote = await noteRepo.getNoteById('remote-note-1');
      expect(savedNote, isNotNull);
      expect(savedNote!.title, 'Remote Meeting Notes');
      expect(savedNote.plainText, 'Meeting discussion points');

      // Verify Attachment restored via CAS
      final savedAtts = await attachmentRepo.getAllForNote('remote-note-1');
      expect(savedAtts.length, 1);
      expect(savedAtts.first.filePath, contains('/media/cas/'));
      expect(File(savedAtts.first.filePath).existsSync(), isTrue);
      expect(
        await File(savedAtts.first.filePath).readAsBytes(),
        orderedEquals(imageBytes),
      );

      // Verify Delta path was rewritten to local CAS path
      expect(savedNote.deltaContent, isNot(contains('/old/remote/path.png')));
      expect(savedNote.deltaContent, contains(savedAtts.first.filePath));

      // Verify Tag was created and assigned
      final tags = await tagRepo.getTagsForNote('remote-note-1');
      expect(tags.length, 1);
      expect(tags.first.name, 'work');

      // Verify Checklist items restored
      final chkItems = await (db.select(db.checklistItems)
            ..where((t) => t.noteId.equals('remote-note-1')))
          .get();
      expect(chkItems.length, 1);
      expect(chkItems.first.itemText, 'Follow up with design');
    });

    test('detects conflict when note was modified on both sides', () async {
      // Create local note with an earlier timestamp
      final localNote = await noteRepo.createNote(
        id: 'conflict-note-1',
        title: 'Local Version',
        type: NoteType.text,
        deviceOriginId: 'local-device',
      );
      await noteRepo.updateContent(
        localNote.id,
        plainText: 'Local text',
        updatedAt: DateTime.utc(2026, 10, 29, 8),
      );

      // Incoming note from different origin with same syncVersion
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'remote-device',
        senderDeviceName: 'Remote Phone',
        sentAt: DateTime.utc(2026, 10, 29),
        notes: [
          SyncNoteEntry(
            noteId: 'conflict-note-1',
            syncVersion: 0,
            updatedAt: DateTime.utc(2026, 10, 29, 11),
            deviceOriginId: 'remote-device',
            noteFields: {
              'title': 'Remote Version',
              'type': 'text',
              'plainText': 'Remote edited text',
            },
          ),
        ],
      );

      final result = await applier.apply(
        bundle: bundle,
        localDeviceName: 'Local Phone',
      );

      expect(result.conflicts.length, 1);
      expect(result.conflicts.first.incoming.noteId, 'conflict-note-1');
      expect(result.conflicts.first.remoteDeviceName, 'Remote Phone');
      expect(result.receivedNoteIds, isEmpty);
      expect(result.rejectedNoteIds, isEmpty);
    });
  });
}
