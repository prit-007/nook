import 'dart:typed_data';

import 'package:cbor/cbor.dart';

/// Lightweight summary of a single note for sync digest exchange.
class NoteDigestEntry {
  const NoteDigestEntry({
    required this.noteId,
    required this.updatedAt,
    required this.syncVersion,
    this.deleted = false,
    this.contentHash,
  });

  final String noteId;
  final DateTime updatedAt;
  final int syncVersion;
  final bool deleted;
  final String? contentHash;

  Map<dynamic, dynamic> toMap() {
    return {
      'id': noteId,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'syncVersion': syncVersion,
      'deleted': deleted,
      if (contentHash != null) 'contentHash': contentHash,
    };
  }

  factory NoteDigestEntry.fromMap(Map<dynamic, dynamic> map) {
    return NoteDigestEntry(
      noteId: (map['id'] as String?) ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as int?) ?? 0,
        isUtc: true,
      ),
      syncVersion: (map['syncVersion'] as int?) ?? 0,
      deleted: (map['deleted'] as bool?) ?? false,
      contentHash: map['contentHash'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteDigestEntry &&
          runtimeType == other.runtimeType &&
          noteId == other.noteId &&
          updatedAt.millisecondsSinceEpoch ==
              other.updatedAt.millisecondsSinceEpoch &&
          syncVersion == other.syncVersion &&
          deleted == other.deleted &&
          contentHash == other.contentHash;

  @override
  int get hashCode => Object.hash(
        noteId,
        updatedAt.millisecondsSinceEpoch,
        syncVersion,
        deleted,
        contentHash,
      );
}

/// Metadata digest of all local notes used to negotiate a two-way sync delta.
class SyncDigest {
  const SyncDigest({
    required this.deviceId,
    required this.entries,
  });

  final String deviceId;
  final List<NoteDigestEntry> entries;

  Uint8List toCbor() {
    final entryMaps = entries.map((e) {
      return CborMap.fromEntries([
        MapEntry(CborString('id'), CborString(e.noteId)),
        MapEntry(CborString('updatedAt'),
            CborSmallInt(e.updatedAt.millisecondsSinceEpoch)),
        MapEntry(CborString('syncVersion'), CborSmallInt(e.syncVersion)),
        MapEntry(CborString('deleted'), CborBool(e.deleted)),
        if (e.contentHash != null)
          MapEntry(CborString('contentHash'), CborString(e.contentHash!)),
      ]);
    }).toList();

    final map = CborMap.fromEntries([
      MapEntry(CborString('deviceId'), CborString(deviceId)),
      MapEntry(CborString('entries'), CborList.of(entryMaps)),
    ]);

    return Uint8List.fromList(cborEncode(map));
  }

  factory SyncDigest.fromCbor(Uint8List bytes) {
    final map = cborDecode(bytes).toObject() as Map<dynamic, dynamic>;
    final deviceId = (map['deviceId'] as String?) ?? '';
    final rawEntries = (map['entries'] as List<dynamic>?) ?? [];

    final entries = rawEntries
        .whereType<Map<dynamic, dynamic>>()
        .map(NoteDigestEntry.fromMap)
        .toList();

    return SyncDigest(
      deviceId: deviceId,
      entries: entries,
    );
  }
}

/// The result of comparing local and remote sync digests.
class SyncReconciliation {
  const SyncReconciliation({
    required this.notesToPush,
    required this.notesToPull,
    required this.conflicts,
    required this.identicalNotes,
  });

  final List<String> notesToPush;
  final List<String> notesToPull;
  final List<String> conflicts;
  final List<String> identicalNotes;

  /// Reconciles local and remote digests to determine minimal transfer sets.
  static SyncReconciliation reconcile({
    required SyncDigest local,
    required SyncDigest remote,
  }) {
    final localMap = {for (final e in local.entries) e.noteId: e};
    final remoteMap = {for (final e in remote.entries) e.noteId: e};
    final allIds = {...localMap.keys, ...remoteMap.keys}.toList()..sort();

    final notesToPush = <String>[];
    final notesToPull = <String>[];
    final conflicts = <String>[];
    final identicalNotes = <String>[];

    for (final id in allIds) {
      final l = localMap[id];
      final r = remoteMap[id];

      if (l != null && r == null) {
        notesToPush.add(id);
      } else if (r != null && l == null) {
        notesToPull.add(id);
      } else if (l != null && r != null) {
        final hashesMatch = l.contentHash != null &&
            r.contentHash != null &&
            l.contentHash == r.contentHash &&
            l.deleted == r.deleted;

        if (hashesMatch) {
          identicalNotes.add(id);
        } else if (l.syncVersion > r.syncVersion) {
          notesToPush.add(id);
        } else if (r.syncVersion > l.syncVersion) {
          notesToPull.add(id);
        } else {
          if (l.updatedAt.isAfter(r.updatedAt)) {
            notesToPush.add(id);
          } else if (r.updatedAt.isAfter(l.updatedAt)) {
            notesToPull.add(id);
          } else {
            conflicts.add(id);
          }
        }
      }
    }

    return SyncReconciliation(
      notesToPush: notesToPush,
      notesToPull: notesToPull,
      conflicts: conflicts,
      identicalNotes: identicalNotes,
    );
  }
}
