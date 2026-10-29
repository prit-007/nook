import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/editor/widgets/revision_diff_view.dart';

void main() {
  testWidgets(
      'RevisionDiffView displays additions, deletions and diff segments',
      (tester) async {
    const oldText = 'First line\nSecond line';
    const newText = 'First line\nModified line\nThird line';

    var restored = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RevisionDiffView(
            revisionTitle: 'v1 Title',
            currentTitle: 'Current Title',
            revisionText: oldText,
            currentText: newText,
            revisionDate: DateTime(2026, 10, 29, 12, 0),
            onRestore: () {
              restored = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check title diff or display
    expect(find.textContaining('v1 Title'), findsOneWidget);

    // Check stats indicators
    expect(find.textContaining('+2'), findsOneWidget); // 2 added lines
    expect(find.textContaining('-1'), findsOneWidget); // 1 deleted line

    // Verify diff segments rendered
    expect(find.textContaining('First line'), findsOneWidget);
    expect(find.textContaining('Second line'), findsOneWidget);
    expect(find.textContaining('Modified line'), findsOneWidget);

    // Toggle to "Snapshot" mode
    await tester.tap(find.text('Full Snapshot'));
    await tester.pumpAndSettle();

    expect(find.text(oldText), findsOneWidget);

    // Tap restore button
    await tester.tap(find.text('Restore this version'));
    await tester.pumpAndSettle();

    expect(restored, isTrue);
  });
}
