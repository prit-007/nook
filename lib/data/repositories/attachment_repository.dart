import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
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
    return attachmentId;
  }

  /// Updates the sidecar file path of an attachment.
  Future<void> updateFilePath(String id, String filePath) async {
    await (_db.update(_db.attachments)..where((a) => a.id.equals(id)))
        .write(AttachmentsCompanion(filePath: Value(filePath)));
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
