import 'dart:io';

/// Patches pubspec.yaml to compile SQLCipher from source instead of
/// downloading a prebuilt binary, and wires a real statically-linked OpenSSL
/// into the build. Used by the F-Droid build where binary downloads are not
/// allowed.
///
/// The sqlite3 native-assets hook's `source: source` path compiles the SQLCipher
/// amalgamation but links no crypto library, so `PRAGMA key` fails at runtime
/// with an unresolved `RAND_bytes`. This script:
///
///  1. Rewrites the `hooks.user_defines.sqlite3` block to compile from the
///     SQLCipher amalgamation with `SQLITE_HAS_CODEC`.
///  2. Deletes the old stub OpenSSL headers (they would shadow the real ones).
///  3. Patches the sqlite3 package's build hook (in the pub cache) so the
///     amalgamation compiles against the real OpenSSL headers for every target
///     config and statically links the per-ABI `libcrypto.a` on Android —
///     passing `PRAGMA key` real crypto instead of stubs.
///  4. Purges the compiled hook cache (`.dart_tool/hooks_runner`) so the
///     patched `build.dart` is recompiled instead of the stale `hook.dill`
///     produced by `flutter pub get`.
void main(List<String> args) {
  final sqlcipherPath =
      args.isNotEmpty ? args[0] : Platform.environment['SQLCIPHER_PATH'] ?? '';
  final opensslDir = args.length > 1
      ? args[1]
      : Platform.environment['NOOK_OPENSSL_DIR'] ?? '';

  if (sqlcipherPath.isEmpty || opensslDir.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/patch_fdroid_sqlite.dart <sqlcipher-path> '
      '<openssl-android-dir>',
    );
    stderr.writeln(
      '${'  '}The OpenSSL dir must contain android-arm64, android-arm and '
      'android-x86_64 subdirs, each with lib/libcrypto.a and include/openssl.',
    );
    exit(1);
  }

  _patchPubspec(sqlcipherPath);
  _removeStubHeaders(sqlcipherPath);
  _validateOpensslBuild(opensslDir);
  _patchSqlite3Hook(opensslDir);

  stdout.writeln(
    'Patched sqlite3 source → source from $sqlcipherPath/sqlite3.c with '
    'per-ABI static OpenSSL from $opensslDir.',
  );
}

/// Replaces the `hooks.user_defines.sqlite3` block in pubspec.yaml so the
/// sqlite3 hook compiles the amalgamation instead of downloading a prebuilt
/// binary. Idempotent: the subtree is rewritten on every run.
void _patchPubspec(String sqlcipherPath) {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found');
    exit(1);
  }

  final lines = pubspec.readAsStringSync().split('\n');
  final start = lines.indexWhere(
    (line) => line.startsWith('    sqlite3:'),
  );
  if (start == -1) {
    stderr.writeln('Could not find "sqlite3:" under hooks.user_defines in '
        'pubspec.yaml');
    exit(1);
  }

  var end = start + 1;
  while (end < lines.length) {
    final line = lines[end];
    if (line.isNotEmpty && !line.startsWith('      ')) {
      break; // A less-indented line ends the sqlite3 subtree.
    }
    end++;
  }

  final block = [
    '    sqlite3:',
    '      source: source',
    '      path: $sqlcipherPath/sqlite3.c',
    '      defines:',
    '        - SQLITE_HAS_CODEC',
    // The -Wno flags guard against warnings from SQLCipher's dead crypto
    // backend code that the amalgamation always includes.
    '      additional_flags:',
    '        - -Wno-implicit-function-declaration',
    '        - -Wno-int-conversion',
    '        - -Wno-incompatible-function-pointer-types',
  ];

  lines.replaceRange(start, end, block);
  pubspec.writeAsStringSync(lines.join('\n'));
}

/// Removes the stub OpenSSL headers previously generated next to the
/// amalgamation. They declare crypto functions without implementations and live
/// on the include path ahead of the real headers, so they must not exist when
/// linking a real OpenSSL.
void _removeStubHeaders(String sqlcipherPath) {
  final stubDir = Directory('$sqlcipherPath/openssl');
  if (stubDir.existsSync()) {
    stubDir.deleteSync(recursive: true);
    stdout.writeln('Removed stub OpenSSL headers at ${stubDir.path}');
  }
}

/// Verifies that each Android ABI tree produced by the CI OpenSSL build step
/// is present and complete.
void _validateOpensslBuild(String opensslDir) {
  const abis = ['android-arm64', 'android-arm', 'android-x86_64'];
  final missing = <String>[];
  for (final abi in abis) {
    if (!File('$opensslDir/$abi/lib/libcrypto.a').existsSync()) {
      missing.add('$abi/lib/libcrypto.a');
    }
    if (!File('$opensslDir/$abi/include/openssl/rand.h').existsSync()) {
      missing.add('$abi/include/openssl/rand.h');
    }
  }
  if (missing.isNotEmpty) {
    stderr.writeln('OpenSSL build is incomplete at $opensslDir, missing:');
    for (final path in missing) {
      stderr.writeln('  $path');
    }
    exit(1);
  }
  stdout
      .writeln('Validated OpenSSL build (libcrypto.a + headers) for all ABIs.');
}

