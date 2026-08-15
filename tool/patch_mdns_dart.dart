import 'dart:io';

/// Idempotently patches `mdns_dart` in the pub cache.
///
/// `MDNSClient.query` is a one-shot lookup that never closes its underlying
/// `_Client` (2-4 UDP sockets) after the query stream ends — the sockets stay
/// open forever. Nook's discovery re-queries every few seconds, so this leaks
/// sockets until the process exhausts file descriptors and discovery silently
/// dies.
///
/// The patch wraps the returned stream so the client's sockets are closed once
/// the stream finishes (or is cancelled).
///
/// This script must run after `flutter pub get` in CI. Remove it once
/// `mdns_dart` closes its sockets upstream.
Future<void> main() async {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final path = '$pubCache/hosted/pub.dev/mdns_dart-2.2.1/lib/src/client.dart';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('mdns_dart: not found at $path');
    exitCode = 1;
    return;
  }

  var source = file.readAsStringSync();
  if (source.contains('nook: close client sockets on query completion')) {
    stdout.writeln('mdns_dart: client.dart already patched.');
    return;
  }

  const anchor = '''    try {
      await client._initialize(params.networkInterface);
      return client._performQuery(params);
    } catch (e) {
      await client.close();
      rethrow;
    }
  }''';

  const patched = '''    try {
      await client._initialize(params.networkInterface);
      // nook: close client sockets on query completion (or cancellation).
      // MDNSClient.query is a one-shot lookup and the underlying _Client
      // (2-4 UDP sockets) is never closed after the query stream ends, so
      // callers that re-query periodically (Nook's discovery) leak sockets
      // until the process exhausts file descriptors.
      return _closeWhenDone(client, params);
    } catch (e) {
      await client.close();
      rethrow;
    }
  }

  /// Forwards [client]'s query stream, closing the client's sockets when the
  /// stream is done OR when the consumer cancels (async* finally covers both).
  static Stream<ServiceEntry> _closeWhenDone(
      _Client client, QueryParams params) async* {
    try {
      yield* client._performQuery(params);
    } finally {
      await client.close();
    }
  }''';

  final index = source.indexOf(anchor);
  if (index == -1) {
    stderr.writeln('mdns_dart: client.dart anchor not found; refusing to '
        'patch.');
    exitCode = 1;
    return;
  }

  source = source.replaceFirst(anchor, patched);
  file.writeAsStringSync(source);
  stdout.writeln('mdns_dart: patched client socket cleanup.');
}
