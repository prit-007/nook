import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import 'sync_bundle.dart';

/// The action to take when resolving an incoming sync note.
enum MergeAction {
  /// Note doesn't exist locally — insert as new.
  insertAsNew,

  /// Local version is newer — ignore the incoming version.
  ignore,

  /// Same lineage (same deviceOriginId), incoming is newer — overwrite.
  overwrite,

  /// Different devices edited independently — prompt user for resolution.
  promptUser,
}

/// Result of applying an incoming sync note.
class MergeResult {
  const MergeResult({
    required this.action,
    this.localNoteId,
    this.error,
  });

  final MergeAction action;
  final String? localNoteId;
  final String? error;
}

/// Resolves incoming sync notes against the local database.
///
/// Implements the merge strategy from the detailed plan §8.4:
/// - New note → insertAsNew
/// - Older/same version with older timestamp → ignore
/// - Same device origin, newer → overwrite
/// - Different device origin, newer → promptUser
class MergeResolver {
  MergeResolver(this._noteRepo);

  final NoteRepository _noteRepo;

  /// Determines the merge action for an incoming note.
  Future<MergeAction> resolveIncoming(SyncNoteEntry incoming) async {
    final existing = await _noteRepo.getNoteById(incoming.noteId);

    if (existing == null) {
      return MergeAction.insertAsNew;
    }

    // Never resurrect a soft-deleted note through sync.
    if (existing.deleted) {
      return MergeAction.ignore;
    }

    // Incoming is strictly older (same lineage, lower/equal version and an
    // older-or-equal timestamp) — ignore it.
    if (incoming.syncVersion <= existing.syncVersion &&
        !incoming.updatedAt.isAfter(existing.updatedAt)) {
      return MergeAction.ignore;
    }

    // Same device origin — same lineage, just a newer edit. Guard against
    // clock skew: a *lower* syncVersion from the same origin must never
    // overwrite a locally newer version even if its wall-clock timestamp is
    // ahead (e.g. a device whose clock was wrong when the edit was made).
    if (incoming.deviceOriginId == existing.deviceOriginId) {
      if (incoming.syncVersion < existing.syncVersion) {
        return MergeAction.ignore;
      }
      return MergeAction.overwrite;
    }

    // Different device origin, but incoming is newer — true conflict
    return MergeAction.promptUser;
  }

  /// Applies an incoming note to the database based on the merge action.
  ///
  /// Returns the action taken. For promptUser, returns the action without
  /// modifying the database (caller must handle conflict resolution UI).
  Future<MergeAction> applyIncoming(SyncNoteEntry incoming) async {
    final action = await resolveIncoming(incoming);

    switch (action) {
      case MergeAction.insertAsNew:
        await _insertAsNew(incoming);
        return MergeAction.insertAsNew;

      case MergeAction.overwrite:
        await _overwrite(incoming);
        return MergeAction.overwrite;

      case MergeAction.ignore:
        return MergeAction.ignore;

      case MergeAction.promptUser:
        // Don't modify database — let caller handle conflict UI
        return MergeAction.promptUser;
    }
  }

  /// Forces an insert of the incoming note as new. If a local note with the
  /// same ID already exists, a new UUID is generated to avoid primary key
  /// collision. Used for "keep both" conflict resolution.
  ///
  /// Pass [originIdOverride] to re-own the duplicate note (e.g. to the local
  /// device) so it never re-conflicts on the next sync.
  Future<MergeAction> insertAsNew(
    SyncNoteEntry incoming, {
    String? originIdOverride,
  }) async {
    final existing = await _noteRepo.getNoteById(incoming.noteId);
    if (existing != null && !existing.deleted) {
      // ID collision — generate a new ID for the duplicate
      await _noteRepo.createNote(
        title: incoming.noteFields['title'] as String? ?? '',
        type: _parseNoteType(incoming.noteFields['type'] as String?),
        deviceOriginId: originIdOverride ?? incoming.deviceOriginId,
        colorSeed: incoming.noteFields['colorSeed'] as String?,
        deltaContent: incoming.noteFields['deltaContent'] as String?,
        plainText: incoming.noteFields['plainText'] as String?,
        syncVersion: incoming.syncVersion,
        notebookId: incoming.noteFields['notebookId'] as String?,
      );
    } else {
      await _insertAsNew(incoming, originIdOverride: originIdOverride);
    }
    return MergeAction.insertAsNew;
  }

  /// Forces an overwrite of the local note with the incoming version,
  /// regardless of what [resolveIncoming] would return. Used when the
  /// user explicitly chooses "keep remote" during conflict resolution.
  Future<MergeAction> forceOverwrite(SyncNoteEntry incoming) async {
    await _overwrite(incoming);
    return MergeAction.overwrite;
  }

  /// Inserts a brand-new note from a remote device, preserving the remote noteId.
  Future<void> _insertAsNew(
    SyncNoteEntry incoming, {
    String? originIdOverride,
  }) async {
    final noteType = _parseNoteType(incoming.noteFields['type'] as String?);

    await _noteRepo.createNote(
      id: incoming.noteId,
      title: incoming.noteFields['title'] as String? ?? '',
      type: noteType,
      deviceOriginId: originIdOverride ?? incoming.deviceOriginId,
      colorSeed: incoming.noteFields['colorSeed'] as String?,
      deltaContent: incoming.noteFields['deltaContent'] as String?,
      plainText: incoming.noteFields['plainText'] as String?,
      syncVersion: incoming.syncVersion,
      notebookId: incoming.noteFields['notebookId'] as String?,
    );

    final pinned = incoming.noteFields['pinned'] as bool?;
    final locked = incoming.noteFields['locked'] as bool?;
    if (pinned != null || locked != null) {
      await _noteRepo.updateNote(
        incoming.noteId,
        pinned: pinned,
        locked: locked,
        updatedAt: incoming.updatedAt,
      );
    }
  }

  /// Overwrites a local note with the remote version (same lineage).
  Future<void> _overwrite(SyncNoteEntry incoming) async {
    await _noteRepo.updateNote(
      incoming.noteId,
      title: incoming.noteFields['title'] as String?,
      colorSeed: incoming.noteFields['colorSeed'] as String?,
      pinned: incoming.noteFields['pinned'] as bool?,
      locked: incoming.noteFields['locked'] as bool?,
      notebookId: incoming.noteFields['notebookId'] as String?,
      syncVersion: incoming.syncVersion,
      updatedAt: incoming.updatedAt,
    );

    // Always write content (even when both fields are null) so a remote that
    // intentionally cleared a note's content actually clears it locally.
    final deltaContent = incoming.noteFields['deltaContent'] as String?;
    final plainText = incoming.noteFields['plainText'] as String?;
    await _noteRepo.updateContent(
      incoming.noteId,
      deltaContent: deltaContent,
      plainText: plainText,
      updatedAt: incoming.updatedAt,
    );
  }

  NoteType _parseNoteType(String? type) {
    switch (type) {
      case 'checklist':
        return NoteType.checklist;
      case 'doodle':
        return NoteType.doodle;
      case 'mixed':
        return NoteType.mixed;
      default:
        return NoteType.text;
    }
  }
}
