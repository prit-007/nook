import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of storing media in content-addressed storage.
class CasResult {
  const CasResult({
    required this.hash,
    required this.filePath,
    required this.wasReused,
  });

  final String hash;
  final String filePath;
  final bool wasReused;

  String get path => filePath;
  File get file => File(filePath);
}

/// Content-Addressed Storage (CAS) for media attachments (photos, images, doodles).
///
/// Deduplicates binary storage on disk by hashing bytes with SHA-256. If a file
/// with the identical hash already exists on disk, it is reused without writing,
/// eliminating duplicate disk usage and reducing sync payload overhead.
class MediaCasStorage {
  MediaCasStorage({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  /// Returns the standard SHA-256 hex string for [bytes].
  static String computeHash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  Future<Directory> _getCasDirectory() async {
    final base = _baseDirectory ?? await getApplicationDocumentsDirectory();
    final casDir = Directory(p.join(base.path, 'media', 'cas'));
    if (!await casDir.exists()) {
      await casDir.create(recursive: true);
    }
    return casDir;
  }

  /// Stores [bytes] in CAS storage. Reuses existing file if identical hash exists.
  Future<CasResult> storeMedia(
    Uint8List bytes, {
    String extension = 'bin',
  }) async {
    final hash = computeHash(bytes);
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final dir = await _getCasDirectory();
    final targetPath = p.join(dir.path, '$hash.$ext');
    final targetFile = File(targetPath);

    if (await targetFile.exists()) {
      final length = await targetFile.length();
      if (length == bytes.length) {
        return CasResult(
          hash: hash,
          filePath: targetPath,
          wasReused: true,
        );
      }
    }

    await targetFile.writeAsBytes(bytes, flush: true);
    return CasResult(
      hash: hash,
      filePath: targetPath,
      wasReused: false,
    );
  }

  /// Whether a media file with [hash] and [extension] exists in CAS.
  Future<bool> hasMedia(String hash, {String extension = 'bin'}) async {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final dir = await _getCasDirectory();
    final targetFile = File(p.join(dir.path, '$hash.$ext'));
    return targetFile.exists();
  }

  /// Returns the File pointer for [hash] and [extension].
  Future<File> getMediaFile(String hash, {String extension = 'bin'}) async {
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    final dir = await _getCasDirectory();
    return File(p.join(dir.path, '$hash.$ext'));
  }

  /// Prunes any CAS files not in [activePaths], returning the count of deleted files.
  Future<int> pruneUnreferenced(Set<String> activePaths) async {
    final dir = await _getCasDirectory();
    var deletedCount = 0;
    if (!await dir.exists()) return 0;

    final entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is File && !activePaths.contains(entity.path)) {
        try {
          await entity.delete();
          deletedCount++;
        } catch (_) {}
      }
    }
    return deletedCount;
  }
}
