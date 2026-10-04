import 'dart:io';

import 'package:path/path.dart' as p;

import 'exports_directory.dart';

/// One file in the Exports library.
class ExportEntry {
  const ExportEntry({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
    required this.modifiedAt,
    required this.format,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final ExportFormat format;

  bool get isImage => format == ExportFormat.png;
  bool get isArchive =>
      format == ExportFormat.markdownZip ||
      format == ExportFormat.htmlZip ||
      format == ExportFormat.vaultZip;
}

enum ExportFormat {
  markdownZip('Markdown zip', 'zip'),
  htmlZip('HTML zip', 'zip'),
  vaultZip('.nook vault', 'nook'),
  html('HTML', 'html'),
  png('PNG image', 'png'),
  other('File', '');

  const ExportFormat(this.label, this.ext);

  final String label;
  final String ext;
}

ExportFormat formatForFileName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.nook') ||
      lower.contains('nook-export') && lower.endsWith('.zip')) {
    if (lower.contains('markdown')) return ExportFormat.markdownZip;
    if (lower.contains('html')) return ExportFormat.htmlZip;
    if (lower.endsWith('.nook')) return ExportFormat.vaultZip;
    if (lower.endsWith('.zip')) return ExportFormat.vaultZip;
  }
  if (lower.endsWith('.md')) return ExportFormat.markdownZip;
  if (lower.endsWith('.html')) return ExportFormat.html;
  if (lower.endsWith('.png')) return ExportFormat.png;
  if (lower.endsWith('.zip')) {
    if (lower.contains('markdown')) return ExportFormat.markdownZip;
    if (lower.contains('html')) return ExportFormat.htmlZip;
    return ExportFormat.vaultZip;
  }
  return ExportFormat.other;
}

/// Lists and mutates files in the exports folder.
class ExportsRepository {
  ExportsRepository(this._dir);

  final ExportsDirectory _dir;

  /// All export files, newest modified first.
  Future<List<ExportEntry>> list() async {
    final root = _dir.root;
    if (!root.existsSync()) return [];
    final files = root
        .listSync()
        .whereType<File>()
        .where((f) => !p.basename(f.path).startsWith('.'))
        .toList();

    final entries = <ExportEntry>[];
    for (final file in files) {
      final stat = file.statSync();
      final name = p.basename(file.path);
      entries.add(
        ExportEntry(
          name: name,
          path: file.path,
          sizeBytes: stat.size,
          createdAt: stat.changed,
          modifiedAt: stat.modified,
          format: formatForFileName(name),
        ),
      );
    }
    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<void> deleteAll() async {
    final entries = await list();
    for (final e in entries) {
      await delete(e.path);
    }
  }

  Future<int> count() async => (await list()).length;

  /// Human-readable size, e.g. `1.2 MB`.
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
