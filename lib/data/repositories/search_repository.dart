import 'package:drift/drift.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';
import '../tables/notes.dart';

/// Kind of search hit.
enum SearchResultKind { note, checklistItem }

/// A single search hit: either a whole-note match or a checklist-item match
/// attached to its parent note.
class SearchHit {
  const SearchHit({
    required this.note,
    required this.kind,
    this.snippet,
    this.checklistItemId,
  });

  final Note note;
  final SearchResultKind kind;

  /// Short context around a checklist-item match (the item text).
  final String? snippet;
  final String? checklistItemId;
}

/// Grouped results for the search UI.
class GroupedSearchResults {
  const GroupedSearchResults({
    this.notes = const [],
    this.checklistItems = const [],
  });

  /// Unique notes that matched via FTS (title / plainText).
  final List<Note> notes;

  /// Checklist-item hits (parent note + item), ordered by note updatedAt.
  final List<SearchHit> checklistItems;

  bool get isEmpty => notes.isEmpty && checklistItems.isEmpty;

  int get total => notes.length + checklistItems.length;
}

/// Repository for full-text search across notes using FTS5, plus checklist
/// item text search (dual-query — checklist items are not in the FTS index).
class SearchRepository {
  SearchRepository(this._db);

  final AppDatabase _db;

  /// Searches notes by title and plainText using FTS5.
  /// Optional [type] filter restricts results to a specific NoteType.
  Future<List<Note>> searchNotes(String query, {NoteType? type}) async {
    if (query.trim().isEmpty) return [];

    final sanitized = _sanitizeFts5Query(query);
    if (sanitized.isEmpty) return [];

    List<QueryRow> ftsResults;
    try {
      ftsResults = await _db.customSelect(
        'SELECT id FROM notes_fts WHERE notes_fts MATCH ?',
        variables: [Variable.withString('$sanitized*')],
      ).get();
    } catch (e) {
      // Never let a malformed FTS query crash search — degrade to empty.
      nookLog(
        NookLogKey.database,
        'FTS query failed for "$sanitized": $e',
        LogLevel.warning,
      );
      return [];
    }

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

  /// Searches notes (FTS) **and** checklist item text (LIKE), returning
  /// grouped results for the search screen.
  ///
  /// Checklist items are not in `notes_fts`; this dual-query keeps the FTS
  /// index untouched while making item text first-class in search UX.
  Future<GroupedSearchResults> searchGrouped(
    String query, {
    NoteType? type,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const GroupedSearchResults();

    final notes = await searchNotes(trimmed, type: type);
    final checklistItems = await _searchChecklistItems(trimmed, type: type);

    nookLog(
      NookLogKey.database,
      'Grouped search "$trimmed" → notes: ${notes.length}, '
      'checklistItems: ${checklistItems.length}',
      LogLevel.debug,
    );
    return GroupedSearchResults(notes: notes, checklistItems: checklistItems);
  }

  Future<List<SearchHit>> _searchChecklistItems(
    String query, {
    NoteType? type,
  }) async {
    // Escape LIKE wildcards in user input; match case-insensitively.
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';

    final rows = await _db.customSelect(
      '''
      SELECT ci.id AS item_id, ci.item_text AS item_text, ci.note_id AS note_id
      FROM checklist_items ci
      INNER JOIN notes n ON n.id = ci.note_id
      WHERE n.deleted = 0
        AND ci.item_text LIKE ? ESCAPE '\\'
      ORDER BY n.updated_at DESC
      ''',
      variables: [Variable.withString(pattern)],
    ).get();

    if (rows.isEmpty) return [];

    final noteIds = rows
        .map((r) => r.read<String>('note_id'))
        .whereType<String>()
        .toSet()
        .toList();

    final notesQuery = _db.select(_db.notes)
      ..where((t) => t.id.isIn(noteIds) & t.deleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (type != null) {
      notesQuery.where((t) => t.type.equalsValue(type));
    }
    final notes = await notesQuery.get();
    final notesById = {for (final n in notes) n.id: n};

    final hits = <SearchHit>[];
    for (final row in rows) {
      final noteId = row.read<String>('note_id');
      final note = notesById[noteId];
      if (note == null) continue;
      hits.add(
        SearchHit(
          note: note,
          kind: SearchResultKind.checklistItem,
          snippet: row.read<String>('item_text'),
          checklistItemId: row.read<String>('item_id'),
        ),
      );
    }
    return hits;
  }

  /// Strips FTS5 special characters and operators from user input to prevent
  /// query injection / parse errors.
  static String _sanitizeFts5Query(String input) {
    return input
        .replaceAll(RegExp(r'["()*%:^{}[\]~-]'), ' ')
        .replaceAll(RegExp(r'\b(NOT|AND|OR|NEAR)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
