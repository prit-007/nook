import 'dart:async';
import 'dart:typed_data';

import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/network/context.dart';
import 'package:dart_libp2p/core/peer/addr_info.dart';
import 'package:flutter_test/flutter_test.dart';

import 'libp2p_test_host.dart';

void main() {
  test('two loopback UDX hosts can open a stream and exchange data', () async {
    final peer = await createLoopbackHost();
    final completer = Completer<Uint8List>();

    peer.setStreamHandler('/smoke/1.0.0', (stream, remote) async {
      final buffer = BytesBuilder();
      while (true) {
        final chunk = await stream.read();
        if (chunk.isEmpty) break;
        buffer.add(chunk);
      }
      completer.complete(buffer.toBytes());
      await stream.write(Uint8List.fromList('pong'.codeUnits));
      await stream.close();
    });

    final host = await createLoopbackHost();
    final addr = loopbackUdxAddr(peer)!;
    await host.connect(AddrInfo(peer.id, [MultiAddr(addr)]),
        context: Context(timeout: const Duration(seconds: 15)));

    final stream = await host.newStream(peer.id, ['/smoke/1.0.0'],
        Context(timeout: const Duration(seconds: 15)));
    await stream.write(Uint8List.fromList('hello'.codeUnits));
    await stream.closeWrite();

    expect(await completer.future, Uint8List.fromList('hello'.codeUnits));

    final response = BytesBuilder();
    while (true) {
      await stream
          .setReadDeadline(DateTime.now().add(const Duration(seconds: 5)));
      final chunk = await stream.read();
      if (chunk.isEmpty) break;
      response.add(chunk);
    }
    expect(response.toBytes(), Uint8List.fromList('pong'.codeUnits));

    await host.close();
    await peer.close();
  });
}
