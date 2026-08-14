import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';

/// Repository for Tags and NoteTags table operations.
class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Creates a new tag and returns the inserted row.
  Future<Tag> createTag({
    required String name,
    required String colorSeed,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: colorSeed,
          ),
        );

    nookLog(NookLogKey.database, 'Tag created: $id', LogLevel.debug);

    return (_db.select(_db.tags)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Returns all tags.
  Future<List<Tag>> getAllTags() async {
    return _db.select(_db.tags).get();
  }

  /// Returns a tag by ID, or null if not found.
  Future<Tag?> getTagById(String id) async {
    final results =
        await (_db.select(_db.tags)..where((t) => t.id.equals(id))).get();
    return results.isEmpty ? null : results.first;
  }

  /// Updates a tag's fields.
  Future<void> updateTag(
    String id, {
    String? name,
    String? colorSeed,
  }) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        colorSeed: colorSeed != null ? Value(colorSeed) : const Value.absent(),
      ),
    );
  }

  /// Deletes a tag by ID and all its associations atomically.
  Future<void> deleteTag(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.noteTags)..where((t) => t.tagId.equals(id))).go();
      await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
    });
    nookLog(NookLogKey.database, 'Tag deleted: $id', LogLevel.debug);
  }

  /// Assigns a tag to a note.
  Future<void> assignTagToNote(String noteId, String tagId) async {
    await _db.into(_db.noteTags).insertOnConflictUpdate(
          NoteTagsCompanion.insert(
            noteId: noteId,
            tagId: tagId,
          ),
        );
  }

  /// Removes a tag assignment from a note.
  Future<void> removeTagFromNote(String noteId, String tagId) async {
    await (_db.delete(_db.noteTags)
          ..where((t) => t.noteId.equals(noteId) & t.tagId.equals(tagId)))
        .go();
  }

  /// Returns all tags assigned to a note.
  Future<List<Tag>> getTagsForNote(String noteId) async {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.noteTags,
        _db.noteTags.tagId.equalsExp(_db.tags.id),
      ),
    ])
      ..where(_db.noteTags.noteId.equals(noteId));

    final results = await query.get();
    return results.map((row) => row.readTable(_db.tags)).toList();
  }

  /// Returns all notes that have a given tag.
  Future<List<Note>> getNotesForTag(String tagId) async {
    final query = _db.select(_db.notes).join([
      innerJoin(
        _db.noteTags,
        _db.noteTags.noteId.equalsExp(_db.notes.id),
      ),
    ])
      ..where(
          _db.noteTags.tagId.equals(tagId) & _db.notes.deleted.equals(false));

    final results = await query.get();
    return results.map((row) => row.readTable(_db.notes)).toList();
  }
}
