import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/selection_action_dock.dart';

void main() {
  group('SelectionActionDock', () {
    testWidgets('morphs between normalDock and batch action bar',
        (tester) async {
      var cleared = false;
      var pinned = false;

      Widget buildDock({required bool isSelecting, required int count}) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: SelectionActionDock(
                isSelecting: isSelecting,
                selectedCount: count,
                normalDock: const Text('Normal Dock'),
                onClearSelection: () => cleared = true,
                onPinSelected: () => pinned = true,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildDock(isSelecting: false, count: 0));
      expect(find.text('Normal Dock'), findsOneWidget);
      expect(find.text('2 selected'), findsNothing);

      await tester.pumpWidget(buildDock(isSelecting: true, count: 2));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Normal Dock'), findsNothing);

      await tester.tap(find.byTooltip('Pin selected'));
      expect(pinned, isTrue);

      await tester.tap(find.byTooltip('Clear selection'));
      expect(cleared, isTrue);
    });
  });
}
