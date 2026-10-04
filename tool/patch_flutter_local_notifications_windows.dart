import 'dart:io';

/// Idempotently patches `flutter_local_notifications_windows` CMake so MSVC
/// accepts `<experimental/coroutine>` via winrt headers.
///
/// Newer MSVC toolchains error C2338 on experimental coroutine headers unless
/// `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` is defined.
///
/// The define MUST stay inside `target_compile_definitions(...)` — appending
/// it on its own line after a closed call is a CMake parse error.
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

  // Broken form produced by earlier patches: closing paren before the define.
  const broken =
      'target_compile_definitions(flutter_local_notifications_windows PUBLIC DART_SHARED_LIB)\n'
      '  $marker';

  // Valid form: all args inside one properly closed command.
  const fixed =
      'target_compile_definitions(flutter_local_notifications_windows PUBLIC\n'
      '  DART_SHARED_LIB\n'
      '  $marker\n'
      ')';

  const original =
      'target_compile_definitions(flutter_local_notifications_windows PUBLIC DART_SHARED_LIB)';

  for (final pluginDir in candidates) {
    // Only src/CMakeLists.txt defines DART_SHARED_LIB; patch that file only.
    final cmakeFile = File('${pluginDir.path}/src/CMakeLists.txt');
    if (!cmakeFile.existsSync()) continue;

    var source = cmakeFile.readAsStringSync();
    var changed = false;

    // Repair previously broken patch output.
    if (source.contains(broken)) {
      source = source.replaceAll(broken, fixed);
      changed = true;
    } else if (source.contains(original) && !source.contains(marker)) {
      source = source.replaceAll(original, fixed);
      changed = true;
    } else if (!source.contains(marker)) {
      // Fallback: append a closed definition for this target.
      source = '$source\n'
          'target_compile_definitions(flutter_local_notifications_windows PRIVATE\n'
          '  $marker\n'
          ')\n';
      changed = true;
    }

    // Drop any stray un-closed define lines left in windows/CMakeLists.txt
    // from older patches (harmless if absent).
    final windowsCmake = File('${pluginDir.path}/windows/CMakeLists.txt');
    if (windowsCmake.existsSync()) {
      var win = windowsCmake.readAsStringSync();
      final stray =
          '\n\ntarget_compile_definitions(flutter_local_notifications_windows PRIVATE\n'
          '  $marker)';
      if (win.contains(stray)) {
        win = win.replaceAll(stray, '');
        windowsCmake.writeAsStringSync(win);
        stdout.writeln(
          '${windowsCmake.path}: removed redundant PRIVATE define.',
        );
      }
    }

    if (changed) {
      cmakeFile.writeAsStringSync(source);
      stdout.writeln('${cmakeFile.path}: patched.');
    } else {
      stdout.writeln('${cmakeFile.path}: already valid, skipping.');
    }
  }
}
