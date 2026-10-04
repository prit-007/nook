import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stable on-disk folder for user-visible exports (zips, HTML, PNG).
///
/// Temp-dir exports vanish on cache clear; this folder lives under the app
/// documents directory so the Exports screen can list, open, share, delete.
class ExportsDirectory {
  ExportsDirectory(this.root);

  final Directory root;

  static const String folderName = 'nook_exports';

  /// Resolves the platform documents `nook_exports` folder (created if needed).
  static Future<ExportsDirectory> resolve() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, folderName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return ExportsDirectory(dir);
  }

  String get path => root.path;

  File file(String name) => File(p.join(root.path, name));

  /// Writes [bytes] to `name` inside the exports folder.
  Future<String> writeBytes(String name, List<int> bytes) async {
    if (!root.existsSync()) root.createSync(recursive: true);
    final file = this.file(name);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Writes [content] to `name` inside the exports folder.
  Future<String> writeText(String name, String content) async {
    if (!root.existsSync()) root.createSync(recursive: true);
    final file = this.file(name);
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}
