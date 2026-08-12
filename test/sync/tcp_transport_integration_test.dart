import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/sync_session_cipher.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/transport/tcp_sync_transport.dart';
import 'package:nook/sync/transport/sync_transport.dart';

/// Persistent buffered frame reader so a single-subscription socket can be
/// read frame-by-frame (mirrors the transport's own approach). Frames are
/// decrypted when [cipher] is active.
class FrameReader {
  FrameReader(this._socket, {this.cipher}) {
    _socket.listen(
      (chunk) {
        _buffer.addAll(chunk);
        _pump();
      },
      onError: (Object e) => _failAll(e),
      onDone: () => _failAll(StateError('Socket closed')),
    );
  }

  final Socket _socket;
  final SyncSessionCipher? cipher;
  final _buffer = <int>[];
  final _frames = <String>[];
  final _waiters = <Completer<String>>[];
  bool _done = false;

  Future<String> readFrame() async {
    if (_frames.isNotEmpty) return _frames.removeAt(0);
    if (_done) throw StateError('Reader closed');
    final completer = Completer<String>();
    _waiters.add(completer);
    return completer.future;
  }

  void _pump() {
    while (_buffer.length >= 4) {
      final len =
          ByteData.sublistView(Uint8List.fromList(_buffer.sublist(0, 4)))
              .getUint32(0, Endian.big);
      if (_buffer.length < 4 + len) break;
      final payload = _buffer.sublist(4, 4 + len);
      _buffer.removeRange(0, 4 + len);
      _dispatch(payload);
    }
  }

  void _dispatch(List<int> payload) {
    Future<void> deliver() async {
      final decrypted =
          cipher == null ? payload : await cipher!.decryptFrame(payload);
      final text = utf8.decode(decrypted);
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete(text);
      } else {
        _frames.add(text);
      }
    }

    deliver();
  }

  void _failAll(Object error) {
    if (_done) return;
    _done = true;
    for (final w in _waiters) {
      if (!w.isCompleted) w.completeError(error);
    }
    _waiters.clear();
  }

  Future<void> close() => _socket.close();
}

Future<void> writeFrame(
  Socket socket,
  String payload, {
  SyncSessionCipher? cipher,
}) async {
  final bytes = cipher == null
      ? utf8.encode(payload)
      : await cipher.encryptFrame(utf8.encode(payload));
  final lengthBytes = ByteData(4)..setUint32(0, bytes.length, Endian.big);
  socket.add(lengthBytes.buffer.asUint8List());
  socket.add(bytes);
  await socket.flush();
}

/// Scripted peer performing the ECDH handshake + encrypted reads/writes.
class ScriptedPeer {
  ScriptedPeer(this.socket);

  final Socket socket;
  final cipher = SyncSessionCipher();

  Future<void> handshake({
    required String remoteDeviceId,
    required String remoteDeviceName,
    String? expectPairingCode,
  }) async {
    final reader = FrameReader(socket, cipher: cipher);
    await cipher.beginHandshake();

    // 1. Read sender hello.
    final hello = jsonDecode(await reader.readFrame()) as Map<String, dynamic>;
    expect(hello['deviceName'], remoteDeviceName);
    if (expectPairingCode != null) {
      expect(hello['pairingCode'], expectPairingCode);
    }
    final senderKey = hello['publicKey'] as String;
    await cipher.completeKeyExchange(base64Decode(senderKey));

    // 2. Reply with our identity (with our public key).
    await writeFrame(
      socket,
      jsonEncode({
        'deviceId': remoteDeviceId,
        'deviceName': 'Peer',
        'protocolVersion': kSyncProtocolVersion,
        'publicKey': base64Encode(cipher.exportPublicKey()),
      }),
    );

    // 3. Approve pairing (now encrypted).
    await writeFrame(
      socket,
      jsonEncode({'type': 'pairing_confirm'}),
      cipher: cipher,
    );
    _reader = reader;
  }

  FrameReader? _reader;

  FrameReader get reader => _reader!;

  Future<String> readEncryptedFrame() => reader.readFrame();

  Future<void> writeEncryptedFrame(String payload) =>
      writeFrame(socket, payload, cipher: cipher);
}

