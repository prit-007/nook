import 'dart:async';
import 'dart:typed_data';

import 'package:dart_libp2p/core/host/host.dart';
import 'package:dart_libp2p/core/network/stream.dart';
import 'package:dart_libp2p/core/peer/peer_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/protocol/sync_message.dart';
import 'package:nook/sync/transport/libp2p_sync_transport.dart';
import 'package:nook/sync/transport/sync_transport.dart';

import 'libp2p_test_host.dart';

/// Reads a single framed [SyncMessage] from [stream] to EOF.
Future<SyncMessage> readMessageToEof(
  P2PStream stream, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final buffer = BytesBuilder(copy: false);
  while (true) {
    await stream.setReadDeadline(DateTime.now().add(timeout));
    final chunk = await stream.read();
    if (chunk.isEmpty) break;
    buffer.add(chunk);
  }
  return SyncMessageCodec.decode(buffer.toBytes());
}

/// A libp2p host that scripted-responds to Nook sync streams, standing in for
/// the remote device. Verifies byte-identical payloads, pairing codes, and
/// ack semantics from the wire.
class ScriptedSyncPeer {
  ScriptedSyncPeer(this.host) {
    host.setStreamHandler(kSyncNotenetProtocol, _handle);
  }

  final Host host;

  final List<Uint8List> receivedBundles = [];
  final List<String> receivedPairingCodes = [];
  final List<String> receivedDeviceNames = [];

  bool respondToPairing = true;
  bool acceptPairing = true;
  bool respondToBundle = true;
  SyncAck ackResponse =
      const SyncAck(receivedNoteIds: ['n1'], rejectedNoteIds: ['n2']);

  Completer<void>? onPairingHandled;
  Completer<void>? onBundleHandled;

  Future<void> _handle(P2PStream stream, PeerId remote) async {
    try {
      final message = await readMessageToEof(stream);
      switch (message.type) {
        case SyncMessageType.pairingRequest:
          receivedPairingCodes.add(message.pairingCode ?? '');
          receivedDeviceNames.add(message.senderDeviceName);
          if (respondToPairing) {
            await stream.write(SyncMessageCodec.encode(SyncMessage(
              type: acceptPairing
                  ? SyncMessageType.pairingAccepted
                  : SyncMessageType.pairingRejected,
              senderDeviceId: host.id.toString(),
              senderDeviceName: 'Peer',
            )));
            await stream.closeWrite();
            await stream.close();
          }
          onPairingHandled?.complete();

        case SyncMessageType.dataBundle:
          if (message.bundleBytes != null) {
            receivedBundles.add(message.bundleBytes!);
          }
          if (respondToBundle) {
            await stream.write(SyncMessageCodec.encode(SyncMessage(
              type: SyncMessageType.ack,
              senderDeviceId: host.id.toString(),
              senderDeviceName: 'Peer',
              ack: ackResponse,
            )));
            await stream.closeWrite();
            await stream.close();
          }
          onBundleHandled?.complete();

        case SyncMessageType.ack:
        case SyncMessageType.pairingAccepted:
        case SyncMessageType.pairingRejected:
          await stream.close();
      }
    } catch (_) {
      await stream.close().catchError((_) {});
    }
  }

  SyncDevice asDevice() => SyncDevice(
        deviceId: host.id.toString(),
        deviceName: 'Peer',
        isOnline: true,
        multiaddresses: [loopbackUdxAddr(host)!],
      );
}