/// Idempotently patches the sqlite3 package's build hook so the
/// compile-from-source path compiles against the real OpenSSL headers for
/// every target config and statically links a per-ABI `libcrypto.a` on
/// Android, resolving `RAND_bytes`/`EVP_*` at runtime instead of leaving them
/// undefined. The OpenSSL tree location is baked in, so the hook does not need
/// the `NOOK_OPENSSL_DIR` env var at build time.
///
/// The compiled hook cache is purged afterwards because `flutter pub get`
/// compiles the hook into `.dart_tool/hooks_runner/**/hook.dill`; editing
/// `build.dart` does not invalidate that dill, so a stale (unpatched) hook
/// would keep running.
void _patchSqlite3Hook(String opensslDir) {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final hookDir = Directory('$pubCache/hosted/pub.dev');
  if (!hookDir.existsSync()) {
    stderr.writeln('Pub cache not found at ${hookDir.path}');
    exit(1);
  }

  final sqlite3Dirs = hookDir
      .listSync()
      .whereType<Directory>()
      .where((d) =>
          d.path.split(Platform.pathSeparator).last.startsWith('sqlite3-'))
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

  if (content.contains('nookOpensslAbi')) {
    stdout.writeln('sqlite3 build hook already patched — skipping.');
    return;
  }

  const marker = '        final library = CBuilder.library(\n'
      '          name: \'sqlite3\',';
  const includesMarker =
      '          includes: [p.dirname(sourceFile), ...additionalIncludes],';
  const libDirsMarker =
      '          libraryDirectories: [...additionalLibraryDirectories],';
  const librariesMarker = '            ...additionalLibraries,';

  for (final needle in [
    marker,
    includesMarker,
    libDirsMarker,
    librariesMarker
  ]) {
    if (!content.contains(needle)) {
      stderr.writeln('Could not find hook marker:\n$needle');
      stderr
          .writeln('The sqlite3 hook may have changed — patch needs updating.');
      exit(1);
    }
  }

  final opensslBlock = '''
        // BEGIN NOOK OPENSSL PATCH: compile against real OpenSSL headers and
        // statically link libcrypto.a for the F-Droid compile-from-source
        // path (PRAGMA key needs real crypto).
        final nookOpensslDir = '$opensslDir';
        final nookOpensslAbi = switch (input.config.code.targetArchitecture) {
          Architecture.arm => 'android-arm',
          Architecture.arm64 => 'android-arm64',
          Architecture.x64 => 'android-x86_64',
          _ => null,
        };
        // Headers are arch-independent, so non-Android configs (e.g. the Linux
        // host build flutter runs first) compile against any ABI's header tree;
        // only Android actually links the static crypto library.
        final nookOpensslHeaderAbi = nookOpensslAbi ?? 'android-arm64';
        final nookOpensslLink = nookOpensslAbi != null &&
            input.config.code.targetOS == OS.android;
        final nookOpensslIncludes = <String>[
          if (nookOpensslDir.isNotEmpty)
            '\$nookOpensslDir/\$nookOpensslHeaderAbi/include',
        ];
        final nookOpensslLibDirs = <String>[
          if (nookOpensslLink) '\$nookOpensslDir/\$nookOpensslAbi/lib',
        ];
        final nookOpensslLibs = <String>[
          if (nookOpensslLink) 'crypto',
        ];
        // END NOOK OPENSSL PATCH
''';

  content = content.replaceFirst(marker, '$opensslBlock$marker');
  content = content.replaceFirst(
    includesMarker,
    '          includes: [p.dirname(sourceFile), '
    '...additionalIncludes, ...nookOpensslIncludes],',
  );
  content = content.replaceFirst(
    libDirsMarker,
    '          libraryDirectories: '
    '[...additionalLibraryDirectories, ...nookOpensslLibDirs],',
  );
  content = content.replaceFirst(
    librariesMarker,
    '            ...nookOpensslLibs,\n'
    '            ...additionalLibraries,',
  );

  hookFile.writeAsStringSync(content);
  stdout.writeln('Patched ${hookFile.path} to link per-ABI static OpenSSL.');

  _purgeStaleHookCache();
}

/// Deletes the compiled native-assets hook cache. `flutter pub get` compiles
/// each hook to `.dart_tool/hooks_runner/<package>/<hash>/hook.dill` from the
/// source as it is at pub-get time; editing `build.dart` afterwards does not
/// invalidate that dill, so without this the unpatched hook keeps running.
void _purgeStaleHookCache() {
  final hooksRunner = Directory('.dart_tool/hooks_runner');
  final nativeAssets = Directory('.dart_tool/native_assets');
  for (final dir in [hooksRunner, nativeAssets]) {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      stdout.writeln(
          'Deleted ${dir.path} to force recompilation of the patched hook.');
    }
  }
}
