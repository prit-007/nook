import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

void main() {
  group('SyncNoteEntry', () {
    test('round-trips through CBOR serialization', () {
      final entry = SyncNoteEntry(
        noteId: 'note-1',
        syncVersion: 3,
        updatedAt: DateTime.utc(2026, 8, 11, 12, 0),
        deviceOriginId: 'device-a',
        noteFields: {
          'title': 'Groceries',
          'type': 'text',
          'pinned': true,
          'colorSeed': '#6750A4',
        },
        checklistItems: [
          {'itemText': 'Milk', 'checked': false, 'sortOrder': 0},
          {'itemText': 'Eggs', 'checked': true, 'sortOrder': 1},
        ],
        attachmentBytes: null,
      );

      final encoded = entry.toCbor();
      final decoded = SyncNoteEntry.fromCbor(encoded);

      expect(decoded.noteId, entry.noteId);
      expect(decoded.syncVersion, entry.syncVersion);
      expect(decoded.updatedAt.millisecondsSinceEpoch,
          entry.updatedAt.millisecondsSinceEpoch);
      expect(decoded.deviceOriginId, entry.deviceOriginId);
      expect(decoded.noteFields['title'], 'Groceries');
      expect(decoded.noteFields['pinned'], true);
      expect(decoded.checklistItems, isNotNull);
      expect(decoded.checklistItems!.length, 2);
      expect(decoded.checklistItems![0]['itemText'], 'Milk');
      expect(decoded.checklistItems![1]['checked'], true);
    });

    test('handles null checklist items and attachments', () {
      final entry = SyncNoteEntry(
        noteId: 'note-2',
        syncVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'device-b',
        noteFields: {'title': 'Simple'},
        checklistItems: null,
        attachmentBytes: null,
      );

      final encoded = entry.toCbor();
      final decoded = SyncNoteEntry.fromCbor(encoded);

      expect(decoded.checklistItems, isNull);
      expect(decoded.attachmentBytes, isNull);
    });

    test('handles binary attachment data', () {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final entry = SyncNoteEntry(
        noteId: 'note-3',
        syncVersion: 2,
        updatedAt: DateTime.utc(2026, 8, 11),
        deviceOriginId: 'device-c',
        noteFields: {'title': 'With Image'},
        checklistItems: null,
        attachmentBytes: fakeBytes,
      );

      final encoded = entry.toCbor();
      final decoded = SyncNoteEntry.fromCbor(encoded);

      expect(decoded.attachmentBytes, fakeBytes);
    });
  });

  group('SyncBundle', () {
    test('round-trips through CBOR serialization', () {
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Pixel 8',
        sentAt: DateTime.utc(2026, 8, 11, 12, 0),
        notes: [
          SyncNoteEntry(
            noteId: 'note-1',
            syncVersion: 3,
            updatedAt: DateTime.utc(2026, 8, 11, 12, 0),
            deviceOriginId: 'device-a',
            noteFields: {'title': 'Groceries'},
            checklistItems: null,
            attachmentBytes: null,
          ),
        ],
      );

      final encoded = bundle.toCbor();
      final decoded = SyncBundle.fromCbor(encoded);

      expect(decoded.protocolVersion, '1.0');
      expect(decoded.senderDeviceId, 'device-a');
      expect(decoded.senderDeviceName, 'Pixel 8');
      expect(decoded.notes.length, 1);
      expect(decoded.notes[0].noteId, 'note-1');
    });

    test('handles empty notes list', () {
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [],
      );

      final encoded = bundle.toCbor();
      final decoded = SyncBundle.fromCbor(encoded);

      expect(decoded.notes, isEmpty);
    });

    test('handles multiple notes', () {
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: List.generate(
          5,
          (i) => SyncNoteEntry(
            noteId: 'note-$i',
            syncVersion: i,
            updatedAt: DateTime.utc(2026, 8, 11),
            deviceOriginId: 'device-a',
            noteFields: {'title': 'Note $i'},
            checklistItems: null,
            attachmentBytes: null,
          ),
        ),
      );

      final encoded = bundle.toCbor();
      final decoded = SyncBundle.fromCbor(encoded);

      expect(decoded.notes.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(decoded.notes[i].noteId, 'note-$i');
      }
    });
  });

  group('SHA-256 checksum', () {
    test('computeChecksum returns consistent hash for same data', () {
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [
          SyncNoteEntry(
            noteId: 'note-1',
            syncVersion: 1,
            updatedAt: DateTime.utc(2026, 8, 11),
            deviceOriginId: 'device-a',
            noteFields: {'title': 'Test'},
            checklistItems: null,
            attachmentBytes: null,
          ),
        ],
      );

      final checksum1 = SyncBundle.computeChecksum(bundle);
      final checksum2 = SyncBundle.computeChecksum(bundle);

      expect(checksum1, checksum2);
      expect(checksum1.length, 64); // SHA-256 hex string
    });

    test('different bundles produce different checksums', () {
      final bundle1 = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [
          SyncNoteEntry(
            noteId: 'note-1',
            syncVersion: 1,
            updatedAt: DateTime.utc(2026, 8, 11),
            deviceOriginId: 'device-a',
            noteFields: {'title': 'Version A'},
            checklistItems: null,
            attachmentBytes: null,
          ),
        ],
      );

      final bundle2 = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [
          SyncNoteEntry(
            noteId: 'note-1',
            syncVersion: 2,
            updatedAt: DateTime.utc(2026, 8, 11),
            deviceOriginId: 'device-a',
            noteFields: {'title': 'Version B'},
            checklistItems: null,
            attachmentBytes: null,
          ),
        ],
      );

      expect(
        SyncBundle.computeChecksum(bundle1),
        isNot(SyncBundle.computeChecksum(bundle2)),
      );
    });

    test('verifyChecksum returns true for valid checksum', () {
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [],
      );

      final checksum = SyncBundle.computeChecksum(bundle);
      expect(SyncBundle.verifyChecksum(bundle, checksum), isTrue);
    });

    test('verifyChecksum returns false for tampered data', () {
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [],
      );

      final checksum = SyncBundle.computeChecksum(bundle);
      // Tamper with the bundle after computing checksum
      final tampered = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        sentAt: DateTime.utc(2026, 8, 11),
        notes: [
          SyncNoteEntry(
            noteId: 'sneaky-note',
            syncVersion: 99,
            updatedAt: DateTime.utc(2026, 8, 11),
            deviceOriginId: 'device-b',
            noteFields: {'title': 'Injected'},
            checklistItems: null,
            attachmentBytes: null,
          ),
        ],
      );

      expect(SyncBundle.verifyChecksum(tampered, checksum), isFalse);
    });
  });

  group('ChunkedTransfer', () {
    test('splitIntoChunks divides data correctly', () {
      final data = Uint8List(256);
      for (var i = 0; i < 256; i++) {
        data[i] = i % 256;
      }

      final chunks = SyncBundle.splitIntoChunks(data, chunkSize: 64);

      expect(chunks.length, 4);
      expect(chunks[0].length, 64);
      expect(chunks[1].length, 64);
      expect(chunks[2].length, 64);
      expect(chunks[3].length, 64);
    });

    test('splitIntoChunks handles exact multiple of chunk size', () {
      final data = Uint8List(128);
      final chunks = SyncBundle.splitIntoChunks(data, chunkSize: 64);

      expect(chunks.length, 2);
      expect(chunks[0].length, 64);
      expect(chunks[1].length, 64);
    });

    test('splitIntoChunks handles data smaller than chunk size', () {
      final data = Uint8List(10);
      final chunks = SyncBundle.splitIntoChunks(data, chunkSize: 64);

      expect(chunks.length, 1);
      expect(chunks[0].length, 10);
    });

    test('reassembleChunks reconstructs original data', () {
      final original = Uint8List.fromList(
        List.generate(200, (i) => i % 256),
      );
      final chunks = SyncBundle.splitIntoChunks(original, chunkSize: 64);
      final reassembled = SyncBundle.reassembleChunks(chunks);

      expect(reassembled, original);
    });

    test('reassembleChunks handles single chunk', () {
      final original = Uint8List.fromList([1, 2, 3]);
      final chunks = SyncBundle.splitIntoChunks(original, chunkSize: 64);
      final reassembled = SyncBundle.reassembleChunks(chunks);

      expect(reassembled, original);
    });
  });

  group('SyncAck', () {
    test('round-trips through CBOR serialization', () {
      const ack = SyncAck(
        receivedNoteIds: ['note-1', 'note-2'],
        rejectedNoteIds: ['note-3'],
      );

      final encoded = ack.toCbor();
      final decoded = SyncAck.fromCbor(encoded);

      expect(decoded.receivedNoteIds, ['note-1', 'note-2']);
      expect(decoded.rejectedNoteIds, ['note-3']);
    });

    test('handles empty lists', () {
      const ack = SyncAck(
        receivedNoteIds: [],
        rejectedNoteIds: [],
      );

      final encoded = ack.toCbor();
      final decoded = SyncAck.fromCbor(encoded);

      expect(decoded.receivedNoteIds, isEmpty);
      expect(decoded.rejectedNoteIds, isEmpty);
    });
  });

  group('SyncHeader', () {
    test('round-trips through CBOR serialization', () {
      const header = SyncHeader(
        bundleSizeBytes: 1024,
        checksum: 'abc123',
        noteCount: 3,
      );

      final encoded = header.toCbor();
      final decoded = SyncHeader.fromCbor(encoded);

      expect(decoded.bundleSizeBytes, 1024);
      expect(decoded.checksum, 'abc123');
      expect(decoded.noteCount, 3);
    });
  });
}
