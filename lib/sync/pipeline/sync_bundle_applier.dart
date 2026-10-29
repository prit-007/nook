import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/database.dart';
import '../../data/media_cas_storage.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/sync_log_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../media_path_rewriter.dart';
import '../protocol/merge_resolver.dart';
import '../protocol/sync_bundle.dart';
import '../sync_orchestrator.dart' show SyncConflict;

/// Encapsulates the outcome of processing and applying an incoming [SyncBundle].
class SyncApplyResult {
  SyncApplyResult({
    required this.receivedNoteIds,
    required this.rejectedNoteIds,
    required this.conflicts,
  }) : ack = SyncAck(
          receivedNoteIds: receivedNoteIds,
          rejectedNoteIds: rejectedNoteIds,
        );

  final List<String> receivedNoteIds;
  final List<String> rejectedNoteIds;
  final List<SyncConflict> conflicts;
  final SyncAck ack;

  int get appliedNotesCount => receivedNoteIds.length;
}

/// Unpacks an incoming [SyncBundle], resolves merges, restores media attachments
/// with Content-Addressed Storage (CAS) deduplication, rewrites document deltas,
/// and applies changes to Drift atomically.
class SyncBundleApplier {
  SyncBundleApplier({
    required this.db,
    NoteRepository? noteRepo,
    NotebookRepository? notebookRepo,
    AttachmentRepository? attachmentRepo,
    TagRepository? tagRepo,
    SyncLogRepository? syncLog,
    MergeResolver? resolver,
    this.restoreDirectoryOverride,
  })  : noteRepo = noteRepo ?? NoteRepository(db),
        notebookRepo = notebookRepo ?? NotebookRepository(db),
        attachmentRepo = attachmentRepo ?? AttachmentRepository(db),
        tagRepo = tagRepo ?? TagRepository(db),
        syncLog = syncLog ?? SyncLogRepository(db),
        resolver = resolver ??
            MergeResolver(
              noteRepo ?? NoteRepository(db),
              notebookRepo ?? NotebookRepository(db),
            );

  final AppDatabase db;
  final NoteRepository noteRepo;
  final NotebookRepository notebookRepo;
  final AttachmentRepository attachmentRepo;
  final TagRepository tagRepo;
  final SyncLogRepository syncLog;
  final MergeResolver resolver;
  final Directory? restoreDirectoryOverride;

  Future<Directory> _resolveMediaDirectory() async {
    if (restoreDirectoryOverride != null) {
      await restoreDirectoryOverride!.create(recursive: true);
      return restoreDirectoryOverride!;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Evaluates and applies all notes within [bundle] to local storage.
  Future<SyncApplyResult> apply({
    required SyncBundle bundle,
    required String localDeviceName,
    void Function(int appliedCount, int totalCount, String currentTitle)?
        onProgress,
  }) async {
    final receivedIds = <String>[];
    final rejectedIds = <String>[];
    final conflicts = <SyncConflict>[];

    final hasAnyAttachments = bundle.notes
        .any((n) => n.attachments != null && n.attachments!.isNotEmpty);
    final baseDir = hasAnyAttachments ? await _resolveMediaDirectory() : null;

    for (var i = 0; i < bundle.notes.length; i++) {
      final entry = bundle.notes[i];
      final title = entry.noteFields['title'] as String? ?? 'Untitled';
      final action = await resolver.resolveIncoming(entry);

      switch (action) {
        case MergeAction.insertAsNew:
        case MergeAction.overwrite:
          nookLog(
            NookLogKey.sync,
            'Incoming note ${entry.noteId} ($title) — '
            '${action == MergeAction.insertAsNew ? 'inserting' : 'overwriting'}',
            LogLevel.info,
          );

          await resolver.applyIncoming(entry);
          if (entry.attachments != null && entry.attachments!.isNotEmpty) {
            await restoreAttachments(
              entry: entry,
              baseDir: baseDir,
            );
          }
          await _restoreTags(entry: entry);
          await _restoreChecklistItems(entry: entry);

          receivedIds.add(entry.noteId);
          await syncLog.logReceived(
            deviceId: bundle.senderDeviceId,
            deviceName: bundle.senderDeviceName,
            noteId: entry.noteId,
          );
          break;

        case MergeAction.promptUser:
          nookLog(
            NookLogKey.sync,
            'Conflict detected for note ${entry.noteId} ($title)',
            LogLevel.warning,
          );
          conflicts.add(SyncConflict(
            incoming: entry,
            localDeviceName: localDeviceName,
            remoteDeviceName: bundle.senderDeviceName,
          ));
          break;

        case MergeAction.ignore:
          nookLog(
            NookLogKey.sync,
            'Incoming note ${entry.noteId} ($title) ignored (older or deleted)',
            LogLevel.info,
          );
          rejectedIds.add(entry.noteId);
          break;
      }

      onProgress?.call(receivedIds.length, bundle.notes.length, title);
    }

    return SyncApplyResult(
      receivedNoteIds: receivedIds,
      rejectedNoteIds: rejectedIds,
      conflicts: conflicts,
    );
  }

  /// Restores attachments for a single note entry using CAS storage and rewrites deltas.
  Future<void> restoreAttachments({
    required SyncNoteEntry entry,
    Directory? baseDir,
  }) async {
    final attachments = entry.attachments;
    if (attachments == null || attachments.isEmpty) return;

    final note = await noteRepo.getNoteById(entry.noteId);
    if (note == null) return;

    final effectiveBaseDir = baseDir ?? await _resolveMediaDirectory();

    await attachmentRepo.deleteAllForNote(note.id);
    final restored = <RestoredMedia>[];

    for (final att in attachments) {
      final restoredId = await _resolveSyncedAttachmentId(att.id);
      final isDoodle = att.type == 'doodleLayer';

      if (isDoodle && att.id.isNotEmpty) {
        // Canonical DoodleStorage layout: sidecar + thumbnail at documents root
        await File('${effectiveBaseDir.path}/$restoredId.doodle.json')
            .writeAsBytes(att.bytes, flush: true);
        final thumbBytes = att.thumbnailBytes;
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          await File('${effectiveBaseDir.path}/${restoredId}_thumb.png')
              .writeAsBytes(thumbBytes, flush: true);
        }
        await attachmentRepo.addDoodle(
          noteId: note.id,
          filePath: '${effectiveBaseDir.path}/$restoredId.doodle.json',
          id: restoredId,
          sortOrder: att.sortOrder,
        );
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          await attachmentRepo.updateThumbnail(
            restoredId,
            '${effectiveBaseDir.path}/${restoredId}_thumb.png',
          );
        }
        restored.add(RestoredMedia(
          attachmentId: att.id,
          newAttachmentId: restoredId != att.id ? restoredId : null,
          originalFilePath: att.filePath,
          originalThumbnailPath: att.thumbnailPath,
          newFilePath: '${effectiveBaseDir.path}/$restoredId.doodle.json',
          newThumbnailPath: '${effectiveBaseDir.path}/${restoredId}_thumb.png',
        ));
        continue;
      }

      // Content-addressed storage (CAS) deduplicates identical media
      final ext = att.type == 'doodleLayer' ? 'drawn' : 'img';
      final casStorage = MediaCasStorage(baseDirectory: effectiveBaseDir);
      final storedFile = await casStorage.storeMedia(att.bytes, extension: ext);
      final filePath = storedFile.path;

      String? thumbPath;
      final thumbBytes = att.thumbnailBytes;
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        final storedThumb =
            await casStorage.storeMedia(thumbBytes, extension: '$ext.thumb');
        thumbPath = storedThumb.path;
      }

      if (att.type == 'doodleLayer') {
        await attachmentRepo.addDoodle(
          noteId: note.id,
          filePath: filePath,
          id: restoredId,
          sortOrder: att.sortOrder,
        );
      } else {
        await attachmentRepo.addImage(
          noteId: note.id,
          filePath: filePath,
          id: restoredId,
          thumbnailPath: thumbPath,
          sortOrder: att.sortOrder,
        );
      }

      restored.add(RestoredMedia(
        attachmentId: att.id,
        newAttachmentId: restoredId != att.id ? restoredId : null,
        originalFilePath: att.filePath,
        originalThumbnailPath: att.thumbnailPath,
        newFilePath: filePath,
        newThumbnailPath: thumbPath,
      ));
    }

