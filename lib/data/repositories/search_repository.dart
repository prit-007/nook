import 'package:drift/drift.dart';

import '../../core/providers/talker_provider.dart';
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

    final sanitized = _sanitizeFts5Query(query);
    if (sanitized.isEmpty) return [];

    final ftsResults = await _db.customSelect(
      'SELECT id FROM notes_fts WHERE notes_fts MATCH ?',
      variables: [Variable.withString('$sanitized*')],
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

    final results = await queryBuilder.get();
    nookLog(
      NookLogKey.database,
      'Search "${query.trim()}" → ${results.length} results',
      LogLevel.debug,
    );
    return results;
  }

  /// Strips FTS5 special characters and operators from user input to prevent
  /// query injection / parse errors.
  static String _sanitizeFts5Query(String input) {
    return input
        .replaceAll(RegExp(r'["()*]'), ' ')
        .replaceAll(RegExp(r'\b(NOT|AND|OR|NEAR)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
