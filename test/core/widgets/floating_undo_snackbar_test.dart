import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/floating_undo_snackbar.dart';

void main() {
  testWidgets('showUndoSnackBar renders message and calls onUndo on tap',
      (tester) async {
    var undone = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showUndoSnackBar(
                  context,
                  message: '2 notes moved to Bin',
                  onUndo: () async => undone = true,
                );
              },
              child: const Text('Delete'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('2 notes moved to Bin'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
  });
}
