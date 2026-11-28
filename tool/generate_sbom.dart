import 'dart:convert';
import 'dart:io';

/// Generates a lightweight CycloneDX JSON SBOM from `pubspec.lock`.
Map<String, dynamic> buildSbomFromLockfile(String lockfileContents) {
  final components = <Map<String, dynamic>>[];
  final lines = lockfileContents.split('\n');

  String? currentName;
  String? currentVersion;
  String? currentSource;

  void flush() {
    if (currentName != null && currentVersion != null) {
      components.add({
        'type': 'library',
        'name': currentName,
        'version': currentVersion,
        if (currentSource != null) 'scope': currentSource,
      });
    }
    currentName = null;
    currentVersion = null;
    currentSource = null;
  }

  var inPackages = false;
  for (final raw in lines) {
    if (raw.trim() == 'packages:') {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (raw.isNotEmpty && !raw.startsWith(' ')) {
      flush();
      break;
    }
    if (raw.startsWith('  ') && !raw.startsWith('    ') && raw.endsWith(':')) {
      flush();
      currentName = raw.trim().substring(0, raw.trim().length - 1);
      continue;
    }
    final trimmed = raw.trim();
    if (trimmed.startsWith('version:')) {
      currentVersion =
          trimmed.substring('version:'.length).trim().replaceAll('"', '');
    } else if (trimmed.startsWith('source:')) {
      currentSource = trimmed.substring('source:'.length).trim();
    }
  }
  flush();

  return {
    'bomFormat': 'CycloneDX',
    'specVersion': '1.5',
    'version': 1,
    'components': components,
  };
}

Future<void> main(List<String> args) async {
  final lockFile = File('pubspec.lock');
  if (!await lockFile.exists()) {
    stderr.writeln('pubspec.lock not found');
    exitCode = 1;
    return;
  }
  final sbom = buildSbomFromLockfile(await lockFile.readAsString());
  final outFile = File('build/sbom.json');
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(sbom),
  );
  stdout.writeln(
    'Generated ${outFile.path} with ${(sbom['components'] as List).length} components.',
  );
}
