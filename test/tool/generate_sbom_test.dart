import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/generate_sbom.dart' as sbom_tool;

void main() {
  group('SBOM generator (Phase 6)', () {
    test('parses pubspec.lock into CycloneDX components', () {
      const sample = '''
packages:
  drift:
    dependency: "direct main"
    source: hosted
    version: "2.26.0"
  cbor:
    dependency: "direct main"
    source: hosted
    version: "6.3.5"
sdks:
  dart: ">=3.6.0 <4.0.0"
''';
      final sbom = sbom_tool.buildSbomFromLockfile(sample);
      expect(sbom['bomFormat'], 'CycloneDX');
      final components = sbom['components'] as List<Map<String, dynamic>>;
      expect(components, hasLength(2));
      expect(components.first['name'], 'drift');
      expect(components.first['version'], '2.26.0');
    });

    test('parses repository pubspec.lock cleanly', () {
      final lock = File('pubspec.lock').readAsStringSync();
      final sbom = sbom_tool.buildSbomFromLockfile(lock);
      final components = sbom['components'] as List<Map<String, dynamic>>;
      expect(components.length, greaterThan(50));
    });
  });
}
