import 'package:drift/drift.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';
import 'attachment_repository.dart';
import 'note_repository.dart';
import 'notebook_repository.dart';
import 'tag_repository.dart';

/// How long soft-deleted items stay in the Bin before auto-purge.
const int kTrashRetentionDays = 30;

/// Result of a trash auto-purge pass — counts per entity type.
class TrashPurgeResult {
  const TrashPurgeResult({
    this.notes = 0,
    this.notebooks = 0,
    this.tags = 0,
    this.attachments = 0,
  });

  final int notes;
  final int notebooks;
  final int tags;
  final int attachments;

  int get total => notes + notebooks + tags + attachments;

  bool get isEmpty => total == 0;

  @override
  String toString() => 'TrashPurgeResult(notes: $notes, notebooks: $notebooks, '
      'tags: $tags, attachments: $attachments)';
}

/// Permanently deletes soft-deleted rows whose `deletedAt` is older than
/// the retention window.
///
/// Called on cold start (and can be re-run) so the Bin matches the
/// "auto-deletes after N days" promise. Injectable [clock] for tests.
class TrashAutoPurger {
  TrashAutoPurger(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Retention window used by [purgeExpired].
  Duration get retention => const Duration(days: kTrashRetentionDays);

  /// Cutoff timestamp: items with `deletedAt < cutoff` are purged.
  DateTime get cutoff => _clock().subtract(retention);

  /// Purges expired soft-deleted notes, notebooks, tags, and attachments.
  ///
  /// Items with `deletedAt == null` (should not happen for soft-deleted
  /// rows) are left alone. Non-deleted rows are never touched.
  Future<TrashPurgeResult> purgeExpired() async {
    final cutoff = this.cutoff;

    final expiredNotes = await (_db.select(_db.notes)
          ..where((t) =>
              t.deleted.equals(true) & t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    final expiredNotebooks = await (_db.select(_db.notebooks)
          ..where((t) =>
              t.deleted.equals(true) & t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    final expiredTags = await (_db.select(_db.tags)
          ..where((t) =>
              t.deleted.equals(true) & t.deletedAt.isSmallerThanValue(cutoff)))
        .get();
    final expiredAttachments = await (_db.select(_db.attachments)
          ..where((t) =>
              t.deleted.equals(true) & t.deletedAt.isSmallerThanValue(cutoff)))
        .get();

    if (expiredNotes.isEmpty &&
        expiredNotebooks.isEmpty &&
        expiredTags.isEmpty &&
        expiredAttachments.isEmpty) {
      return const TrashPurgeResult();
    }

    final noteRepo = NoteRepository(_db);
    final notebookRepo = NotebookRepository(_db);
    final tagRepo = TagRepository(_db);
    final attachmentRepo = AttachmentRepository(_db);

    for (final note in expiredNotes) {
      await noteRepo.permanentlyDelete(note.id);
    }
    for (final notebook in expiredNotebooks) {
      await notebookRepo.permanentlyDelete(notebook.id);
    }
    for (final tag in expiredTags) {
      await tagRepo.permanentlyDelete(tag.id);
    }
    for (final att in expiredAttachments) {
      await attachmentRepo.permanentlyDeleteWithFiles(att);
    }

    final result = TrashPurgeResult(
      notes: expiredNotes.length,
      notebooks: expiredNotebooks.length,
      tags: expiredTags.length,
      attachments: expiredAttachments.length,
    );
    nookLog(
      NookLogKey.database,
      'Trash auto-purge removed $result (cutoff $cutoff)',
      LogLevel.info,
    );
    return result;
  }
}