void main() {
  late ScriptedSyncPeer peer;

  setUp(() async {
    peer = ScriptedSyncPeer(await createLoopbackHost());
  });

  tearDown(() async {
    await peer.host.close();
  });

  Libp2pSyncTransport makeSender({Duration? ackTimeout}) => Libp2pSyncTransport(
        localDeviceName: 'Sender',
        identityStore: IdentityStore(storage: InMemorySeedStorage()),
        pairingTimeout: const Duration(seconds: 10),
        ackTimeout: ackTimeout ?? const Duration(seconds: 10),
      );

  group('Libp2pSyncTransport round-trip', () {
    test('pair -> accept -> sendData -> ack with byte-identical payload',
        () async {
      final sender = makeSender();
      final errors = <String>[];
      sender.sessionStateStream
          .listen((s) => s.error == null ? null : errors.add(s.error!));
      await sender.initialize();

      final device = peer.asDevice();

      // Pairing (scripted peer accepts).
      final paired =
          await sender.connectToDevice(device, pairingCode: '123456');
      expect(paired, isTrue, reason: 'errors: $errors');
      expect(peer.receivedPairingCodes, ['123456']);
      expect(peer.receivedDeviceNames, ['Sender']);

      // Transfer.
      final payload = Uint8List.fromList(List.generate(5000, (i) => i % 251));
      final ack = await sender.sendData(payload);

      expect(ack, isNotNull);
      expect(ack!.receivedNoteIds, ['n1']);
      expect(ack.rejectedNoteIds, ['n2']);
      expect(peer.receivedBundles, hasLength(1));
      expect(peer.receivedBundles.first, payload,
          reason: 'peer must receive the exact bundle bytes');

      await sender.disconnect();
    });

    test('pairing rejected surfaces a rejected outcome', () async {
      final sender = makeSender();
      peer.acceptPairing = false;

      final outcomes = <SyncOutcomeCategory>[];
      sender.sessionStateStream.listen((s) {
        if (s.error != null) outcomes.add(s.outcome!);
      });
      await sender.initialize();

      final paired =
          await sender.connectToDevice(peer.asDevice(), pairingCode: '000000');

      await pumpEventQueue();

      expect(paired, isFalse);
      expect(outcomes, contains(SyncOutcomeCategory.rejected));

      await sender.disconnect();
    });

    test('missing ack times out with a timedOut outcome', () async {
      final sender = makeSender(ackTimeout: const Duration(seconds: 3));
      peer.respondToBundle = false;

      final outcomes = <SyncOutcomeCategory>[];
      sender.sessionStateStream.listen((s) {
        if (s.error != null) outcomes.add(s.outcome!);
      });
      await sender.initialize();

      expect(await sender.connectToDevice(peer.asDevice()), isTrue);

      final ack = await sender.sendData(
        Uint8List.fromList([1, 2, 3]),
      );

      await pumpEventQueue();

      expect(ack, isNull);
      expect(outcomes, contains(SyncOutcomeCategory.timedOut));

      await sender.disconnect();
    });

    test('pairing timeout surfaces a timedOut outcome', () async {
      final sender = Libp2pSyncTransport(
        localDeviceName: 'Sender',
        identityStore: IdentityStore(storage: InMemorySeedStorage()),
        pairingTimeout: const Duration(seconds: 3),
      );
      peer.respondToPairing = false;

      final outcomes = <SyncOutcomeCategory>[];
      sender.sessionStateStream.listen((s) {
        if (s.error != null) outcomes.add(s.outcome!);
      });
      await sender.initialize();

      final paired = await sender.connectToDevice(peer.asDevice());

      await pumpEventQueue();

      expect(paired, isFalse);
      expect(outcomes, contains(SyncOutcomeCategory.timedOut));

      await sender.disconnect();
    });

    test('cancel aborts a pending transfer', () async {
      final sender = makeSender(ackTimeout: const Duration(seconds: 30));
      peer.respondToBundle = false;

      await sender.initialize();
      expect(await sender.connectToDevice(peer.asDevice()), isTrue);

      final sendFuture = sender.sendData(Uint8List.fromList([1, 2, 3]));
      // Give the transfer a moment to open the stream, then cancel.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await sender.disconnect();

      final ack = await sendFuture.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      expect(ack, isNull);
    });
  });

  group('Libp2pSyncTransport identity', () {
    test('getCurrentDeviceId is stable across instances with the same seed',
        () async {
      final store = IdentityStore(storage: InMemorySeedStorage());
      final a = Libp2pSyncTransport(identityStore: store);
      final b = Libp2pSyncTransport(identityStore: store);

      final idA = await a.getCurrentDeviceId();
      final idB = await b.getCurrentDeviceId();

      expect(idA, idB);
      expect(idA, isNotNull);
      expect(idA!.length, greaterThan(10));

      await a.disconnect();
      await b.disconnect();
    });

    test('connectToDevice with no addresses fails cleanly', () async {
      final sender = makeSender();
      await sender.initialize();

      final paired = await sender.connectToDevice(const SyncDevice(
        deviceId: '12D3KooWQ4p6yA1b9cX2dE3fG4hI5jK6lM7nO8pQ9rS',
        deviceName: 'Peer',
        isOnline: true,
      ));

      expect(paired, isFalse);

      await sender.disconnect();
    });
  });
}
