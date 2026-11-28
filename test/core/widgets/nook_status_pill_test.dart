import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/widgets/nook_status_pill.dart';

void main() {
  group('NookStatusPill', () {
    testWidgets('renders message, icon, and invokes Undo callback',
        (tester) async {
      var undone = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NookStatusPill(
                message: 'Note archived',
                icon: HugeIcons.strokeRoundedArchive,
                actionLabel: 'Undo',
                onAction: () => undone = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Note archived'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      expect(undone, isTrue);
    });
  });
}
