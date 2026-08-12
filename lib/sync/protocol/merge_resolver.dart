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

    // Check if incoming is older or same version with older/same timestamp
    if (incoming.syncVersion <= existing.syncVersion &&
        !incoming.updatedAt.isAfter(existing.updatedAt)) {
      return MergeAction.ignore;
    }

    // Same device origin — same lineage, just a newer edit
    if (incoming.deviceOriginId == existing.deviceOriginId) {
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
  Future<MergeAction> insertAsNew(SyncNoteEntry incoming) async {
    final existing = await _noteRepo.getNoteById(incoming.noteId);
    if (existing != null) {
      // ID collision — generate a new ID for the duplicate
      await _noteRepo.createNote(
        title: incoming.noteFields['title'] as String? ?? '',
        type: _parseNoteType(incoming.noteFields['type'] as String?),
        deviceOriginId: incoming.deviceOriginId,
        colorSeed: incoming.noteFields['colorSeed'] as String?,
        deltaContent: incoming.noteFields['deltaContent'] as String?,
        plainText: incoming.noteFields['plainText'] as String?,
      );
    } else {
      await _insertAsNew(incoming);
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
  Future<void> _insertAsNew(SyncNoteEntry incoming) async {
    final noteType = _parseNoteType(incoming.noteFields['type'] as String?);

    await _noteRepo.createNote(
      id: incoming.noteId,
      title: incoming.noteFields['title'] as String? ?? '',
      type: noteType,
      deviceOriginId: incoming.deviceOriginId,
      colorSeed: incoming.noteFields['colorSeed'] as String?,
      deltaContent: incoming.noteFields['deltaContent'] as String?,
      plainText: incoming.noteFields['plainText'] as String?,
    );
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

    // Update content if present
    final deltaContent = incoming.noteFields['deltaContent'] as String?;
    final plainText = incoming.noteFields['plainText'] as String?;
    if (deltaContent != null || plainText != null) {
      await _noteRepo.updateContent(
        incoming.noteId,
        deltaContent: deltaContent,
        plainText: plainText,
      );
    }
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
