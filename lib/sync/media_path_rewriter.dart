import 'dart:convert';

/// A single media file (image or doodle layer) that was restored on this
/// device, together with the mapping from its source-device locations to the
/// paths it now lives at.
class RestoredMedia {
  const RestoredMedia({
    required this.attachmentId,
    this.newAttachmentId,
    this.originalFilePath,
    this.originalThumbnailPath,
    this.originalFileName,
    required this.newFilePath,
    this.newThumbnailPath,
  });

  /// Id the media carried on the source device (as referenced by the delta).
  final String attachmentId;

  /// Id the restored row lives under on this device. Differs from
  /// [attachmentId] only when a collision forced a fresh id; the delta's
  /// `attachment_id` must be re-pointed at it.
  final String? newAttachmentId;

  /// Absolute path the image lived at on the source device (the delta's image
  /// `url` value), if known.
  final String? originalFilePath;

  /// Absolute path the thumbnail lived at on the source device (the delta's
  /// doodle `thumbnail_path` value), if known.
  final String? originalThumbnailPath;

  /// File name the media was exported under, used as a basename fallback for
  /// images whose original path is unknown (legacy payloads).
  final String? originalFileName;

  /// Absolute path the media now lives at on this device.
  final String newFilePath;

  /// Absolute path the thumbnail now lives at on this device.
  final String? newThumbnailPath;

  String get resolvedId => newAttachmentId ?? attachmentId;
}

/// Rewrites the absolute media paths baked into a note's `deltaContent` so the
/// restored files on this device are referenced instead of the source device's
/// — e.g. a Windows `C:\Users\...` image url when importing/syncing onto
/// Android, where that path does not exist.
///
/// The delta is parsed as JSON and walked structurally, so path separators and
/// JSON escaping (backslashes, quotes) are handled automatically:
/// - `image` nodes: `url` is matched by exact path, then by basename against
///   the exported file name.
/// - `doodle` nodes: `thumbnail_path` is matched by exact path, then by
///   `attachment_id` against the restored thumbnail. A remapped id (collision)
///   also re-points `attachment_id` at the restored row.
///
/// Returns the input unchanged when nothing needed rewriting. If the delta is
/// not parseable JSON, falls back to literal string replacement of the known
/// old paths plus legacy structural regexes.
String rewriteMediaPaths(String deltaJson, List<RestoredMedia> restored) {
  if (deltaJson.isEmpty || restored.isEmpty) return deltaJson;

  final exactPaths = <String, String>{};
  final exactThumbs = <String, String>{};
  final byId = <String, RestoredMedia>{};
  final byFileName = <String, RestoredMedia>{};
  for (final r in restored) {
    if (r.originalFilePath != null && r.originalFilePath!.isNotEmpty) {
      exactPaths[r.originalFilePath!] = r.newFilePath;
    }
    if (r.originalThumbnailPath != null &&
        r.originalThumbnailPath!.isNotEmpty) {
      exactThumbs[r.originalThumbnailPath!] =
          r.newThumbnailPath ?? r.newFilePath;
    }
    if (r.originalFileName != null && r.originalFileName!.isNotEmpty) {
      byFileName[r.originalFileName!] = r;
    }
    byId[r.attachmentId] = r;
  }

  Object? doc;
  try {
    doc = jsonDecode(deltaJson);
  } catch (_) {
    return _legacyStringRewrite(deltaJson, exactPaths, exactThumbs, byId);
  }

  var changed = false;
  _walkNodes(doc, (node) {
    final data = node['data'];
    if (data is! Map) return;

    switch (node['type']) {
      case 'image':
        final url = data['url'] as String?;
        if (url == null || url.isEmpty) break;
        var newUrl = exactPaths[url];
        if (newUrl == null) {
          final match = byFileName[_basename(url)];
          if (match != null) newUrl = match.newFilePath;
        }
        if (newUrl != null && newUrl != url) {
          data['url'] = newUrl;
          changed = true;
        }
        break;

      case 'doodle':
        final attId = data['attachment_id'] as String?;
        final restored = attId != null ? byId[attId] : null;
        if (restored != null && restored.resolvedId != attId) {
          data['attachment_id'] = restored.resolvedId;
          changed = true;
        }

        var thumb = data['thumbnail_path'] as String?;
        if (thumb != null && thumb.isNotEmpty) {
          var newThumb = exactThumbs[thumb];
          if (newThumb == null && restored != null) {
            newThumb = restored.newThumbnailPath;
          }
          if (newThumb != null && newThumb != thumb) {
            data['thumbnail_path'] = newThumb;
            changed = true;
          }
        } else if (restored != null && restored.newThumbnailPath != null) {
          data['thumbnail_path'] = restored.newThumbnailPath;
          changed = true;
        }
    }
  });

  if (!changed) return deltaJson;
  return jsonEncode(doc);
}

/// Walks every node in the AppFlowy document JSON — either a list of nodes or
/// a document map carrying a `children` list. A legacy `document` wrapper map
/// is unwrapped too.
void _walkNodes(Object? doc, void Function(Map<String, dynamic> node) visit) {
  if (doc is List) {
    for (final item in doc) {
      _visitNode(item, visit);
    }
  } else if (doc is Map) {
    final document = doc['document'];
    final inner = document is Map ? document : doc;
    final children = inner['children'];
    if (children is List) {
      for (final item in children) {
        _visitNode(item, visit);
      }
    }
  }
}

void _visitNode(Object? node, void Function(Map<String, dynamic>) visit) {
  if (node is Map<String, dynamic>) {
    visit(node);
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        _visitNode(child, visit);
      }
    }
  }
}

/// Last path segment of [path], tolerant of both `/` and `\` separators so a
/// Windows path resolves correctly even on a POSIX host.
String _basename(String path) {
  final clean = path.replaceAll('\\', '/');
  final slash = clean.lastIndexOf('/');
  return slash >= 0 ? clean.substring(slash + 1) : clean;
}

/// Fallback for deltas that failed to parse as JSON: literal path replacement
/// plus the legacy structural regexes.
String _legacyStringRewrite(
  String delta,
  Map<String, String> exactPaths,
  Map<String, String> exactThumbs,
  Map<String, RestoredMedia> byId,
) {
  var out = delta;
  exactPaths
      .forEach((oldPath, newPath) => out = out.replaceAll(oldPath, newPath));
  exactThumbs
      .forEach((oldPath, newPath) => out = out.replaceAll(oldPath, newPath));

  for (final r in byId.values) {
    final thumb = r.newThumbnailPath;
    if (thumb != null && r.attachmentId.isNotEmpty) {
      final nodeRe = RegExp(
        '("attachment_id"\\s*:\\s*"${RegExp.escape(r.attachmentId)}"'
        '[^}]*?"thumbnail_path"\\s*:\\s*")([^"]*)(")',
      );
      out = out.replaceAllMapped(nodeRe, (m) => '${m[1]}$thumb${m[3]}');
    }
    final fileName = r.originalFileName;
    if (fileName != null && fileName.isNotEmpty) {
      final urlRe = RegExp(
        '("url"\\s*:\\s*")[^"]*${RegExp.escape(fileName)}(")',
      );
      out =
          out.replaceAllMapped(urlRe, (m) => '${m[1]}${r.newFilePath}${m[2]}');
    }
  }
  return out;
}
