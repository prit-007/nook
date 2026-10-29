import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/features/home/models/note_sort_order.dart';
import 'package:nook/features/home/widgets/note_sort_sheet.dart';

void main() {
  testWidgets('NoteSortSheet renders options and triggers onSelected',
      (tester) async {
    NoteSortOrder? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                NoteSortSheet.show(
                  context,
                  current: NoteSortOrder.updatedDesc,
                  onSelected: (order) => selected = order,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Sort Vault'), findsOneWidget);
    expect(find.text('Recently modified'), findsOneWidget);
    expect(find.text('Date created'), findsOneWidget);
    expect(find.text('Title (A to Z)'), findsOneWidget);
    expect(find.text('Color theme'), findsOneWidget);

    // Verify checkmark appears on current selection (updatedDesc)
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedCheckmarkCircle02,
      ),
      findsOneWidget,
    );

    // Tap Title (A to Z)
    await tester.tap(find.text('Title (A to Z)'));
    await tester.pumpAndSettle();

    expect(selected, NoteSortOrder.titleAsc);
    expect(find.text('Sort Vault'), findsNothing); // dismissed
  });
}
