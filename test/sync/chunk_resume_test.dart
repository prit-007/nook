import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/pipeline/sync_bundle_packer.dart';

void main() {
  group('Chunked attachment resume', () {
    test('resuming missing chunk indices reconstructs exact payload', () {
      final payload = Uint8List.fromList(
        List<int>.generate(150 * 1024, (i) => (i * 31) & 0xff),
      );

      final allChunks = SyncBundlePacker.chunkPayload(
        payload,
        chunkSize: 32 * 1024,
      );
      expect(allChunks.length, 5);

      // Simulate transfer cutting off after chunks 0 and 2 arrived.
      final receivedIndices = {0, 2};
      final received = <PayloadChunk>[
        for (final idx in receivedIndices) allChunks[idx],
      ];

      // Incomplete stream must fail loudly rather than silently truncating.
      expect(
        () => SyncBundlePacker.reassembleChunks(received),
        throwsFormatException,
      );

      // Resume: request only missing indices [1, 3, 4].
      final missingIndices = [
        for (var i = 0; i < allChunks.length; i++)
          if (!receivedIndices.contains(i)) i,
      ];
      expect(missingIndices, equals([1, 3, 4]));

      for (final idx in missingIndices) {
        received.add(allChunks[idx]);
      }

      final reassembled = SyncBundlePacker.reassembleChunks(received);
      expect(reassembled, equals(payload));
    });

    test('tampered chunk fails SHA-256 verification on resume', () {
      final payload =
          Uint8List.fromList(List<int>.generate(4096, (i) => i % 97));
      final chunks = SyncBundlePacker.chunkPayload(payload, chunkSize: 1024);
      final corrupted = PayloadChunk(
        index: chunks[1].index,
        totalChunks: chunks[1].totalChunks,
        data: Uint8List.fromList(List<int>.filled(1024, 0xaa)),
        sha256Hex: chunks[1].sha256Hex,
      );

      expect(
        () => SyncBundlePacker.reassembleChunks([
          chunks[0],
          corrupted,
          chunks[2],
          chunks[3],
        ]),
        throwsFormatException,
      );
    });
  });
}
