import 'dart:io';

/// Idempotently patches `local_auth_windows` 2.0.1's Windows CMake build to
/// add `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`.
///
/// Newer MSVC toolchains error on `<experimental/coroutine>` unless this macro
/// is defined. The plugin still requires `/await` for `co_await`/`winrt::fire_and_forget`,
/// so the workaround is to silence the deprecation static-assert.
///
/// Remove this script once `local_auth_windows` ships a version that no longer
/// uses the deprecated coroutine headers.
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
      .where((d) => d.path.endsWith('local_auth_windows-2.0.1'))
      .toList();

  if (candidates.isEmpty) {
    stderr.writeln('local_auth_windows-2.0.1 not found in pub cache');
    exitCode = 1;
    return;
  }

  final pluginDir = candidates.single;
  final cmakeFile = File('${pluginDir.path}/windows/CMakeLists.txt');
  if (!cmakeFile.existsSync()) {
    stderr.writeln('CMakeLists.txt not found at ${cmakeFile.path}');
    exitCode = 1;
    return;
  }

  var source = cmakeFile.readAsStringSync();
  if (source.contains('_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS')) {
    stdout.writeln('local_auth_windows: already patched, skipping.');
    return;
  }

  source = source.replaceAll(
    r'target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)',
    r'target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)',
  );

  if (!source.contains(
      r'target_compile_definitions(${TEST_RUNNER} PRIVATE _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)')) {
    source = source.replaceAll(
      r'target_compile_options(${TEST_RUNNER} PRIVATE /await)',
      'target_compile_options(\${TEST_RUNNER} PRIVATE /await)\n'
          'target_compile_definitions(\${TEST_RUNNER} PRIVATE _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)',
    );
  }

  cmakeFile.writeAsStringSync(source);
  stdout.writeln('local_auth_windows: patched CMakeLists.txt.');
}
