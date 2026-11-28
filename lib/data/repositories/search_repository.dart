import 'dart:math' as math;

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
  Future<List<Note>> searchNotes(
    String query, {
    NoteType? type,
    bool includeLocked = false,
  }) async {
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
      ..where((t) =>
          t.id.isIn(ids) &
          t.deleted.equals(false) &
          (includeLocked ? const Constant(true) : t.locked.equals(false)))
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

  /// Searches notes with inline structured filter tokens:
  /// - `tag:<name>`
  /// - `in:<notebook>`
  /// - `is:pinned | archived | locked | checklist | doodle`
  /// - `before:YYYY-MM-DD` / `after:YYYY-MM-DD`
  Future<List<Note>> searchNotesWithFilters(
    String rawQuery, {
    bool includeLocked = false,
  }) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return [];

    String? tagFilter;
    String? notebookFilter;
    bool? pinnedFilter;
    bool? archivedFilter;
    bool? lockedFilter;
    NoteType? typeFilter;
    DateTime? beforeDate;
    DateTime? afterDate;
    final textTokens = <String>[];

    for (final token in trimmed.split(RegExp(r'\s+'))) {
      final lower = token.toLowerCase();
      if (lower.startsWith('tag:') && token.length > 4) {
        tagFilter = token.substring(4).toLowerCase();
      } else if (lower.startsWith('in:') && token.length > 3) {
        notebookFilter = token.substring(3).toLowerCase();
      } else if (lower.startsWith('is:') && token.length > 3) {
        switch (lower.substring(3)) {
          case 'pinned':
            pinnedFilter = true;
          case 'archived':
            archivedFilter = true;
          case 'locked':
            lockedFilter = true;
          case 'checklist':
            typeFilter = NoteType.checklist;
          case 'doodle':
            typeFilter = NoteType.doodle;
        }
      } else if (lower.startsWith('before:') && token.length > 7) {
        beforeDate = DateTime.tryParse(token.substring(7));
      } else if (lower.startsWith('after:') && token.length > 6) {
        afterDate = DateTime.tryParse(token.substring(6));
      } else {
        textTokens.add(token);
      }
    }

    final textQuery = textTokens.join(' ').trim();
    List<Note> candidates;
    if (textQuery.isNotEmpty) {
      candidates = await searchNotes(
        textQuery,
        type: typeFilter,
        includeLocked: includeLocked,
      );
    } else {
      final q = _db.select(_db.notes)
        ..where((t) =>
            t.deleted.equals(false) &
            (includeLocked ? const Constant(true) : t.locked.equals(false)))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      if (typeFilter != null) {
        q.where((t) => t.type.equalsValue(typeFilter!));
      }
      candidates = await q.get();
    }

    if (pinnedFilter != null) {
      candidates = candidates.where((n) => n.pinned == pinnedFilter).toList();
    }
    if (archivedFilter != null) {
      candidates =
          candidates.where((n) => n.archived == archivedFilter).toList();
    }
    if (lockedFilter != null) {
      candidates = candidates.where((n) => n.locked == lockedFilter).toList();
    }
    if (beforeDate != null) {
      candidates =
          candidates.where((n) => n.updatedAt.isBefore(beforeDate!)).toList();
    }
    if (afterDate != null) {
      candidates =
          candidates.where((n) => !n.updatedAt.isBefore(afterDate!)).toList();
    }

    if (notebookFilter != null && candidates.isNotEmpty) {
      final notebooks = await (_db.select(_db.notebooks)
            ..where((t) => t.deleted.equals(false)))
          .get();
      final matchingNbIds = notebooks
          .where((nb) => nb.name.toLowerCase() == notebookFilter)
          .map((nb) => nb.id)
          .toSet();
      candidates = candidates
          .where(
            (n) => n.notebookId != null && matchingNbIds.contains(n.notebookId),
          )
          .toList();
    }

    if (tagFilter != null && candidates.isNotEmpty) {
      final tagRows = await _db.customSelect(
        '''
        SELECT nt.note_id AS note_id
        FROM note_tags nt
        INNER JOIN tags t ON t.id = nt.tag_id
        WHERE nt.deleted = 0
          AND t.deleted = 0
          AND LOWER(t.name) = ?
        ''',
        variables: [Variable.withString(tagFilter)],
      ).get();
      final taggedIds = tagRows.map((r) => r.read<String>('note_id')).toSet();
      candidates = candidates.where((n) => taggedIds.contains(n.id)).toList();
    }

    return candidates;
  }

  /// Searches notes (FTS) **and** checklist item text (LIKE), returning
  /// grouped results for the search screen.
  ///
  /// Checklist items are not in `notes_fts`; this dual-query keeps the FTS
  /// index untouched while making item text first-class in search UX.
  Future<GroupedSearchResults> searchGrouped(
    String query, {
    NoteType? type,
    bool includeLocked = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const GroupedSearchResults();

    final notes =
        await searchNotes(trimmed, type: type, includeLocked: includeLocked);
    final checklistItems = await _searchChecklistItems(trimmed,
        type: type, includeLocked: includeLocked);

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
    bool includeLocked = false,
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
      ..where((t) =>
          t.id.isIn(noteIds) &
          t.deleted.equals(false) &
          (includeLocked ? const Constant(true) : t.locked.equals(false)))
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

/// Ranked semantic search result.
class SemanticSearchHit {
  const SemanticSearchHit({required this.note, required this.score});
  final Note note;
  final double score;
}

/// Opt-in offline semantic search over unlocked notes (never indexes locked notes).
class SemanticSearchIndex {
  SemanticSearchIndex(this._db, {this.enabled = false});

  final AppDatabase _db;
  final bool enabled;
  final Map<String, ({Note note, Map<String, double> vector})> _index = {};

  Future<void> rebuildIndex() async {
    _index.clear();
    if (!enabled) return;

    final notes = await (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(false) & t.locked.equals(false)))
        .get();

    for (final note in notes) {
      final text = '${note.title} ${note.plainText ?? ''}';
      _index[note.id] = (note: note, vector: _embed(text));
    }
  }

  Future<List<SemanticSearchHit>> search(String query, {int limit = 20}) async {
    if (!enabled || query.trim().isEmpty) return const [];
    if (_index.isEmpty) {
      await rebuildIndex();
    }
    final qVec = _embed(query);
    if (qVec.isEmpty) return const [];

    final hits = <SemanticSearchHit>[];
    for (final entry in _index.values) {
      if (entry.note.locked || entry.note.deleted) continue;
      final score = _cosine(qVec, entry.vector);
      if (score > 0.05) {
        hits.add(SemanticSearchHit(note: entry.note, score: score));
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  static Map<String, double> _embed(String text) {
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 2);
    final counts = <String, double>{};
    for (final token in tokens) {
      counts[token] = (counts[token] ?? 0) + 1.0;
      if (token.length >= 3) {
        for (var i = 0; i <= token.length - 3; i++) {
          final tri = '#${token.substring(i, i + 3)}';
          counts[tri] = (counts[tri] ?? 0) + 0.5;
        }
      }
    }
    return counts;
  }

  static double _cosine(Map<String, double> a, Map<String, double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (final v in a.values) {
      normA += v * v;
    }
    for (final v in b.values) {
      normB += v * v;
    }
    if (normA == 0 || normB == 0) return 0;
    for (final entry in a.entries) {
      final bv = b[entry.key];
      if (bv != null) dot += entry.value * bv;
    }
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }
}
