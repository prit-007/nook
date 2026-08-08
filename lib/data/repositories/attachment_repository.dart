import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';
import '../tables/attachments.dart';

/// Repository for Attachments table operations.
class AttachmentRepository {
  AttachmentRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Adds an image attachment for a note.
  Future<String> addImage({
    required String noteId,
    required String filePath,
    String? thumbnailPath,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.attachments).insert(
          AttachmentsCompanion.insert(
            id: Value(id),
            noteId: noteId,
            type: AttachmentType.image,
            filePath: filePath,
            thumbnailPath: Value(thumbnailPath),
            sortOrder: Value(sortOrder),
          ),
        );
    return id;
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
    await (_db.delete(_db.attachments)
          ..where((a) => a.noteId.equals(noteId)))
        .go();
  }

  /// Updates the thumbnail path for an attachment.
  Future<void> updateThumbnail(String id, String? thumbnailPath) async {
    await (_db.update(_db.attachments)..where((a) => a.id.equals(id)))
        .write(AttachmentsCompanion(thumbnailPath: Value(thumbnailPath)));
  }

  /// Reorders images by updating sort orders.
  Future<void> reorderImages(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.attachments)
            ..where((a) => a.id.equals(orderedIds[i])))
          .write(AttachmentsCompanion(sortOrder: Value(i)));
    }
  }
}
