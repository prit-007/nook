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

  test('design system: enforced files respect kFontFloor (12.0sp)', () {
    final fontFloorFiles = <String>[
      'lib/core/theme/nook_tokens.dart',
      'lib/core/widgets/app_shell.dart',
      'lib/features/home/home_screen.dart',
      'lib/features/home/widgets/nook_hero.dart',
      'lib/features/editor/note_editor_screen.dart',
      'lib/core/router.dart',
    ];
    final fontSizeRegex = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
    final fontViolations = <String>[];

    for (final relative in fontFloorFiles) {
      final file = File(relative);
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = fontSizeRegex.firstMatch(lines[i]);
        if (match != null) {
          final size = double.tryParse(match.group(1)!);
          if (size != null && size < 12.0) {
            fontViolations.add(
              '$relative:${i + 1}: fontSize $size < 12.0 (NookTokens.kFontFloor)',
            );
          }
        }
      }
    }

    expect(fontViolations, isEmpty, reason: fontViolations.join('\n'));
  });
}
