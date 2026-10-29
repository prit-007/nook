import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/protocol/sync_digest.dart';

void main() {
  group('SyncDigest CBOR serialization', () {
    test('encodes and decodes SyncDigest losslessly', () {
      final now = DateTime.utc(2026, 10, 29, 14, 0, 0);
      final digest = SyncDigest(
        deviceId: 'device-alpha',
        entries: [
          NoteDigestEntry(
            noteId: 'note-1',
            updatedAt: now,
            syncVersion: 2,
            deleted: false,
            contentHash: 'hash-abc-123',
          ),
          NoteDigestEntry(
            noteId: 'note-2',
            updatedAt: now.subtract(const Duration(minutes: 5)),
            syncVersion: 1,
            deleted: true,
            contentHash: 'hash-def-456',
          ),
        ],
      );

      final cborBytes = digest.toCbor();
      expect(cborBytes, isA<Uint8List>());
      expect(cborBytes.isNotEmpty, isTrue);

      final decoded = SyncDigest.fromCbor(cborBytes);
      expect(decoded.deviceId, 'device-alpha');
      expect(decoded.entries.length, 2);

      final entry1 = decoded.entries[0];
      expect(entry1.noteId, 'note-1');
      expect(
          entry1.updatedAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(entry1.syncVersion, 2);
      expect(entry1.deleted, isFalse);
      expect(entry1.contentHash, 'hash-abc-123');

      final entry2 = decoded.entries[1];
      expect(entry2.noteId, 'note-2');
      expect(entry2.deleted, isTrue);
      expect(entry2.contentHash, 'hash-def-456');
    });

    test('handles empty entries list', () {
      final digest = const SyncDigest(
        deviceId: 'device-empty',
        entries: [],
      );

      final decoded = SyncDigest.fromCbor(digest.toCbor());
      expect(decoded.deviceId, 'device-empty');
      expect(decoded.entries, isEmpty);
    });
  });

  group('SyncReconciliation', () {
    final t0 = DateTime.utc(2026, 10, 29, 10, 0, 0);
    final t1 = DateTime.utc(2026, 10, 29, 11, 0, 0);
    final t2 = DateTime.utc(2026, 10, 29, 12, 0, 0);

    test('identifies identical notes that require no transfer', () {
      final local = SyncDigest(
        deviceId: 'local',
        entries: [
          NoteDigestEntry(
            noteId: 'note-same',
            updatedAt: t1,
            syncVersion: 3,
            deleted: false,
            contentHash: 'same-hash',
          ),
        ],
      );
      final remote = SyncDigest(
        deviceId: 'remote',
        entries: [
          NoteDigestEntry(
            noteId: 'note-same',
            updatedAt: t1,
            syncVersion: 3,
            deleted: false,
            contentHash: 'same-hash',
          ),
        ],
      );

      final recon = SyncReconciliation.reconcile(local: local, remote: remote);
      expect(recon.identicalNotes, ['note-same']);
      expect(recon.notesToPush, isEmpty);
      expect(recon.notesToPull, isEmpty);
      expect(recon.conflicts, isEmpty);
    });

    test('pushes note when local has it but remote does not', () {
      final local = SyncDigest(
        deviceId: 'local',
        entries: [
          NoteDigestEntry(
            noteId: 'note-local-only',
            updatedAt: t1,
            syncVersion: 1,
            deleted: false,
            contentHash: 'hash-1',
          ),
        ],
      );
      final remote = const SyncDigest(
        deviceId: 'remote',
        entries: [],
      );

      final recon = SyncReconciliation.reconcile(local: local, remote: remote);
      expect(recon.notesToPush, ['note-local-only']);
      expect(recon.notesToPull, isEmpty);
      expect(recon.identicalNotes, isEmpty);
    });

    test('pulls note when remote has it but local does not', () {
      final local = const SyncDigest(
        deviceId: 'local',
        entries: [],
      );
      final remote = SyncDigest(
        deviceId: 'remote',
        entries: [
          NoteDigestEntry(
            noteId: 'note-remote-only',
            updatedAt: t1,
            syncVersion: 1,
            deleted: false,
            contentHash: 'hash-remote',
          ),
        ],
      );

      final recon = SyncReconciliation.reconcile(local: local, remote: remote);
      expect(recon.notesToPull, ['note-remote-only']);
      expect(recon.notesToPush, isEmpty);
    });

    test('pushes when local has strictly higher syncVersion', () {
      final local = SyncDigest(
        deviceId: 'local',
        entries: [
          NoteDigestEntry(
            noteId: 'note-edit',
            updatedAt: t2,
            syncVersion: 5,
            contentHash: 'hash-v5',
          ),
        ],
      );
      final remote = SyncDigest(
        deviceId: 'remote',
        entries: [
          NoteDigestEntry(
            noteId: 'note-edit',
            updatedAt: t1,
            syncVersion: 4,
            contentHash: 'hash-v4',
          ),
        ],
      );

      final recon = SyncReconciliation.reconcile(local: local, remote: remote);
      expect(recon.notesToPush, ['note-edit']);
      expect(recon.notesToPull, isEmpty);
    });

    test('pulls when remote has strictly higher syncVersion', () {
      final local = SyncDigest(
        deviceId: 'local',
        entries: [
          NoteDigestEntry(
            noteId: 'note-edit',
            updatedAt: t1,
            syncVersion: 2,
            contentHash: 'hash-v2',
          ),
        ],
      );
      final remote = SyncDigest(
        deviceId: 'remote',
        entries: [
          NoteDigestEntry(
            noteId: 'note-edit',
            updatedAt: t2,
            syncVersion: 3,
            contentHash: 'hash-v3',
          ),
        ],
      );

      final recon = SyncReconciliation.reconcile(local: local, remote: remote);
      expect(recon.notesToPull, ['note-edit']);
      expect(recon.notesToPush, isEmpty);
    });

    test(
        'reconciles simultaneous two-way notes (both push and pull in one round)',
        () {
      final local = SyncDigest(
        deviceId: 'local',
        entries: [
          NoteDigestEntry(
            noteId: 'note-to-push',
            updatedAt: t2,
            syncVersion: 2,
            contentHash: 'push-hash',
          ),
          NoteDigestEntry(
            noteId: 'note-identical',
            updatedAt: t0,
            syncVersion: 1,
            contentHash: 'same',
          ),
        ],
      );
      final remote = SyncDigest(
        deviceId: 'remote',
        entries: [
          NoteDigestEntry(
            noteId: 'note-to-pull',
            updatedAt: t2,
            syncVersion: 2,
            contentHash: 'pull-hash',
          ),
          NoteDigestEntry(
            noteId: 'note-identical',
            updatedAt: t0,
            syncVersion: 1,
            contentHash: 'same',
          ),
        ],
      );

      final recon = SyncReconciliation.reconcile(local: local, remote: remote);
      expect(recon.notesToPush, ['note-to-push']);
      expect(recon.notesToPull, ['note-to-pull']);
      expect(recon.identicalNotes, ['note-identical']);
      expect(recon.conflicts, isEmpty);
    });

    test(
        'detects conflict when equal syncVersion but differing hash and simultaneous edits',
        () {
      final local = SyncDigest(
        deviceId: 'local',
        entries: [
          NoteDigestEntry(
            noteId: 'note-conflict',
            updatedAt: t1,
            syncVersion: 3,
            contentHash: 'local-hash',
          ),
        ],
      );
      final remote = SyncDigest(
        deviceId: 'remote',
        entries: [
          NoteDigestEntry(
            noteId: 'note-conflict',
            updatedAt: t1,
            syncVersion: 3,
            contentHash: 'remote-hash',
          ),
        ],
      );

      final recon = SyncReconciliation.reconcile(local: local, remote: remote);
      expect(recon.conflicts, ['note-conflict']);
      expect(recon.notesToPush, isEmpty);
      expect(recon.notesToPull, isEmpty);
    });
  });
}
