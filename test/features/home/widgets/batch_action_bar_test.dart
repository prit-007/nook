import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/features/home/widgets/batch_action_bar.dart';

void main() {
  testWidgets('BatchActionBar renders count and responds to action taps',
      (tester) async {
    var pinnedTapped = false;
    var notebookTapped = false;
    var tagTapped = false;
    var deleteTapped = false;
    var closeTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchActionBar(
            selectedCount: 3,
            allPinned: false,
            onTogglePin: () => pinnedTapped = true,
            onMoveToNotebook: () => notebookTapped = true,
            onAddTag: () => tagTapped = true,
            onDelete: () => deleteTapped = true,
            onClose: () => closeTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('3 selected'), findsOneWidget);

    // Tap pin
    await tester.tap(find.byWidgetPredicate(
      (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPin,
    ));
    expect(pinnedTapped, isTrue);

    // Tap notebook
    await tester.tap(find.byWidgetPredicate(
      (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedBook02,
    ));
    expect(notebookTapped, isTrue);

    // Tap tag
    await tester.tap(find.byWidgetPredicate(
      (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedTag01,
    ));
    expect(tagTapped, isTrue);

    // Tap delete
    await tester.tap(find.byWidgetPredicate(
      (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete01,
    ));
    expect(deleteTapped, isTrue);

    // Tap close
    await tester.tap(find.byWidgetPredicate(
      (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedCancel01,
    ));
    expect(closeTapped, isTrue);
  });

  testWidgets('BatchActionBar with 0 count shows Select notes label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatchActionBar(
            selectedCount: 0,
            allPinned: false,
            onTogglePin: () {},
            onMoveToNotebook: () {},
            onAddTag: () {},
            onDelete: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Select notes'), findsOneWidget);
    // Action buttons hidden when 0 selected
    expect(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete01,
      ),
      findsNothing,
    );
  });
}