/// Loopback integration test for [TcpSyncTransport].
///
/// Exercises the real TCP + length-prefixed framing against a scripted server
/// bound on 127.0.0.1 (no mDNS/bonsoir, which needs platform channels). Covers
/// the encrypted ECDH handshake, chunked transfer, SHA-256 checksum, and ack.
void main() {
  group('TcpSyncTransport loopback', () {
    late ServerSocket server;
    late TcpSyncTransport sender;

    setUp(() async {
      server = await ServerSocket.bind('127.0.0.1', 0, shared: true);
      sender = TcpSyncTransport(
        localDeviceName: 'Loopback Sender',
        pairingTimeout: const Duration(seconds: 5),
        ackTimeout: const Duration(seconds: 5),
      );
      await sender.initialize();
    });

    tearDown(() async {
      await sender.disconnect();
      await server.close();
    });

    SyncDevice functionDevice() => SyncDevice(
          deviceId: 'peer-1',
          deviceName: 'Peer',
          isOnline: true,
          hostAddress: '127.0.0.1',
          port: server.port,
        );

    test('encrypted pairing handshake + transfer + ack round-trip', () async {
      final payload = Uint8List.fromList(List.generate(3000, (i) => i % 251));
      final expectedChecksum = sha256.convert(payload).toString();

      final connectFuture =
          sender.connectToDevice(functionDevice(), pairingCode: '123456');

      final errors = <String>[];
      sender.sessionStateStream.listen((s) {
        if (s.error != null) errors.add('ERR: ${s.error}');
      });

      final socket = await server.first;
      final peer = ScriptedPeer(socket);
      await peer.handshake(
        remoteDeviceId: 'peer-1',
        remoteDeviceName: 'Loopback Sender',
        expectPairingCode: '123456',
      );

      expect(await connectFuture, isTrue,
          reason: 'errors: ${errors.join(' | ')}');

      // Receive the (encrypted) bundle.
      final sendFuture = sender.sendData(payload);

      // Header.
      final header =
          jsonDecode(await peer.readEncryptedFrame()) as Map<String, dynamic>;
      expect(header['type'], 'sync_header');
      expect(header['checksum'], expectedChecksum);

      // Chunks.
      final chunks = <Uint8List>[];
      final total = header['totalChunks'] as int;
      while (chunks.length < total) {
        final frame = jsonDecode(await peer.readEncryptedFrame());
        expect(frame['type'], 'sync_chunk');
        chunks.add(base64Decode(frame['data'] as String));
      }
      final reassembled = SyncBundle.reassembleChunks(chunks);
      expect(reassembled, payload);
      expect(sha256.convert(reassembled).toString(), expectedChecksum);

      // Send ack back (encrypted).
      final ack =
          const SyncAck(receivedNoteIds: ['n1'], rejectedNoteIds: ['n2']);
      await peer.writeEncryptedFrame(jsonEncode({
        'type': 'sync_ack',
        'data': base64Encode(ack.toCbor()),
      }));

      final result = await sendFuture;
      expect(result, isNotNull);
      expect(result!.receivedNoteIds, ['n1']);
      expect(result.rejectedNoteIds, ['n2']);
      await peer.socket.close();
    });

    test('sender rejects a peer that does not perform key exchange', () async {
      final connectFuture =
          sender.connectToDevice(functionDevice(), pairingCode: '999');

      final socket = await server.first;
      final reader = FrameReader(socket);
      await reader.readFrame(); // hello (plaintext)
      // Reply with an identity that omits the public key.
      await writeFrame(
          socket,
          jsonEncode({
            'deviceId': 'peer-1',
            'deviceName': 'Peer',
            'protocolVersion': kSyncProtocolVersion,
          }));

      expect(await connectFuture, isFalse);
      await reader.close();
    });

    test('pairing is rejected when receiver does not confirm', () async {
      final connectFuture =
          sender.connectToDevice(functionDevice(), pairingCode: '999');

      final socket = await server.first;
      final peer = ScriptedPeer(socket);
      final reader = FrameReader(socket);
      await peer.cipher.beginHandshake();
      final hello =
          jsonDecode(await reader.readFrame()) as Map<String, dynamic>;
      await peer.cipher
          .completeKeyExchange(base64Decode(hello['publicKey'] as String));

      // Send identity but reject pairing instead of confirming.
      await writeFrame(
          socket,
          jsonEncode({
            'deviceId': 'peer-1',
            'deviceName': 'Peer',
            'protocolVersion': kSyncProtocolVersion,
            'publicKey': base64Encode(peer.cipher.exportPublicKey()),
          }));
      await writeFrame(socket, jsonEncode({'type': 'pairing_rejected'}),
          cipher: peer.cipher);

      expect(await connectFuture, isFalse);
      await reader.close();
    });
  });
}
