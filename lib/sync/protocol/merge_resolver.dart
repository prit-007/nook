import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/tables/notes.dart';
import 'sync_bundle.dart';
import 'sync_message.dart';

/// Compatibility outcome of peer capability negotiation.
enum CapabilityNegotiationStatus {
  compatible,
  degraded,
  incompatible,
}

/// Result of negotiating protocol & schema versions with a remote peer.
class CapabilityNegotiationResult {
  const CapabilityNegotiationResult({
    required this.status,
    required this.agreedProtocolVersion,
    required this.agreedSchemaVersion,
    this.reason,
  });

  final CapabilityNegotiationStatus status;
  final int agreedProtocolVersion;
  final int agreedSchemaVersion;
  final String? reason;

  bool get isCompatible => status != CapabilityNegotiationStatus.incompatible;
}

/// Evaluates whether a remote [SyncMessage] can be processed by this build.
class SyncCapabilityNegotiator {
  const SyncCapabilityNegotiator._();

  static CapabilityNegotiationResult negotiateMessage(SyncMessage remote) {
    if (remote.protocolVersion < 1 ||
        remote.protocolVersion > SyncMessage.currentProtocolVersion) {
      return CapabilityNegotiationResult(
        status: CapabilityNegotiationStatus.incompatible,
        agreedProtocolVersion: SyncMessage.currentProtocolVersion,
        agreedSchemaVersion: SyncMessage.currentSchemaVersion,
        reason:
            'Incompatible sync protocol version ${remote.protocolVersion} (supported: 1..${SyncMessage.currentProtocolVersion})',
      );
    }

    if (remote.schemaVersion < 1 ||
        remote.schemaVersion > SyncMessage.currentSchemaVersion) {
      return CapabilityNegotiationResult(
        status: CapabilityNegotiationStatus.incompatible,
        agreedProtocolVersion: remote.protocolVersion,
        agreedSchemaVersion: SyncMessage.currentSchemaVersion,
        reason:
            'Incompatible sync schema version ${remote.schemaVersion} (supported: 1..${SyncMessage.currentSchemaVersion})',
      );
    }

    if (remote.schemaVersion < SyncMessage.currentSchemaVersion) {
      return CapabilityNegotiationResult(
        status: CapabilityNegotiationStatus.degraded,
        agreedProtocolVersion: remote.protocolVersion,
        agreedSchemaVersion: remote.schemaVersion,
        reason:
            'Remote schema v${remote.schemaVersion} is older than local v${SyncMessage.currentSchemaVersion}; running in degraded mode',
      );
    }

    return CapabilityNegotiationResult(
      status: CapabilityNegotiationStatus.compatible,
      agreedProtocolVersion: remote.protocolVersion,
      agreedSchemaVersion: remote.schemaVersion,
    );
  }
}

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
  MergeResolver(this._noteRepo, this._notebookRepo);

  /// Field-level sync classification matrix (Phase 3.1).
  static const Map<String, String> syncFieldMatrix = {
    'notes.title': 'synced',
    'notes.deltaContent': 'synced',
    'notes.plainText': 'synced',
    'notes.colorSeed': 'synced',
    'notes.fontStyle': 'synced',
    'notes.pinned': 'synced',
    'notes.archived': 'synced',
    'notes.deleted': 'synced',
    'notes.deletedAt': 'synced',
    'notes.updatedAt': 'synced',
    'notes.hlc': 'synced',
    'notes.syncVersion': 'synced',
    'notes.deviceOriginId': 'synced',
    'notes.locked': 'excluded_by_default',
    'notebooks.parentId': 'synced',
    'note_tags.deleted': 'synced',
    'note_revisions': 'local_only',
    'trusted_devices': 'local_only',
    'sync_log': 'local_only',
  };

  final NoteRepository _noteRepo;
  final NotebookRepository _notebookRepo;

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
    nookLog(
      NookLogKey.sync,
      'True conflict for ${incoming.noteId} (local vs ${incoming.deviceOriginId})',
      LogLevel.warning,
    );
    return MergeAction.promptUser;
  }

  /// Applies an incoming note only if [remoteMessage] passes capability
  /// negotiation; otherwise refuses cleanly without mutating the database.
  Future<
      ({
        CapabilityNegotiationResult negotiation,
        MergeAction? action,
        String? error,
      })> applyIncomingIfCompatible(
    SyncNoteEntry incoming, {
    required SyncMessage remoteMessage,
  }) async {
    final negotiation =
        SyncCapabilityNegotiator.negotiateMessage(remoteMessage);
    if (!negotiation.isCompatible) {
      nookLog(
        NookLogKey.sync,
        'Refused incoming note ${incoming.noteId}: ${negotiation.reason}',
        LogLevel.warning,
      );
      return (
        negotiation: negotiation,
        action: null,
        error: negotiation.reason,
      );
    }
    final action = await applyIncoming(incoming);
    return (
      negotiation: negotiation,
      action: action,
      error: null,
    );
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
      final notebookId = incoming.noteFields['notebookId'] as String?;
      await _ensureNotebookExists(
        notebookId,
        name: incoming.noteFields['notebookName'] as String?,
        colorSeed: incoming.noteFields['notebookColorSeed'] as String?,
        icon: incoming.noteFields['notebookIcon'] as String?,
        parentId: incoming.noteFields['notebookParentId'] as String?,
      );
      final rawCreatedAt = incoming.noteFields['createdAt'];
      final createdAt = rawCreatedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(rawCreatedAt)
          : null;
      final newNote = await _noteRepo.createNote(
        title: incoming.noteFields['title'] as String? ?? '',
        type: _parseNoteType(incoming.noteFields['type'] as String?),
        deviceOriginId: originIdOverride ?? incoming.deviceOriginId,
        colorSeed: incoming.noteFields['colorSeed'] as String?,
        deltaContent: incoming.noteFields['deltaContent'] as String?,
        plainText: incoming.noteFields['plainText'] as String?,
        syncVersion: incoming.syncVersion,
        notebookId: notebookId,
        createdAt: createdAt,
      );
      // Preserve pinned/locked from the incoming note — the base createNote
      // does not accept these params, so apply them in a follow-up update.
      final pinned = incoming.noteFields['pinned'] as bool?;
      final locked = incoming.noteFields['locked'] as bool?;
      if (pinned != null || locked != null) {
        await _noteRepo.updateNote(
          newNote.id,
          pinned: pinned,
          locked: locked,
          updatedAt: incoming.updatedAt,
        );
      }
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

  /// Ensures the referenced notebook exists locally. If it doesn't, a
  /// placeholder is created under the same ID so the note keeps its grouping
  /// and the FK constraint is satisfied. Mirrors the import handler's
  /// `_resolveNotebookId` logic.
  Future<void> _ensureNotebookExists(
    String? notebookId, {
    String? name,
    String? colorSeed,
    String? icon,
    String? parentId,
  }) async {
    if (notebookId == null || notebookId.isEmpty) return;
    final existing = await _notebookRepo.getNotebookById(notebookId);
    if (existing != null) {
      if (parentId != null && existing.parentId != parentId) {
        // Deterministically break cycles: if setting parentId would cause a cycle, detach to root
        final wouldCycle =
            await _notebookRepo.wouldCreateCycle(notebookId, parentId);
        if (wouldCycle) {
          nookLog(
            NookLogKey.sync,
            'Cycle detected on concurrent reparent ($notebookId -> $parentId). Detaching to root.',
            LogLevel.warning,
          );
          await _notebookRepo.updateNotebook(notebookId,
              parentId: const Value(null));
        } else {
          final parentDepth = await _notebookRepo.getNotebookDepth(parentId);
          if (parentDepth >= NotebookRepository.maxCollectionDepth) {
            await _notebookRepo.updateNotebook(notebookId,
                parentId: const Value(null));
          } else {
            await _notebookRepo.updateNotebook(notebookId,
                parentId: Value(parentId));
          }
        }
      }
      return;
    }

    String? safeParentId = parentId;
    if (safeParentId != null) {
      final parentDepth = await _notebookRepo.getNotebookDepth(safeParentId);
      if (parentDepth >= NotebookRepository.maxCollectionDepth) {
        safeParentId = null;
      }
    }

    await _notebookRepo.createNotebookWithId(
      notebookId,
      name: name ?? 'Synced Notebook',
      colorSeed: colorSeed ?? '#6750A4',
      icon: icon ?? 'notebook',
      parentId: safeParentId,
    );
    nookLog(
      NookLogKey.sync,
      'Created placeholder notebook for incoming note: $notebookId (parent: $safeParentId)',
      LogLevel.info,
    );
  }

  /// Inserts a brand-new note from a remote device, preserving the remote noteId.
  Future<void> _insertAsNew(
    SyncNoteEntry incoming, {
    String? originIdOverride,
  }) async {
    final noteType = _parseNoteType(incoming.noteFields['type'] as String?);
    final notebookId = incoming.noteFields['notebookId'] as String?;

    await _ensureNotebookExists(
      notebookId,
      name: incoming.noteFields['notebookName'] as String?,
      colorSeed: incoming.noteFields['notebookColorSeed'] as String?,
      icon: incoming.noteFields['notebookIcon'] as String?,
      parentId: incoming.noteFields['notebookParentId'] as String?,
    );

    final rawCreatedAt = incoming.noteFields['createdAt'];
    final createdAt = rawCreatedAt is int
        ? DateTime.fromMillisecondsSinceEpoch(rawCreatedAt)
        : null;

    await _noteRepo.createNote(
      id: incoming.noteId,
      title: incoming.noteFields['title'] as String? ?? '',
      type: noteType,
      deviceOriginId: originIdOverride ?? incoming.deviceOriginId,
      colorSeed: incoming.noteFields['colorSeed'] as String?,
      deltaContent: incoming.noteFields['deltaContent'] as String?,
      plainText: incoming.noteFields['plainText'] as String?,
      syncVersion: incoming.syncVersion,
      notebookId: notebookId,
      createdAt: createdAt,
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
    if (incoming.noteFields['archived'] == true) {
      await _noteRepo.archiveNote(incoming.noteId);
    }
    if (incoming.noteFields['deleted'] == true) {
      await _noteRepo.softDelete(incoming.noteId);
    }
  }

  /// Overwrites a local note with the remote version (same lineage).
  Future<void> _overwrite(SyncNoteEntry incoming) async {
    final noteType = _parseNoteType(incoming.noteFields['type'] as String?);

    await _ensureNotebookExists(
      incoming.noteFields['notebookId'] as String?,
      name: incoming.noteFields['notebookName'] as String?,
      colorSeed: incoming.noteFields['notebookColorSeed'] as String?,
      icon: incoming.noteFields['notebookIcon'] as String?,
      parentId: incoming.noteFields['notebookParentId'] as String?,
    );

    await _noteRepo.updateNote(
      incoming.noteId,
      title: incoming.noteFields['title'] as String?,
      type: noteType,
      colorSeed: incoming.noteFields['colorSeed'] as String?,
      pinned: incoming.noteFields['pinned'] as bool?,
      locked: incoming.noteFields['locked'] as bool?,
      notebookId: incoming.noteFields['notebookId'] as String?,
      syncVersion: incoming.syncVersion,
      updatedAt: incoming.updatedAt,
    );

    // Always write content (even when both fields are null) so a remote that
    // intentionally cleared a note's content actually clears it locally.
    // Guard: only update content when the incoming bundle actually carries
    // content keys — CBOR omits null-valued map entries, so a sender that
    // did not set deltaContent/plainText produces a map without those keys.
    final noteFields = incoming.noteFields;
    final hasDeltaContent = noteFields.containsKey('deltaContent');
    final hasPlainText = noteFields.containsKey('plainText');
    if (hasDeltaContent || hasPlainText) {
      final deltaContent =
          hasDeltaContent ? noteFields['deltaContent'] as String? : null;
      final plainText =
          hasPlainText ? noteFields['plainText'] as String? : null;
      await _noteRepo.updateContent(
        incoming.noteId,
        deltaContent: deltaContent,
        plainText: plainText,
        updatedAt: incoming.updatedAt,
      );
    }
    final archived = noteFields['archived'] as bool?;
    if (archived == true) {
      await _noteRepo.archiveNote(incoming.noteId);
    } else if (archived == false) {
      await _noteRepo.unarchiveNote(incoming.noteId);
    }
    if (noteFields['deleted'] == true) {
      await _noteRepo.softDelete(incoming.noteId);
    }
  }

  /// Performs a block-level 3-way merge on AppFlowy node-tree JSON documents
  /// given a common [base] revision.
  ///
  /// Non-overlapping block edits merge cleanly (`hasConflict: false`).
  /// Concurrent edits to the exact same block index produce `hasConflict: true`.
  static ({bool hasConflict, Map<String, dynamic> mergedDocument})
      threeWayMergeDocument({
    required Map<String, dynamic> base,
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final baseChildren = ((base['document'] as Map?)?['children'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final localChildren = ((local['document'] as Map?)?['children'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final remoteChildren = ((remote['document'] as Map?)?['children'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    final maxLen = [
      baseChildren.length,
      localChildren.length,
      remoteChildren.length,
    ].reduce((a, b) => a > b ? a : b);

    final mergedChildren = <Map<String, dynamic>>[];
    var hasConflict = false;

    for (var i = 0; i < maxLen; i++) {
      final b = i < baseChildren.length ? baseChildren[i] : null;
      final l = i < localChildren.length ? localChildren[i] : null;
      final r = i < remoteChildren.length ? remoteChildren[i] : null;

      final bJson = b == null ? null : jsonEncode(b);
      final lJson = l == null ? null : jsonEncode(l);
      final rJson = r == null ? null : jsonEncode(r);

      if (lJson == rJson) {
        if (l != null) mergedChildren.add(l);
      } else if (lJson == bJson) {
        if (r != null) mergedChildren.add(r);
      } else if (rJson == bJson) {
        if (l != null) mergedChildren.add(l);
      } else {
        hasConflict = true;
        if (l != null) mergedChildren.add(l);
      }
    }

    final merged = Map<String, dynamic>.from(local);
    final docMap = Map<String, dynamic>.from(
      (local['document'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    docMap['children'] = mergedChildren;
    merged['document'] = docMap;
    return (hasConflict: hasConflict, mergedDocument: merged);
  }

  /// Resolves an incoming note using [baseDocument] for block-level 3-way merge
  /// when two devices edited independently from a common revision.
  Future<({MergeAction action, Map<String, dynamic>? mergedDocument})>
      resolveIncomingWithBase(
    SyncNoteEntry incoming, {
    Map<String, dynamic>? baseDocument,
  }) async {
    final action = await resolveIncoming(incoming);
    if (action != MergeAction.promptUser || baseDocument == null) {
      return (action: action, mergedDocument: null);
    }

    final existing = await _noteRepo.getNoteById(incoming.noteId);
    final localRaw = existing?.deltaContent;
    final remoteRaw = incoming.noteFields['deltaContent'] as String?;
    if (localRaw == null || remoteRaw == null) {
      return (action: MergeAction.promptUser, mergedDocument: null);
    }

    try {
      final localDoc = jsonDecode(localRaw) as Map<String, dynamic>;
      final remoteDoc = jsonDecode(remoteRaw) as Map<String, dynamic>;
      final merged = threeWayMergeDocument(
        base: baseDocument,
        local: localDoc,
        remote: remoteDoc,
      );
      if (merged.hasConflict) {
        return (action: MergeAction.promptUser, mergedDocument: null);
      }
      return (
        action: MergeAction.overwrite,
        mergedDocument: merged.mergedDocument
      );
    } catch (_) {
      return (action: MergeAction.promptUser, mergedDocument: null);
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
