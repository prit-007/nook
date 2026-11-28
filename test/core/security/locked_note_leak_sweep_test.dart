import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/home_widget_service.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/reminder_repository.dart';
import 'package:nook/data/repositories/revision_repository.dart';
import 'package:nook/data/repositories/search_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/data/tables/reminders.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';
import 'package:nook/features/home/widgets/note_banner_card.dart';
import 'package:nook/features/home/widgets/note_card.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';
import 'package:nook/features/settings/widgets/bulk_export.dart';
import 'package:nook/sync/pipeline/sync_bundle_packer.dart';

class _RecordingHomeWidgetBridge implements HomeWidgetBridge {
  final Map<String, Object?> saved = {};

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) async {
    saved[id] = data;
    return true;
  }

  @override
  Future<bool?> updateWidget({
    String? name,
    String? androidName,
    String? iOSName,
    String? qualifiedAndroidName,
  }) async =>
      true;

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;

  @override
  Stream<Uri?> get widgetClicked => const Stream.empty();
}

class _RecordingReminderScheduler implements ReminderScheduler {
  String? lastTitle;
  String? lastBody;

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<void> cancelForNote(String noteId) async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required ReminderRepeat repeat,
  }) async {
    lastTitle = title;
    lastBody = body;
  }
}

void main() {
  group('Locked-note leak sweep (Phase 1.2)', () {
    test('1 & 9. FTS index and SearchRepository exclude locked notes',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);
      final searchRepo = SearchRepository(db);

      final note = await noteRepo.createNote(
        title: 'Secret Nuclear Codes',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Launch sequence alpha-99',
      );
      await noteRepo.updateNote(note.id, locked: true);

      final ftsRows = await db.customSelect(
        'SELECT id FROM notes_fts WHERE id = ?',
        variables: [Variable.withString(note.id)],
      ).get();
      expect(ftsRows, isEmpty);

      final hits = await searchRepo.searchNotes('Nuclear');
      expect(hits, isEmpty);
    });

    testWidgets(
        '2 & 3. NoteCard, NoteBannerCard, NoteDoodleCard hide locked previews and thumbnails',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final lockedText = Note(
        id: 'locked-1',
        title: 'Private Diary',
        type: NoteType.text,
        plainText: 'Top secret body text',
        pinned: false,
        locked: true,
        archived: false,
        deleted: false,
        syncVersion: 1,
        deviceOriginId: 'dev-1',
        fontStyle: 'auto',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final lockedDoodle = Note(
        id: 'locked-2',
        title: 'Secret Sketch',
        type: NoteType.doodle,
        pinned: false,
        locked: true,
        archived: false,
        deleted: false,
        syncVersion: 1,
        deviceOriginId: 'dev-1',
        fontStyle: 'auto',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: NoteCard(
                      note: lockedText,
                      preloadedMetadata: const NoteCardMetadata(),
                    ),
                  ),
                  Expanded(
                    child: NoteBannerCard(
                      note: lockedText,
                      preloadedMetadata: const NoteCardMetadata(),
                    ),
                  ),
                  Expanded(
                    child: NoteDoodleCard(
                      note: lockedDoodle,
                      preloadedMetadata: const NoteCardMetadata(
                        thumbnailPath: '/nonexistent/secret_thumb.png',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Top secret body text'), findsNothing);
    });

    test('4. HomeWidgetService.syncPinnedNotes excludes locked notes',
        () async {
      final bridge = _RecordingHomeWidgetBridge();
      final service = HomeWidgetService(bridge: bridge);
      final lockedNote = Note(
        id: 'locked-pin',
        title: 'Secret Pinned Title',
        type: NoteType.text,
        plainText: 'Secret pinned body',
        pinned: true,
        locked: true,
        archived: false,
        deleted: false,
        syncVersion: 1,
        deviceOriginId: 'dev-1',
        fontStyle: 'auto',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await service.syncPinnedNotes([lockedNote]);
      expect(bridge.saved['pinned_count'], 0);
      expect(bridge.saved['pinned_notes_json'], '[]');
    });

    test('5. ReminderRepository redacts notification text for locked notes',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);
      final scheduler = _RecordingReminderScheduler();
      final reminderRepo = ReminderRepository(db, scheduler: scheduler);

      final note = await noteRepo.createNote(
        title: 'Secret Medical Result',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.updateNote(note.id, locked: true);

      await reminderRepo.create(
        noteId: note.id,
        title: 'Secret Medical Result',
        fireAt: DateTime(2026, 12, 1, 9, 0),
      );

      expect(scheduler.lastTitle, isNot(contains('Medical')));
      expect(scheduler.lastBody, isNot(contains('Medical')));
    });

    test('6. RevisionRepository skips snapshots for locked notes', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);
      final revRepo = RevisionRepository(db);

      final note = await noteRepo.createNote(
        title: 'Locked Draft',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.updateNote(note.id, locked: true);

      final rev = await revRepo.maybeSnapshot(
        noteId: note.id,
        title: 'Locked Draft',
        deltaContent: '{}',
        plainText: 'Sensitive text',
        source: RevisionSource.manual,
      );
      expect(rev, isNull);
      expect(await revRepo.listForNote(note.id), isEmpty);
    });

    test('7. BulkExporter excludes locked notes from export archive', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);
      final tempDir = await Directory.systemTemp.createTemp('nook_export_test');
      addTearDown(() => tempDir.delete(recursive: true));

      await noteRepo.createNote(
        title: 'Public Note',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Public content',
      );
      final secret = await noteRepo.createNote(
        title: 'Locked Note',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Should never export',
      );
      await noteRepo.updateNote(secret.id, locked: true);

      final exporter = BulkExporter(
        noteRepository: noteRepo,
        checklistItemRepository: ChecklistItemRepository(db),
        attachmentRepository: AttachmentRepository(db),
        outputDirectory: tempDir,
      );
      final zipPath = await exporter.exportAll(BulkExportFormat.markdown);
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final noteFiles = archive.files
          .where((f) => f.name.startsWith('notes/') && f.name.endsWith('.md'))
          .toList();
      expect(noteFiles, hasLength(1));
      final exportedContent = String.fromCharCodes(noteFiles.first.content);
      expect(exportedContent, contains('Public content'));
      expect(exportedContent, isNot(contains('Should never export')));
    });

    test(
        '8. SyncBundlePacker supports excluding locked notes via includeLocked=false',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);
      final packer = SyncBundlePacker(db: db);

      final pub = await noteRepo.createNote(
        title: 'Public',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      final sec = await noteRepo.createNote(
        title: 'Secret',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.updateNote(sec.id, locked: true);

      final bundle = await packer.pack(
        noteIds: [pub.id, sec.id],
        senderDeviceId: 'dev-1',
        senderDeviceName: 'Test',
        includeLocked: false,
      );
      expect(bundle.notes.map((n) => n.noteId), [pub.id]);
    });
  });
}
