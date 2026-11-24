import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/resizable_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({
    double initialRatio = 0.4,
    double minRatio = 0.2,
    double maxRatio = 0.8,
    String storageKey = 'test_split_ratio',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1000,
          height: 600,
          child: ResizableSplitView(
            storageKey: storageKey,
            initialRatio: initialRatio,
            minRatio: minRatio,
            maxRatio: maxRatio,
            left: const Center(key: Key('left_pane'), child: Text('Left Pane')),
            right:
                const Center(key: Key('right_pane'), child: Text('Right Pane')),
          ),
        ),
      ),
    );
  }

  testWidgets('renders both left and right panes', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('left_pane')), findsOneWidget);
    expect(find.byKey(const Key('right_pane')), findsOneWidget);
    expect(find.byType(DraggableSplitDivider), findsOneWidget);
  });

  testWidgets('loads persisted ratio from SharedPreferences', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('test_split_ratio', 0.6);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final leftBox = tester.getRect(find.byKey(const Key('left_pane')));
    // Default test viewport width is 800dp. With ratio 0.6, left pane is ~474dp (800 * 0.6 - divider/2)
    expect(leftBox.width, closeTo(800 * 0.6, 20));
  });

  testWidgets('dragging divider adjusts pane widths and persists value',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(initialRatio: 0.4));
    await tester.pumpAndSettle();

    final dividerFinder = find.byType(DraggableSplitDivider);
    expect(dividerFinder, findsOneWidget);

    // Drag divider 100px to the right
    await tester.drag(dividerFinder, const Offset(100, 0));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final savedRatio = prefs.getDouble('test_split_ratio');
    expect(savedRatio, isNotNull);
    // 0.4 + 100/1000 = 0.5
    expect(savedRatio!, closeTo(0.5, 0.05));
  });
}
