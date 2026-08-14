import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/protocol/sync_message.dart';

void main() {
  group('SyncMessageCodec', () {
    test('round-trips a pairingRequest envelope', () {
      const message = SyncMessage(
        type: SyncMessageType.pairingRequest,
        senderDeviceId: 'device-a',
        senderDeviceName: 'Pixel 8',
        requestId: 'req-1',
      );

      final framed = SyncMessageCodec.encode(message);
      final decoded = SyncMessageCodec.decode(framed);

      expect(decoded.type, SyncMessageType.pairingRequest);
      expect(decoded.senderDeviceId, 'device-a');
      expect(decoded.senderDeviceName, 'Pixel 8');
      expect(decoded.requestId, 'req-1');
      expect(decoded.bundleBytes, isNull);
      expect(decoded.ack, isNull);
    });

    test('round-trips a dataBundle envelope with raw bytes', () {
      final payload = Uint8List.fromList(
        List.generate(2000, (i) => i % 251),
      );
      final message = SyncMessage(
        type: SyncMessageType.dataBundle,
        senderDeviceId: 'device-a',
        senderDeviceName: 'Phone',
        bundleBytes: payload,
      );

      final framed = SyncMessageCodec.encode(message);
      final decoded = SyncMessageCodec.decode(framed);

      expect(decoded.type, SyncMessageType.dataBundle);
      expect(decoded.bundleBytes, payload);
    });

    test('round-trips an ack envelope', () {
      const message = SyncMessage(
        type: SyncMessageType.ack,
        senderDeviceId: 'device-b',
        senderDeviceName: 'Phone',
        ack: SyncAck(
          receivedNoteIds: ['n1', 'n2'],
          rejectedNoteIds: ['n3'],
        ),
      );

      final framed = SyncMessageCodec.encode(message);
      final decoded = SyncMessageCodec.decode(framed);

      expect(decoded.type, SyncMessageType.ack);
      expect(decoded.ack!.receivedNoteIds, ['n1', 'n2']);
      expect(decoded.ack!.rejectedNoteIds, ['n3']);
    });

    test('handles unicode sender device names', () {
      const message = SyncMessage(
        type: SyncMessageType.pairingAccepted,
        senderDeviceId: 'd1',
        senderDeviceName: 'Galáxï 日本語 📱',
        requestId: 'r1',
      );

      final decoded = SyncMessageCodec.decode(SyncMessageCodec.encode(message));
      expect(decoded.senderDeviceName, 'Galáxï 日本語 📱');
    });

    test('rejects tampered checksums', () {
      final framed = SyncMessageCodec.encode(const SyncMessage(
        type: SyncMessageType.ack,
        senderDeviceId: 'a',
        senderDeviceName: 'b',
        ack: SyncAck(receivedNoteIds: [], rejectedNoteIds: []),
      ));

      // Flip one byte in the payload (offset 36 is the first payload byte).
      final tampered = Uint8List.fromList(framed);
      tampered[36] ^= 0x01;

      expect(
        () => SyncMessageCodec.decode(tampered),
        throwsA(isA<SyncMessageChecksumException>()),
      );
    });

    test('rejects truncated envelopes', () {
      final framed = SyncMessageCodec.encode(const SyncMessage(
        type: SyncMessageType.ack,
        senderDeviceId: 'a',
        senderDeviceName: 'b',
      ));

      expect(
        () => SyncMessageCodec.decode(Uint8List.fromList(framed.sublist(0, 8))),
        throwsA(isA<SyncMessageFormatException>()),
      );
    });

    test('rejects trailing bytes', () {
      final framed = SyncMessageCodec.encode(const SyncMessage(
        type: SyncMessageType.ack,
        senderDeviceId: 'a',
        senderDeviceName: 'b',
      ));
      final padded = Uint8List.fromList([...framed, 0x00, 0x01]);

      expect(
        () => SyncMessageCodec.decode(padded),
        throwsA(isA<SyncMessageFormatException>()),
      );
    });

    test('rejects unknown message types', () {
      // Hand-build a frame whose payload CBOR carries an unknown type name.
      final payload = Uint8List.fromList(cborEncode(CborMap.fromEntries([
        MapEntry(CborString('type'), CborString('nonsense')),
        MapEntry(CborString('senderDeviceId'), CborString('a')),
        MapEntry(CborString('senderDeviceName'), CborString('b')),
      ])));
      final checksum = sha256.convert(payload).bytes;
      final out = BytesBuilder(copy: false);
      final lengthBytes = ByteData(4)
        ..setUint32(0, checksum.length + payload.length, Endian.big);
      out.add(lengthBytes.buffer.asUint8List());
      out.add(checksum);
      out.add(payload);

      expect(
        () => SyncMessageCodec.decode(out.toBytes()),
        throwsA(isA<SyncMessageFormatException>()),
      );
    });

    test('rejects oversized frames', () {
      final framed = Uint8List(8);
      ByteData.sublistView(framed, 0, 4)
          .setUint32(0, SyncMessageCodec.maxFrameLength + 1, Endian.big);

      expect(
        () => SyncMessageCodec.decode(framed),
        throwsA(isA<SyncMessageFormatException>()),
      );
    });
  });

  group('IdentityStore', () {
    test('generates a seed on first use', () async {
      final storage = InMemorySeedStorage();
      final store = IdentityStore(storage: storage);

      final seed = await store.getOrCreateSeed();

      expect(seed, hasLength(32));
      expect(storage.values[IdentityStore.seedKey], isNotNull);
    });

    test('reuses the persisted seed across instances', () async {
      final storage = InMemorySeedStorage();
      final store1 = IdentityStore(storage: storage);
      final store2 = IdentityStore(storage: storage);

      final seed1 = await store1.getOrCreateSeed();
      final seed2 = await store2.getOrCreateSeed();

      expect(seed1, seed2);
      // Store only ever writes once — the second read is served from storage.
      expect(storage.values[IdentityStore.seedKey], isNotNull);
    });

    test('derives a stable key pair from the seed', () async {
      final store = IdentityStore(storage: InMemorySeedStorage());
      final pair1 = await store.getKeyPair();
      final pair2 = await store.getKeyPair();

      final raw1 = pair1.publicKey.raw;
      final raw2 = pair2.publicKey.raw;
      expect(raw1, raw2);
    });

    test('clear() removes the persisted seed', () async {
      final storage = InMemorySeedStorage();
      final store = IdentityStore(storage: storage);

      await store.getOrCreateSeed();
      await store.clear();

      expect(storage.values[IdentityStore.seedKey], isNull);
      // A subsequent read generates a fresh seed.
      final seed = await store.getOrCreateSeed();
      expect(seed, hasLength(32));
    });
  });
}
