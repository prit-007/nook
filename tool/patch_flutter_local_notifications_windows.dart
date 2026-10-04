import 'dart:io';

/// Idempotently patches `flutter_local_notifications_windows` CMake so MSVC
/// accepts `<experimental/coroutine>` via winrt headers.
///
/// Newer MSVC toolchains error C2338 on experimental coroutine headers unless
/// `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` is defined.
///
/// Remove once the plugin ships a build that no longer pulls those headers.
Future<void> main() async {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';

  final dir = Directory('$pubCache/hosted/pub.dev');
  if (!dir.existsSync()) {
    stderr.writeln('Pub cache not found at $pubCache');
    exitCode = 1;
    return;
  }

  final candidates = dir
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('flutter_local_notifications_windows-'))
      .toList();

  if (candidates.isEmpty) {
    stdout.writeln(
      'flutter_local_notifications_windows not found in pub cache — skipping.',
    );
    return;
  }

  const marker = '_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS';
  const from =
      'target_compile_definitions(flutter_local_notifications_windows PUBLIC DART_SHARED_LIB)';
  const to =
      'target_compile_definitions(flutter_local_notifications_windows PUBLIC DART_SHARED_LIB)\n'
      '  $marker';

  for (final pluginDir in candidates) {
    for (final rel in ['src/CMakeLists.txt', 'windows/CMakeLists.txt']) {
      final cmakeFile = File('${pluginDir.path}/$rel');
      if (!cmakeFile.existsSync()) continue;
      var source = cmakeFile.readAsStringSync();
      if (source.contains(marker)) {
        stdout.writeln('${pluginDir.path}/$rel: already patched, skipping.');
        continue;
      }
      if (source.contains(from)) {
        source = source.replaceAll(from, to);
      } else if (!source.contains(marker)) {
        source = '$source\n'
            'target_compile_definitions(flutter_local_notifications_windows PRIVATE\n'
            '  $marker)\n';
      }
      cmakeFile.writeAsStringSync(source);
      stdout.writeln('${pluginDir.path}/$rel: patched.');
    }
  }
}
