import 'dart:io';

import 'package:drift/drift.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/notes.dart';
import '../protocol/sync_bundle.dart';

/// Extracts note records, attachments, tags, checklist items, and CAS hashes
/// from Drift and builds a cryptographically integral [SyncBundle].
class SyncBundlePacker {
  SyncBundlePacker({
    required this.db,
    NoteRepository? noteRepo,
    AttachmentRepository? attachmentRepo,
    TagRepository? tagRepo,
    NotebookRepository? notebookRepo,
  })  : noteRepo = noteRepo ?? NoteRepository(db),
        attachmentRepo = attachmentRepo ?? AttachmentRepository(db),
        tagRepo = tagRepo ?? TagRepository(db),
        notebookRepo = notebookRepo ?? NotebookRepository(db);

  final AppDatabase db;
  final NoteRepository noteRepo;
  final AttachmentRepository attachmentRepo;
  final TagRepository tagRepo;
  final NotebookRepository notebookRepo;

  /// Serializes the notes designated by [noteIds] into a [SyncBundle].
  Future<SyncBundle> pack({
    required List<String> noteIds,
    required String senderDeviceId,
    required String senderDeviceName,
    void Function(int packedCount, int totalCount, String currentTitle)?
        onProgress,
  }) async {
    // Pre-fetch tags for all requested notes in a single query
    final tagMap = await tagRepo.getTagsForNotes(noteIds);
    final entries = <SyncNoteEntry>[];

    for (final noteId in noteIds) {
      final note = await noteRepo.getNoteById(noteId);
      if (note == null) continue;

      // Pack attachments and read their on-disk bytes
      final attachments = <SyncAttachment>[];
      final attachmentRows = await attachmentRepo.getAllForNote(noteId);
      for (final row in attachmentRows) {
        final file = File(row.filePath);
        if (await file.exists()) {
          Uint8List? thumbBytes;
          final thumbPath = row.thumbnailPath;
          if (thumbPath != null && thumbPath.isNotEmpty) {
            final thumbFile = File(thumbPath);
            if (await thumbFile.exists()) {
              thumbBytes = await thumbFile.readAsBytes();
            }
          }
          attachments.add(SyncAttachment(
            id: row.id,
            type: row.type.name,
            sortOrder: row.sortOrder,
            bytes: await file.readAsBytes(),
            filePath: row.filePath,
            thumbnailPath: thumbPath,
            thumbnailBytes: thumbBytes,
          ));
        } else {
          nookLog(
            NookLogKey.sync,
            'Attachment ${row.id} missing on disk: ${row.filePath}',
            LogLevel.warning,
          );
        }
      }

      // Pack checklist items for checklist or mixed notes
      List<Map<String, dynamic>>? checklistItems;
      if (note.type == NoteType.checklist || note.type == NoteType.mixed) {
        final items = await (db.select(db.checklistItems)
              ..where((t) => t.noteId.equals(noteId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
        if (items.isNotEmpty) {
          checklistItems = items
              .map((item) => {
                    'id': item.id,
                    'itemText': item.itemText,
                    'checked': item.checked,
                    'sortOrder': item.sortOrder,
                  })
              .toList();
        }
      }

      // Pack tags for this note
      final noteTags = tagMap[noteId];
      final tagsPayload = noteTags
          ?.map((t) => {
                'id': t.id,
                'name': t.name,
                'colorSeed': t.colorSeed,
              })
          .toList();

      // Pack notebook metadata so the receiver can create/link properly
      String? notebookName;
      String? notebookColorSeed;
      String? notebookIcon;
      if (note.notebookId != null) {
        final notebook = await notebookRepo.getNotebookById(note.notebookId!);
        if (notebook != null) {
          notebookName = notebook.name;
          notebookColorSeed = notebook.colorSeed;
          notebookIcon = notebook.icon;
        }
      }

      entries.add(SyncNoteEntry(
        noteId: note.id,
        syncVersion: note.syncVersion,
        updatedAt: note.updatedAt,
        deviceOriginId: note.deviceOriginId,
        noteFields: {
          'title': note.title,
          'type': note.type.name,
          'colorSeed': note.colorSeed,
          'pinned': note.pinned,
          'locked': note.locked,
          'notebookId': note.notebookId,
          'deltaContent': note.deltaContent,
          'plainText': note.plainText,
          'coverImagePath': note.coverImagePath,
          'createdAt': note.createdAt.millisecondsSinceEpoch,
          if (tagsPayload != null && tagsPayload.isNotEmpty)
            'tags': tagsPayload,
          if (notebookName != null) 'notebookName': notebookName,
          if (notebookColorSeed != null) 'notebookColorSeed': notebookColorSeed,
          if (notebookIcon != null) 'notebookIcon': notebookIcon,
        },
        checklistItems: checklistItems != null && checklistItems.isNotEmpty
            ? checklistItems
            : null,
        attachments: attachments.isEmpty ? null : attachments,
      ));

      onProgress?.call(entries.length, noteIds.length, note.title);
    }

    return SyncBundle(
      protocolVersion: '1.0',
      senderDeviceId: senderDeviceId,
      senderDeviceName: senderDeviceName,
      sentAt: DateTime.now(),
      notes: entries,
    );
  }
}
