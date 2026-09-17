import 'dart:io';

/// Idempotently patches the `sqlite3` package's build hook on Android so the
/// SQLCipher build links `liblog` — required by `__android_log_vprint` calls in
/// the native binary.
///
/// Without this, the pre-built SQLCipher `.so` fails to load at runtime with:
///
///   dlopen failed: cannot locate symbol "__android_log_vprint" referenced
///   by ".../libsqlite3.so"
///
/// The fix adds `'log'` to the Android libraries list in the hook's
/// `CompileSqlite` case so that the linker resolves the symbol from
/// `liblog.so`.
///
/// This script must run after `flutter pub get` in CI. Remove it once the
/// upstream `sqlite3` package links `liblog` on Android by default.
Future<void> main() async {
  // Locate the sqlite3 package in the pub cache.
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final hookDir = Directory('$pubCache/hosted/pub.dev');
  if (!hookDir.existsSync()) {
    stderr.writeln('Pub cache not found at ${hookDir.path}');
    exit(1);
  }

  // Find the sqlite3 package directory (may have different version suffixes).
  final sqlite3Dirs = hookDir
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.split(Platform.pathSeparator).last.startsWith('sqlite3-'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path)); // newest first

  if (sqlite3Dirs.isEmpty) {
    stderr.writeln('No sqlite3 package found in pub cache');
    exit(1);
  }

  final hookFile = File('${sqlite3Dirs.first.path}/hook/build.dart');
  if (!hookFile.existsSync()) {
    stderr.writeln('Build hook not found at ${hookFile.path}');
    exit(1);
  }

  var content = hookFile.readAsStringSync();

  // The patch: add 'log' after 'm' in the Android libraries list.
  const marker = "// We need to link the math library on Android.\n              'm',";
  const replacement =
      "// We need to link the math library on Android.\n              'm',\n"
      "              // SQLCipher uses __android_log_vprint — link liblog.\n"
      "              'log',";

  if (content.contains("'log',")) {
    stdout.writeln('sqlite3 build hook already patched — skipping.');
    return;
  }

  if (!content.contains(marker)) {
    stderr.writeln('Could not find the Android libraries block in the hook. '
        'The hook may have changed — patch needs updating.');
    exit(1);
  }

  content = content.replaceFirst(marker, replacement);
  hookFile.writeAsStringSync(content);
  stdout.writeln('Patched ${hookFile.path} — added log to Android libraries.');
}