    // Re-point the note's delta at the local restored CAS files
    final originalDelta = note.deltaContent ?? '';
    final rewrittenDelta = rewriteMediaPaths(originalDelta, restored);
    if (rewrittenDelta != originalDelta) {
      await noteRepo.updateContent(
        note.id,
        deltaContent: rewrittenDelta,
        plainText: note.plainText,
        updatedAt: note.updatedAt,
      );
    }
  }

  Future<String> _resolveSyncedAttachmentId(String incomingId) async {
    if (incomingId.isEmpty) return const Uuid().v4();
    final existing = await attachmentRepo.getById(incomingId);
    if (existing == null) return incomingId;
    return const Uuid().v4();
  }

  Future<void> _restoreTags({required SyncNoteEntry entry}) async {
    final rawTags = entry.noteFields['tags'];
    if (rawTags is! List) return;

    final tagIds = <String>[];
    for (final raw in rawTags) {
      if (raw is! Map) continue;
      final tagId = raw['id'] as String?;
      final tagName = raw['name'] as String?;
      final tagColor = raw['colorSeed'] as String?;
      if (tagId == null || tagId.isEmpty) continue;

      final existing = await tagRepo.getTagById(tagId);
      if (existing == null) {
        await tagRepo.createTagWithId(
          tagId,
          name:
              (tagName != null && tagName.isNotEmpty) ? tagName : 'Synced Tag',
          colorSeed: tagColor ?? '#808080',
        );
      }
      tagIds.add(tagId);
    }

    if (tagIds.isNotEmpty) {
      await noteRepo.updateNoteTags(entry.noteId, tagIds);
    }
  }

  Future<void> _restoreChecklistItems({required SyncNoteEntry entry}) async {
    final items = entry.checklistItems;
    if (items == null || items.isEmpty) return;

    // Replace existing checklist items for this note atomically
    await (db.delete(db.checklistItems)
          ..where((t) => t.noteId.equals(entry.noteId)))
        .go();

    for (final item in items) {
      final itemId = item['id'] as String? ?? const Uuid().v4();
      final itemText = item['itemText'] as String? ?? '';
      final checked = item['checked'] == true;
      final sortOrder = item['sortOrder'] as int? ?? 0;

      await db.into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: Value(itemId),
              noteId: entry.noteId,
              itemText: itemText,
              checked: Value(checked),
              sortOrder: Value(sortOrder),
            ),
          );
    }
  }
}
