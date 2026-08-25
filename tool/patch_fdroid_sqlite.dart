import 'dart:io';

/// Patches pubspec.yaml to compile SQLite from source instead of downloading
/// a prebuilt binary. Used by the F-Droid build where binary downloads are
/// not allowed.
///
/// Reads the sqlite3 hooks config and changes:
///   source: sqlcipher → source: source
/// Adding the path to the SQLCipher amalgamation and the SQLITE_HAS_CODEC define.
void main(List<String> args) {
  final sqlcipherPath = args.isNotEmpty
      ? args[0]
      : Platform.environment['SQLCIPHER_PATH'] ?? '';

  if (sqlcipherPath.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/patch_fdroid_sqlite.dart <sqlcipher-path>',
    );
    exit(1);
  }

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found');
    exit(1);
  }

  var content = pubspec.readAsStringSync();

  // Replace source: sqlcipher with source: source + path + defines
  final old = '      source: sqlcipher';
  final newPath = '$sqlcipherPath/sqlite3.c';
  final newContent = '''      source: source
      path: $newPath
      defines:
        - SQLITE_HAS_CODEC''';

  if (!content.contains(old)) {
    stderr.writeln('Could not find "$old" in pubspec.yaml');
    exit(1);
  }

  content = content.replaceFirst(old, newContent);
  pubspec.writeAsStringSync(content);

  stdout.writeln('Patched pubspec.yaml: sqlite3 source → source (from $newPath)');
}
