import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cache/thumbnail_cache.dart';

void main() {
  late Directory tempDir;
  late File sampleImageFile;
  final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('thumb_cache_test_');
    sampleImageFile = File('${tempDir.path}/test_thumb.png');
    await sampleImageFile.writeAsBytes(sampleBytes);
    ThumbnailCache.instance.clear();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loads bytes from disk into memory cache on first access', () async {
    expect(ThumbnailCache.instance.isCached(sampleImageFile.path), isFalse);

    final bytes = await ThumbnailCache.instance.getBytes(sampleImageFile.path);
    expect(bytes, isNotNull);
    expect(bytes, equals(sampleBytes));
    expect(ThumbnailCache.instance.isCached(sampleImageFile.path), isTrue);
  });

  test('returns cached bytes directly from memory on second access', () async {
    await ThumbnailCache.instance.getBytes(sampleImageFile.path);

    // Delete file from disk to prove second read is purely in-memory
    await sampleImageFile.delete();
    expect(sampleImageFile.existsSync(), isFalse);

    final cachedBytes =
        await ThumbnailCache.instance.getBytes(sampleImageFile.path);
    expect(cachedBytes, equals(sampleBytes));
  });

  test('clear() purges all in-memory entries', () async {
    await ThumbnailCache.instance.getBytes(sampleImageFile.path);
    expect(ThumbnailCache.instance.count, 1);

    ThumbnailCache.instance.clear();
    expect(ThumbnailCache.instance.count, 0);
    expect(ThumbnailCache.instance.isCached(sampleImageFile.path), isFalse);
  });
}
