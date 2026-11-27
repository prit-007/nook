import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ascii_layout.dart';

void main() {
  testWidgets('asciiLayout generates snapshot of keyed regions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Container(
                key: const Key('sidebar'),
                width: 200,
                color: Colors.blue,
              ),
              Expanded(
                child: Container(
                  key: const Key('content'),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final snapshot = asciiLayout(
      tester,
      {
        'sidebar': find.byKey(const Key('sidebar')),
        'content': find.byKey(const Key('content')),
      },
      cols: 40,
      rows: 10,
    );

    expect(snapshot, contains('sidebar'));
    expect(snapshot, contains('content'));

    expectLayoutSnap(snapshot, 'ascii_layout_smoke_test');
  });
}
