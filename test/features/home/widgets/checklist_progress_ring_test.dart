import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home/widgets/checklist_progress_ring.dart';

void main() {
  group('ChecklistProgressRing', () {
    testWidgets('renders progress fraction and respects kFontFloor',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChecklistProgressRing(completed: 3, total: 5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3/5'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('3/5'));
      expect(textWidget.style?.fontSize ?? 12.0, greaterThanOrEqualTo(12.0));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders nothing when total is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChecklistProgressRing(completed: 0, total: 0),
            ),
          ),
        ),
      );
      expect(find.text('0/0'), findsNothing);
    });
  });
}
