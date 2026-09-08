import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/features/quick_note/quick_note_overlay.dart';

/// Creates an in-memory test database and wraps the quick note overlay
/// in a ProviderScope + MaterialApp for widget testing.
Widget buildOverlay() {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(createTestDatabase()),
    ],
    child: const MaterialApp(
      home: QuickNoteOverlay(),
    ),
  );
}

void main() {
  testWidgets('renders quick note overlay with text field', (tester) async {
    await tester.pumpWidget(buildOverlay());
    await tester.pumpAndSettle();

    expect(find.text('Quick Note'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Esc to close'), findsOneWidget);
    expect(find.text('Save & Close'), findsOneWidget);
  });

  testWidgets('text field is auto-focused on open', (tester) async {
    await tester.pumpWidget(buildOverlay());
    await tester.pumpAndSettle();

    // The text field should have focus.
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('shows auto-save hint', (tester) async {
    await tester.pumpWidget(buildOverlay());
    await tester.pumpAndSettle();

    expect(find.text('Auto-saves'), findsOneWidget);
  });

  testWidgets('tapping outside card dismisses overlay', (tester) async {
    await tester.pumpWidget(buildOverlay());
    await tester.pumpAndSettle();

    // Tap the top-left corner (outside the card).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // The overlay should be dismissed — no more Quick Note text.
    expect(find.text('Quick Note'), findsNothing);
  });

  testWidgets('empty note is dismissed without saving', (tester) async {
    await tester.pumpWidget(buildOverlay());
    await tester.pumpAndSettle();

    // Tap "Save & Close" with empty text.
    await tester.tap(find.text('Save & Close'));
    await tester.pumpAndSettle();

    // Overlay should be dismissed.
    expect(find.text('Quick Note'), findsNothing);
  });
}
