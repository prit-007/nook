import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Distribution & beta readiness audit (Phases 7 & 8)', () {
    test('F-Droid reproducible build scripts exist and are non-empty', () {
      for (final path in [
        'tool/ci/android_build.sh',
        'tool/ci/fdroid_flutter_setup.sh',
        '.github/workflows/ci.yml',
      ]) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: 'Missing $path');
        expect(f.lengthSync(), greaterThan(0));
      }
    });

    test('Linux packaging, Web target decision, and beta readiness docs exist',
        () {
      for (final path in [
        'linux/packaging/com.devparadise.nook.yml',
        'docs/LINUX-DISTRIBUTION.md',
        'docs/WEB-TARGET.md',
        'lib/features/web/web_companion_app.dart',
        'SECURITY.md',
        'docs/SECURITY.md',
        'docs/PRIVACY.md',
        'CONTRIBUTING.md',
        'CHANGELOG.md',
        '.github/ISSUE_TEMPLATE/bug.md',
        '.github/ISSUE_TEMPLATE/feature.md',
      ]) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: 'Missing $path');
        expect(f.lengthSync(), greaterThan(0));
      }
    });
  });
}
