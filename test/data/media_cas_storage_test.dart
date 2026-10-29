import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/media_cas_storage.dart';

void main() {
  late Directory tempDir;
  late MediaCasStorage cas;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nook-cas-test');
    cas = MediaCasStorage(baseDirectory: tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('MediaCasStorage (TDD)', () {
    test('computeHash returns standard sha256 lowercase hex', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final expectedHash = sha256.convert(data).toString();

      final hash = MediaCasStorage.computeHash(data);
      expect(hash, expectedHash);
    });

    test('storeMedia saves file and returns path and hash', () async {
      final sampleBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      final expectedHash = sha256.convert(sampleBytes).toString();

      final result = await cas.storeMedia(sampleBytes, extension: 'png');

      expect(result.hash, expectedHash);
      expect(result.wasReused, isFalse);
      expect(await File(result.filePath).exists(), isTrue);
      expect(await File(result.filePath).readAsBytes(), sampleBytes);
      expect(result.filePath.endsWith('$expectedHash.png'), isTrue);
    });

    test(
        'storeMedia with identical bytes reuses existing file and avoids rewriting',
        () async {
      final sampleBytes = Uint8List.fromList([10, 20, 30, 40, 50]);

      final firstResult = await cas.storeMedia(sampleBytes, extension: 'png');
      expect(firstResult.wasReused, isFalse);

      final secondResult = await cas.storeMedia(sampleBytes, extension: 'png');
      expect(secondResult.wasReused, isTrue);
      expect(secondResult.hash, firstResult.hash);
      expect(secondResult.filePath, firstResult.filePath);
    });

    test('hasMedia returns true if file exists and false otherwise', () async {
      final sampleBytes = Uint8List.fromList([99, 88, 77]);
      final hash = MediaCasStorage.computeHash(sampleBytes);

      expect(await cas.hasMedia(hash, extension: 'jpg'), isFalse);

      await cas.storeMedia(sampleBytes, extension: 'jpg');
      expect(await cas.hasMedia(hash, extension: 'jpg'), isTrue);
    });

    test('pruneUnreferenced deletes CAS files not in active paths set',
        () async {
      final bytesA = Uint8List.fromList([1, 1, 1]);
      final bytesB = Uint8List.fromList([2, 2, 2]);

      final fileA = await cas.storeMedia(bytesA, extension: 'png');
      final fileB = await cas.storeMedia(bytesB, extension: 'png');

      expect(await File(fileA.filePath).exists(), isTrue);
      expect(await File(fileB.filePath).exists(), isTrue);

      // Only fileA is in active use
      final removed = await cas.pruneUnreferenced({fileA.filePath});

      expect(removed, 1);
      expect(await File(fileA.filePath).exists(), isTrue);
      expect(await File(fileB.filePath).exists(), isFalse);
    });
  });
}
