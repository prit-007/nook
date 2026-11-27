import 'dart:convert';
import 'dart:io';

/// Audits Nook's pubspec and resolved packages for proprietary/tracking SDKs
/// and missing open-source license files.
///
/// Usage: `dart run tool/licence_audit.dart`
void main() {
  final forbiddenPackages = <String>[
    'firebase_',
    'google_mlkit',
    'google_ml_kit',
    'flutter_mobile_vision',
    'mixpanel',
    'amplitude',
    'sentry',
    'appsflyer',
    'adjust_sdk',
    'facebook_app_events',
    'onesignal',
    'huawei_',
    'google_mobile_ads',
  ];

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('ERROR: pubspec.yaml not found');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  for (final pattern in forbiddenPackages) {
    if (pubspecContent.contains(pattern)) {
      stderr.writeln(
        'ERROR: Forbidden proprietary/tracking package matching "$pattern" found in pubspec.yaml',
      );
      exit(1);
    }
  }

  final lockFile = File('pubspec.lock');
  if (lockFile.existsSync()) {
    final lockContent = lockFile.readAsStringSync();
    for (final pattern in forbiddenPackages) {
      if (lockContent.contains(pattern)) {
        stderr.writeln(
          'ERROR: Forbidden proprietary/tracking package matching "$pattern" found in pubspec.lock',
        );
        exit(1);
      }
    }
  }

  final packageConfig = File('.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) {
    stderr.writeln(
      'ERROR: .dart_tool/package_config.json not found. Run `flutter pub get` first.',
    );
    exit(1);
  }

  final decoded =
      jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
  final packages =
      (decoded['packages'] as List<dynamic>).cast<Map<String, dynamic>>();

  var checkedCount = 0;
  final missingLicense = <String>[];

  for (final pkg in packages) {
    final name = pkg['name'] as String;
    final rootUriStr = pkg['rootUri'] as String;
    if (name == 'nook') continue;

    for (final pattern in forbiddenPackages) {
      if (name.contains(pattern)) {
        stderr.writeln(
          'ERROR: Forbidden proprietary/tracking transitive package "$name" resolved',
        );
        exit(1);
      }
    }

    final rootUri = Uri.parse(rootUriStr);
    if (!rootUri.isAbsolute || rootUri.scheme != 'file') {
      continue;
    }

    final rootDir = Directory.fromUri(rootUri);
    if (!rootDir.existsSync()) continue;

    checkedCount++;
    final hasLicense = [
      'LICENSE',
      'LICENSE.md',
      'LICENSE.txt',
      'COPYING',
      'COPYING.md',
    ].any((filename) => File('${rootDir.path}/$filename').existsSync());

    if (!hasLicense) {
      missingLicense.add(name);
    }
  }

  if (missingLicense.isNotEmpty) {
    stdout.writeln(
      'Warning: ${missingLicense.length} packages had no top-level LICENSE file: ${missingLicense.join(', ')}',
    );
  }

  stdout.writeln(
    'Licence audit passed: ${packages.length} packages checked ($checkedCount resolved in cache), 0 forbidden tracking/proprietary dependencies.',
  );
}
