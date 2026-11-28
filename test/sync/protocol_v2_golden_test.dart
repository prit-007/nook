import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/pipeline/sync_bundle_packer.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/protocol/sync_message.dart';

void main() {
  group('Protocol v2 golden & field matrix', () {
    test('SyncMessageCodec round-trips dataBundle with SHA-256 framing', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final msg = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'dev-a',
        senderDeviceName: 'Pixel 9',
        protocolVersion: SyncMessage.currentProtocolVersion,
        schemaVersion: SyncMessage.currentSchemaVersion,
        bundleBytes: payload,
      );

      final wire = SyncMessageCodec.encode(msg);
      final decoded = SyncMessageCodec.decode(wire);

      expect(decoded.type, SyncMessageType.dataBundle);
      expect(decoded.senderDeviceId, 'dev-a');
      expect(decoded.senderDeviceName, 'Pixel 9');
      expect(decoded.bundleBytes, equals(payload));

      // Flipping a payload byte triggers checksum failure before CBOR decode.
      final corrupted = Uint8List.fromList(wire);
      corrupted[corrupted.length - 1] ^= 0xff;
      expect(
        () => SyncMessageCodec.decode(corrupted),
        throwsA(isA<SyncMessageChecksumException>()),
      );
    });

    test('MergeResolver.syncFieldMatrix documents v2 fields', () {
      expect(
        MergeResolver.syncFieldMatrix.keys,
        containsAll([
          'notes.archived',
          'notes.deleted',
          'notes.deletedAt',
          'notes.updatedAt',
          'notes.hlc',
          'note_tags.deleted',
        ]),
      );
    });

    test('SyncBundlePacker packs archived, deleted, deletedAt, updatedAt, hlc',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final repo = NoteRepository(db);
      final note = await repo.createNote(
        id: 'packed-v2-note',
        title: 'Packed Note',
        type: NoteType.text,
        deviceOriginId: 'dev-a',
      );
      await db.customUpdate(
        'UPDATE notes SET hlc = ? WHERE id = ?',
        variables: [
          Variable.withString('2026-11-28T10:00:00Z-0001-dev-a'),
          Variable.withString(note.id)
        ],
        updates: {db.notes},
      );
      await repo.archiveNote(note.id);
      await repo.softDelete(note.id);

      final packer = SyncBundlePacker(db: db);
      final bundle = await packer.pack(
        noteIds: [note.id],
        senderDeviceId: 'dev-a',
        senderDeviceName: 'Pixel 9',
      );

      expect(bundle.notes, hasLength(1));
      final fields = bundle.notes.single.noteFields;
      expect(fields['archived'], isTrue);
      expect(fields['deleted'], isTrue);
      expect(fields['deletedAt'], isNotNull);
      expect(fields['updatedAt'], isNotNull);
      expect(fields.containsKey('hlc'), isTrue);
    });

    test('SyncAck round-trips cleanly', () {
      const ack = SyncAck(
        receivedNoteIds: ['n1', 'n2'],
        rejectedNoteIds: ['n3'],
      );
      const msg = SyncMessage(
        type: SyncMessageType.ack,
        senderDeviceId: 'dev-b',
        senderDeviceName: 'Linux',
        ack: ack,
      );
      final decoded = SyncMessageCodec.decode(SyncMessageCodec.encode(msg));
      expect(decoded.ack?.receivedNoteIds, equals(['n1', 'n2']));
      expect(decoded.ack?.rejectedNoteIds, equals(['n3']));
    });
  });
}
