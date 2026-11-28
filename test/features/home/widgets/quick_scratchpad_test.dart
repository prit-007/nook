import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home/widgets/quick_scratchpad.dart';

void main() {
  group('QuickScratchpad', () {
    testWidgets('captures text, saves as note, and supports discard',
        (tester) async {
      String? savedText;
      var discarded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickScratchpad(
                isOpen: true,
                onSaveAsNote: (text) => savedText = text,
                onDiscard: () => discarded = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Quick Scratchpad'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Ephemeral idea');
      await tester.pump();

      await tester.tap(find.text('Save as Note'));
      await tester.pump();
      expect(savedText, 'Ephemeral idea');

      await tester.tap(find.text('Discard'));
      await tester.pump();
      expect(discarded, isTrue);
    });
  });
}
