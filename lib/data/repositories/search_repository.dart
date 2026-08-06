import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/notes.dart';

/// Repository for full-text search across notes using FTS5.
class SearchRepository {
  SearchRepository(this._db);

  final AppDatabase _db;

  /// Searches notes by title and plainText using FTS5.
  /// Optional [type] filter restricts results to a specific NoteType.
  Future<List<Note>> searchNotes(String query, {NoteType? type}) async {
    if (query.trim().isEmpty) return [];

    // Use FTS5 to find matching IDs
    final ftsResults = await _db.customSelect(
      'SELECT id FROM notes_fts WHERE notes_fts MATCH ?',
      variables: [Variable.withString('$query*')],
    ).get();

    if (ftsResults.isEmpty) return [];

    final ids = ftsResults
        .map((r) => r.read<String>('id'))
        .whereType<String>()
        .toList();

    final queryBuilder = _db.select(_db.notes)
      ..where((t) => t.id.isIn(ids) & t.deleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    if (type != null) {
      queryBuilder.where((t) => t.type.equalsValue(type));
    }

    return queryBuilder.get();
  }
}
