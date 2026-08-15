import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/updates/update_models.dart';

void main() {
  group('AppVersion.parse', () {
    test('parses bare semver', () {
      final v = AppVersion.parse('0.8.0');
      expect(v.major, 0);
      expect(v.minor, 8);
      expect(v.patch, 0);
      expect(v.raw, '0.8.0');
    });

    test('parses v-prefixed release tags', () {
      final v = AppVersion.parse('v0.9.0');
      expect(v, const AppVersion(0, 9, 0, 'v0.9.0'));
      expect(v.toString(), 'v0.9.0');
    });

    test('ignores build metadata', () {
      final v = AppVersion.parse('1.2.3+42');
      expect(v.patch, 3);
    });

    test('ignores pre-release suffixes', () {
      expect(AppVersion.parse('1.2.3-beta.1').patch, 3);
    });

    test('missing components default to zero', () {
      expect(AppVersion.parse('1.2'), const AppVersion(1, 2, 0));
    });

    test('non-numeric parts default to zero', () {
      expect(AppVersion.parse('abc'), const AppVersion(0, 0, 0));
    });
  });

  group('AppVersion comparison', () {
    test('detects a newer minor', () {
      expect(
        AppVersion.parse('v0.9.0').isNewerThan(AppVersion.parse('0.8.0')),
        isTrue,
      );
    });

    test('patch bumps are newer', () {
      expect(
        AppVersion.parse('0.8.1').isNewerThan(AppVersion.parse('0.8.0')),
        isTrue,
      );
    });

    test('equal versions are not newer', () {
      expect(
        AppVersion.parse('v0.8.0').isNewerThan(AppVersion.parse('0.8.0')),
        isFalse,
      );
    });

    test('older versions are not newer', () {
      expect(
        AppVersion.parse('0.7.9').isNewerThan(AppVersion.parse('0.8.0')),
        isFalse,
      );
    });
  });
}
