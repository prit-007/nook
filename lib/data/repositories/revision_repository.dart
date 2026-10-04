import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';
import 'note_repository.dart';

/// Why a revision was recorded.
enum RevisionSource {
  autosave('autosave'),
  manual('manual'),
  restore('restore');

  const RevisionSource(this.dbValue);
  final String dbValue;

  static RevisionSource fromDb(String value) =>
      RevisionSource.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => RevisionSource.autosave,
      );
}

/// Maximum revisions kept per note (oldest pruned first).
const int kMaxRevisionsPerNote = 200;

/// Minimum gap between autosave snapshots for the same note.
const Duration kRevisionAutosaveBucket = Duration(minutes: 10);

/// Local-only version history for notes.
///
/// Snapshot policy: at most one autosave revision per [kRevisionAutosaveBucket]
/// per note; always snapshot before restore; prune beyond
/// [kMaxRevisionsPerNote]. Revisions are not synced (v1).
class RevisionRepository {
  RevisionRepository(
    this._db, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Records a revision for [noteId] if policy allows.
  ///
  /// Returns the created revision, or null when skipped (same-bucket autosave
  /// or note missing).
  Future<NoteRevision?> maybeSnapshot({
    required String noteId,
    required String title,
    required String? deltaContent,
    required String? plainText,
    RevisionSource source = RevisionSource.autosave,
    DateTime? at,
  }) async {
    final now = at ?? _clock();

    if (source == RevisionSource.autosave) {
      final last = await (_db.select(_db.noteRevisions)
            ..where((t) =>
                t.noteId.equals(noteId) & t.source.equals(source.dbValue))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();
      if (last != null &&
          now.difference(last.createdAt) < kRevisionAutosaveBucket) {
        return null;
      }
    }

    final revId = const Uuid().v4();
    await _db.into(_db.noteRevisions).insert(
          NoteRevisionsCompanion.insert(
            id: Value(revId),
            noteId: noteId,
            title: Value(title),
            deltaContent: Value(deltaContent),
            plainText: Value(plainText),
            createdAt: Value(now),
            source: Value(source.dbValue),
          ),
        );

    await _prune(noteId);

    nookLog(
      NookLogKey.database,
      'Revision saved for note $noteId (${source.dbValue})',
      LogLevel.debug,
    );

    return (_db.select(_db.noteRevisions)..where((t) => t.id.equals(revId)))
        .getSingle();
  }

  /// All revisions for a note, newest first.
  Future<List<NoteRevision>> listForNote(String noteId) {
    return (_db.select(_db.noteRevisions)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Restores [revisionId] onto the live note.
  ///
  /// Snapshots the current note content first (source=restore) so undo is
  /// always possible, then overwrites title/deltaContent/plainText and bumps
  /// `updatedAt`.
  Future<Note> restore(String revisionId) async {
    final revision = await (_db.select(_db.noteRevisions)
          ..where((t) => t.id.equals(revisionId)))
        .getSingleOrNull();
    if (revision == null) {
      throw StateError('Revision $revisionId not found');
    }

    final noteRepo = NoteRepository(_db);
    final current = await noteRepo.getNoteById(revision.noteId);
    if (current == null) {
      throw StateError('Note ${revision.noteId} not found for restore');
    }

    await maybeSnapshot(
      noteId: current.id,
      title: current.title,
      deltaContent: current.deltaContent,
      plainText: current.plainText,
      source: RevisionSource.restore,
    );

    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.id.equals(current.id)))
          .write(
        NotesCompanion(
          title: Value(revision.title),
          deltaContent: Value(revision.deltaContent),
          plainText: Value(revision.plainText),
          updatedAt: Value(_clock()),
        ),
      );
    });

    // Keep FTS in sync with restored plainText.
    await noteRepo.updateContent(
      current.id,
      deltaContent: revision.deltaContent,
      plainText: revision.plainText,
    );

    nookLog(
      NookLogKey.database,
      'Note ${current.id} restored from revision $revisionId',
      LogLevel.info,
    );

    return (_db.select(_db.notes)..where((t) => t.id.equals(current.id)))
        .getSingle();
  }

  /// Hard-deletes a single revision row.
  Future<void> deleteRevision(String id) async {
    await (_db.delete(_db.noteRevisions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _prune(String noteId) async {
    final all = await (_db.select(_db.noteRevisions)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (all.length <= kMaxRevisionsPerNote) return;
    final excess = all.sublist(kMaxRevisionsPerNote);
    final ids = excess.map((r) => r.id).toList();
    await (_db.delete(_db.noteRevisions)..where((t) => t.id.isIn(ids))).go();
  }
}
