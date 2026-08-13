import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/transport/libp2p_sync_transport.dart';
import 'package:nook/sync/transport/sync_transport.dart';

void main() {
  test(
    'two Libp2pSyncTransport instances complete pair + transfer over loopback UDX',
    () async {
      final receiver = Libp2pSyncTransport(
        localDeviceName: 'Receiver',
        identityStore: IdentityStore(storage: InMemorySeedStorage()),
        pairingTimeout: const Duration(seconds: 15),
        ackTimeout: const Duration(seconds: 15),
        listenAddress: '/ip4/127.0.0.1/udp/0/udx',
      );
      final sender = Libp2pSyncTransport(
        localDeviceName: 'Sender',
        identityStore: IdentityStore(storage: InMemorySeedStorage()),
        pairingTimeout: const Duration(seconds: 15),
        ackTimeout: const Duration(seconds: 15),
        listenAddress: '/ip4/127.0.0.1/udp/0/udx',
      );

      await receiver.initialize();
      await sender.initialize();

      // Receiver surfaces the incoming pairing request.
      final pairingDone = Completer<void>();
      final pairingStream = receiver.pairingRequestStream;
      final pairingSub = pairingStream.listen((request) async {
        expect(request.pairingCode, '654321');
        expect(request.remoteDeviceName, 'Sender');
        await receiver.respondToPairing(request, true);
        pairingDone.complete();
      });

      // Receiver captures the bundle and acks it.
      final received = <Uint8List>[];
      final bytesSub = receiver.bytesReceivedStream.listen((bytes) async {
        received.add(Uint8List.fromList(bytes));
        await receiver.sendAck(const SyncAck(
          receivedNoteIds: ['n1'],
          rejectedNoteIds: ['n2'],
        ).toCbor());
      });

      // Sender pairs with the receiver (addressed directly, no mDNS needed).
      final receiverId = (await receiver.getCurrentDeviceId())!;
      final addrs = receiver.localMultiaddresses;

      final paired = await sender.connectToDevice(
          SyncDevice(
            deviceId: receiverId,
            deviceName: 'Receiver',
            isOnline: true,
            multiaddresses: addrs,
          ),
          pairingCode: '654321');

      expect(paired, isTrue);

      // Sender transfers a payload.
      final payload = Uint8List.fromList(List.generate(12000, (i) => i % 253));
      final ack = await sender.sendData(payload);

      expect(ack, isNotNull);
      expect(ack!.receivedNoteIds, ['n1']);
      expect(ack.rejectedNoteIds, ['n2']);

      // Receiver got the exact bytes.
      await pairingDone.future;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(received, hasLength(1));
      expect(received.first, payload,
          reason: 'receiver must get byte-identical bundle');

      await pairingSub.cancel();
      await bytesSub.cancel();
      await sender.disconnect();
      await receiver.disconnect();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
