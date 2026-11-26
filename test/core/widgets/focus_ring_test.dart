import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/focus_ring.dart';

void main() {
  testWidgets('FocusRing changes border on focus gain and loss',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusRing(
            focusNode: node,
            ringColor: Colors.deepPurple,
            child: const Text('Focus Target'),
          ),
        ),
      ),
    );

    // Initial state: not focused
    var container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    var boxDec = container.decoration as BoxDecoration;
    var border = boxDec.border as Border;
    expect(border.top.color, Colors.transparent);

    // Request focus
    node.requestFocus();
    await tester.pumpAndSettle();

    container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    boxDec = container.decoration as BoxDecoration;
    border = boxDec.border as Border;
    expect(border.top.color, Colors.deepPurple);
  });
}
