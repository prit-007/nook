import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforcement test: design-system identity must not drift.
///
/// Checks Phase 12 files for:
/// - Hardcoded `BorderRadius.circular(<number>)` — use NookTokens radius
///   tokens instead.
/// - Deprecated `withOpacity(` — use `withValues(alpha:)` instead.
///
/// These files should be violation-free; other directories will be brought
/// into compliance in subsequent phases.
void main() {
  final phase12Files = <String>[
    'lib/core/theme/nook_tokens.dart',
    'lib/core/widgets/app_shell.dart',
    'lib/features/editor/note_editor_screen.dart',
    'lib/core/router.dart',
  ];

  final hardcodedRadiusRegex = RegExp(
    r'BorderRadius\.circular\(\s*\d+(\.\d+)?\s*\)',
  );
  final withOpacityRegex = RegExp(r'\.withOpacity\(');

  final violations = <String>[];

  for (final relative in phase12Files) {
    final file = File(relative);
    if (!file.existsSync()) continue;

    final contents = file.readAsStringSync();
    final lines = contents.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      if (hardcodedRadiusRegex.hasMatch(line)) {
        violations.add(
          '$relative:$lineNum: hardcoded BorderRadius.circular — use NookTokens radius tokens',
        );
      }
      if (withOpacityRegex.hasMatch(line)) {
        violations.add(
          '$relative:$lineNum: deprecated withOpacity — use withValues(alpha:)',
        );
      }
    }
  }

  test('design system: Phase 12 files have no hardcoded radii or withOpacity',
      () {
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
