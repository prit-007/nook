import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';

/// URI scheme for in-app note links.
const String kNoteLinkScheme = 'nook';
const String kNoteLinkHost = 'note';

/// Builds a deep link for a note id: `nook://note/<id>`.
String noteLinkUri(String noteId) =>
    '$kNoteLinkScheme://$kNoteLinkHost/$noteId';

/// Extracts note ids referenced by `nook://note/<id>` hrefs in an AppFlowy
/// document JSON blob.
Set<String> extractNoteLinkIds(String? deltaJson) {
  if (deltaJson == null || deltaJson.isEmpty) return {};
  final Object? decoded;
  try {
    decoded = jsonDecode(deltaJson);
  } catch (_) {
    return {};
  }
  final ids = <String>{};
  void walk(Object? node) {
    if (node is Map) {
      final href = node['href'];
      if (href is String) {
        final id = parseNoteLinkUri(href);
        if (id != null) ids.add(id);
      }
      for (final value in node.values) {
        walk(value);
      }
    } else if (node is List) {
      for (final value in node) {
        walk(value);
      }
    }
  }

  walk(decoded);
  return ids;
}

/// Parses `nook://note/<id>` → note id, or null if not a note link.
String? parseNoteLinkUri(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null) return null;
  if (uri.scheme != kNoteLinkScheme) return null;
  if (uri.host != kNoteLinkHost) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  return segments.first;
}

/// A backlink or outgoing link with resolved note metadata.
class NoteLinkHit {
  const NoteLinkHit({
    required this.noteId,
    required this.title,
    required this.linkedNoteId,
    required this.linkedTitle,
    this.linkedDeleted = false,
  });

  final String noteId;
  final String title;
  final String linkedNoteId;
  final String linkedTitle;
  final bool linkedDeleted;
}

/// Cache of note-to-note links, rebuilt from document JSON.
class NoteLinkRepository {
  NoteLinkRepository(this._db);

  final AppDatabase _db;

  /// Rebuilds the link cache for [noteId] from its current `deltaContent`.
  ///
  /// Called from `NoteRepository.updateContent` so editor saves, sync receive,
  /// and import all stay consistent. Deltas are the source of truth.
  Future<void> rebuildForNote(String noteId) async {
    final note = await (_db.select(_db.notes)
          ..where((t) => t.id.equals(noteId)))
        .getSingleOrNull();
    if (note == null || note.deleted) {
      await (_db.delete(_db.noteLinks)
            ..where((t) => t.sourceNoteId.equals(noteId)))
          .go();
      return;
    }

    final targetIds = extractNoteLinkIds(note.deltaContent)
      ..remove(noteId); // ignore self-links

    await (_db.delete(_db.noteLinks)
          ..where((t) => t.sourceNoteId.equals(noteId)))
        .go();

    if (targetIds.isEmpty) return;

    final existingTargets = await (_db.select(_db.notes)
          ..where((t) => t.id.isIn(targetIds.toList())))
        .get();
    final known = existingTargets.map((n) => n.id).toSet();

    for (final targetId in known) {
      await _db.into(_db.noteLinks).insert(
            NoteLinksCompanion.insert(
              sourceNoteId: noteId,
              targetNoteId: targetId,
            ),
          );
    }
    nookLog(
      NookLogKey.database,
      'Note links rebuilt for $noteId → ${known.length} target(s)',
      LogLevel.debug,
    );
  }

  /// Outgoing links from [noteId] (what this note points at).
  Future<List<NoteLinkHit>> outgoingFrom(String noteId) async {
    final rows = await (_db.select(_db.noteLinks)
          ..where((t) => t.sourceNoteId.equals(noteId)))
        .get();
    return _hydrate(rows, sourceIsNote: false);
  }

  /// Incoming links to [noteId] (what points at this note).
  Future<List<NoteLinkHit>> incomingTo(String noteId) async {
    final rows = await (_db.select(_db.noteLinks)
          ..where((t) => t.targetNoteId.equals(noteId)))
        .get();
    return _hydrate(rows, sourceIsNote: true);
  }

  Future<List<NoteLinkHit>> _hydrate(
    List<NoteLink> rows, {
    required bool sourceIsNote,
  }) async {
    if (rows.isEmpty) return [];
    final noteIds = <String>{
      for (final r in rows)
        if (sourceIsNote) r.sourceNoteId else r.targetNoteId,
      for (final r in rows)
        if (sourceIsNote) r.targetNoteId else r.sourceNoteId,
    };
    final notes = await (_db.select(_db.notes)
          ..where((t) => t.id.isIn(noteIds.toList())))
        .get();
    final byId = {for (final n in notes) n.id: n};

    final hits = <NoteLinkHit>[];
    for (final r in rows) {
      final source = byId[r.sourceNoteId];
      final target = byId[r.targetNoteId];
      if (source == null || target == null) continue;
      hits.add(
        NoteLinkHit(
          noteId: r.sourceNoteId,
          title: source.title,
          linkedNoteId: r.targetNoteId,
          linkedTitle: target.title.isEmpty ? 'Untitled' : target.title,
          linkedDeleted: sourceIsNote ? target.deleted : source.deleted,
        ),
      );
    }
    // Stable order: most recently updated parent note first.
    hits.sort((a, b) {
      final an = byId[sourceIsNote ? a.noteId : a.linkedNoteId];
      final bn = byId[sourceIsNote ? b.noteId : b.linkedNoteId];
      return (bn?.updatedAt ?? DateTime(0))
          .compareTo(an?.updatedAt ?? DateTime(0));
    });
    return hits;
  }

  /// Live (non-deleted) notes matching [query] for the link picker.
  Future<List<Note>> searchNotesForLinkPicker(
    String query, {
    String? excludeId,
  }) async {
    final q = query.trim();
    final lowerQ = q.toLowerCase();
    final rows = await (_db.select(_db.notes)
          ..where((t) {
            if (q.isEmpty) return t.deleted.equals(false);
            return t.deleted.equals(false) &
                (t.title.lower().contains(lowerQ) |
                    t.plainText.lower().contains(lowerQ));
          })
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(30))
        .get();
    return excludeId == null
        ? rows
        : rows.where((n) => n.id != excludeId).toList();
  }
}
