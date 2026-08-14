import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/talker_provider.dart';
import '../database.dart';
import '../tables/attachments.dart';

/// Repository for Attachments table operations.
class AttachmentRepository {
  AttachmentRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Adds an image attachment for a note. Pass [id] to preserve a remote
  /// attachment id during sync; otherwise a fresh UUID is generated.
  Future<String> addImage({
    required String noteId,
    required String filePath,
    String? id,
    String? thumbnailPath,
    int sortOrder = 0,
  }) async {
    final attachmentId = id ?? _uuid.v4();
    await _db.into(_db.attachments).insert(
          AttachmentsCompanion.insert(
            id: Value(attachmentId),
            noteId: noteId,
            type: AttachmentType.image,
            filePath: filePath,
            thumbnailPath: Value(thumbnailPath),
            sortOrder: Value(sortOrder),
          ),
        );
    nookLog(NookLogKey.database, 'Image attachment added: $attachmentId',
        LogLevel.debug);
    return attachmentId;
  }

  /// Adds a doodle layer attachment for a note. Uses an upsert so a re-sync
  /// of an already-applied note cannot crash on a primary-key collision.
  Future<String> addDoodle({
    required String noteId,
    required String filePath,
    String? id,
    int sortOrder = 0,
  }) async {
    final attachmentId = id ?? _uuid.v4();
    await _db.into(_db.attachments).insertOnConflictUpdate(
          AttachmentsCompanion.insert(
            id: Value(attachmentId),
            noteId: noteId,
            type: AttachmentType.doodleLayer,
            filePath: filePath,
            sortOrder: Value(sortOrder),
          ),
        );
    nookLog(NookLogKey.database, 'Doodle layer saved: $attachmentId',
        LogLevel.debug);
    return attachmentId;
  }

  /// Updates the sidecar file path of an attachment.
  Future<void> updateFilePath(String id, String filePath) async {
    await (_db.update(_db.attachments)..where((a) => a.id.equals(id)))
        .write(AttachmentsCompanion(filePath: Value(filePath)));
  }

  /// Returns the attachment whose full-size file path matches [filePath], or null.
  Future<Attachment?> getByFilePath(String filePath) {
    return (_db.select(_db.attachments)
          ..where((a) => a.filePath.equals(filePath)))
        .getSingleOrNull();
  }

  /// Deletes an attachment row and any files it references on disk.
  Future<void> deleteAttachmentWithFiles(Attachment attachment) async {
    final paths = <String>[
      if (attachment.filePath.isNotEmpty) attachment.filePath,
      if (attachment.thumbnailPath != null &&
          attachment.thumbnailPath!.isNotEmpty)
        attachment.thumbnailPath!,
    ];
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort — file may already be gone.
      }
    }
    await deleteImage(attachment.id);
  }

  /// Returns all attachments (images + doodle layers) for a note, ordered by sortOrder.
  Future<List<Attachment>> getAllForNote(String noteId) {
    return (_db.select(_db.attachments)
          ..where((a) => a.noteId.equals(noteId))
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .get();
  }

  /// Returns all image attachments for a note, ordered by sortOrder.
  Future<List<Attachment>> getImagesForNote(String noteId) {
    return (_db.select(_db.attachments)
          ..where((a) =>
              a.noteId.equals(noteId) &
              a.type.equalsValue(AttachmentType.image))
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .get();
  }

  /// Returns a single attachment by id.
  Future<Attachment?> getById(String id) {
    return (_db.select(_db.attachments)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Deletes an attachment by id.
  Future<void> deleteImage(String id) async {
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
    nookLog(NookLogKey.database, 'Attachment deleted: $id', LogLevel.debug);
  }

  /// Deletes all attachments (images + doodle layers) for a note.
  Future<void> deleteAllForNote(String noteId) async {
    await (_db.delete(_db.attachments)..where((a) => a.noteId.equals(noteId)))
        .go();
  }

  /// Updates the thumbnail path for an attachment.
  Future<void> updateThumbnail(String id, String? thumbnailPath) async {
    await (_db.update(_db.attachments)..where((a) => a.id.equals(id)))
        .write(AttachmentsCompanion(thumbnailPath: Value(thumbnailPath)));
  }

  /// Reorders images by updating sort orders atomically.
  Future<void> reorderImages(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.attachments)
              ..where((a) => a.id.equals(orderedIds[i])))
            .write(AttachmentsCompanion(sortOrder: Value(i)));
      }
    });
  }
}
