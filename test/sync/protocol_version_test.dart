import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/protocol/sync_message.dart';

void main() {
  group('Protocol version & capability negotiation (Phase 2.1)', () {
    test('SyncMessage defaults protocolVersion and schemaVersion cleanly', () {
      const msg = SyncMessage(
        type: SyncMessageType.pairingRequest,
        senderDeviceId: 'dev-1',
        senderDeviceName: 'Pixel',
      );

      expect(msg.protocolVersion, SyncMessage.currentProtocolVersion);
      expect(msg.schemaVersion, SyncMessage.currentSchemaVersion);
      expect(msg.protocolVersion, 1);
      expect(msg.schemaVersion, 7);
    });

    test(
        'SyncMessageCodec round-trips explicit protocolVersion and schemaVersion',
        () {
      const msg = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'dev-1',
        senderDeviceName: 'Laptop',
        protocolVersion: 2,
        schemaVersion: 9,
      );

      final encoded = SyncMessageCodec.encode(msg);
      final decoded = SyncMessageCodec.decode(encoded);

      expect(decoded.protocolVersion, 2);
      expect(decoded.schemaVersion, 9);
    });

    test(
        'SyncMessageCodec decodes legacy payload without version fields using defaults',
        () {
      final payload = Uint8List.fromList(cborEncode(CborMap.fromEntries([
        MapEntry(CborString('type'), CborString('ack')),
        MapEntry(CborString('senderDeviceId'), CborString('legacy-dev')),
        MapEntry(CborString('senderDeviceName'), CborString('Legacy Phone')),
      ])));
      final checksum = sha256.convert(payload).bytes;
      final length = checksum.length + payload.length;
      final lengthBytes = ByteData(4)..setUint32(0, length, Endian.big);
      final framed = Uint8List.fromList([
        ...lengthBytes.buffer.asUint8List(),
        ...checksum,
        ...payload,
      ]);

      final decoded = SyncMessageCodec.decode(framed);
      expect(decoded.type, SyncMessageType.ack);
      expect(decoded.senderDeviceId, 'legacy-dev');
      expect(decoded.protocolVersion, SyncMessage.currentProtocolVersion);
      expect(decoded.schemaVersion, SyncMessage.currentSchemaVersion);
    });

    test('negotiateCapabilities returns compatible for matching versions', () {
      const remote = SyncMessage(
        type: SyncMessageType.pairingRequest,
        senderDeviceId: 'dev-2',
        senderDeviceName: 'Tablet',
        protocolVersion: 1,
        schemaVersion: 7,
      );

      final result = SyncCapabilityNegotiator.negotiateMessage(remote);
      expect(result.status, CapabilityNegotiationStatus.compatible);
      expect(result.isCompatible, isTrue);
      expect(result.agreedProtocolVersion, 1);
      expect(result.agreedSchemaVersion, 7);
      expect(result.reason, isNull);
    });

    test('negotiateCapabilities degrades cleanly for older supported schema',
        () {
      const remote = SyncMessage(
        type: SyncMessageType.pairingRequest,
        senderDeviceId: 'dev-2',
        senderDeviceName: 'Old Tablet',
        protocolVersion: 1,
        schemaVersion: 5,
      );

      final result = SyncCapabilityNegotiator.negotiateMessage(remote);
      expect(result.status, CapabilityNegotiationStatus.degraded);
      expect(result.isCompatible, isTrue);
      expect(result.agreedProtocolVersion, 1);
      expect(result.agreedSchemaVersion, 5);
      expect(result.reason, isNotNull);
    });

    test('negotiateCapabilities refuses incompatible protocol version', () {
      const remoteTooNew = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'dev-2',
        senderDeviceName: 'Future Phone',
        protocolVersion: 99,
        schemaVersion: 7,
      );

      final resNew = SyncCapabilityNegotiator.negotiateMessage(remoteTooNew);
      expect(resNew.status, CapabilityNegotiationStatus.incompatible);
      expect(resNew.isCompatible, isFalse);
      expect(resNew.reason, contains('protocol'));

      const remoteTooOld = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'dev-2',
        senderDeviceName: 'Ancient Phone',
        protocolVersion: 0,
        schemaVersion: 7,
      );

      final resOld = SyncCapabilityNegotiator.negotiateMessage(remoteTooOld);
      expect(resOld.status, CapabilityNegotiationStatus.incompatible);
      expect(resOld.isCompatible, isFalse);
    });

    test('negotiateCapabilities refuses incompatible schema version', () {
      const remoteNewSchema = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'dev-2',
        senderDeviceName: 'Newer App',
        protocolVersion: 1,
        schemaVersion: 99,
      );

      final resNew = SyncCapabilityNegotiator.negotiateMessage(remoteNewSchema);
      expect(resNew.status, CapabilityNegotiationStatus.incompatible);
      expect(resNew.isCompatible, isFalse);
      expect(resNew.reason, contains('schema'));

      const remoteZeroSchema = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'dev-2',
        senderDeviceName: 'Broken App',
        protocolVersion: 1,
        schemaVersion: 0,
      );

      final resOld =
          SyncCapabilityNegotiator.negotiateMessage(remoteZeroSchema);
      expect(resOld.status, CapabilityNegotiationStatus.incompatible);
      expect(resOld.isCompatible, isFalse);
    });

    test(
        'MergeResolver.applyIncomingIfCompatible refuses incompatible message without corrupting DB',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final resolver = MergeResolver(noteRepo, NotebookRepository(db));

      final local = await noteRepo.createNote(
        id: 'note-1',
        title: 'Local Safe Note',
        type: NoteType.text,
        deviceOriginId: 'dev-local',
      );

      final entry = SyncNoteEntry(
        noteId: local.id,
        syncVersion: 10,
        updatedAt: DateTime.utc(2026, 12, 1),
        deviceOriginId: 'dev-local',
        noteFields: {'title': 'Corrupted Remote', 'type': 'text'},
      );

      const incompatibleMsg = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'dev-remote',
        senderDeviceName: 'Future Device',
        protocolVersion: 2,
        schemaVersion: 7,
      );

      final result = await resolver.applyIncomingIfCompatible(
        entry,
        remoteMessage: incompatibleMsg,
      );

      expect(result.negotiation.isCompatible, isFalse);
      expect(result.action, isNull);
      expect(result.error, isNotNull);

      final after = await noteRepo.getNoteById(local.id);
      expect(after!.title, 'Local Safe Note');
      expect(after.syncVersion, local.syncVersion);
    });
  });
}
