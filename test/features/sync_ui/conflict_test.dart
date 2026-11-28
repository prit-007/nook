import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/sync_ui/widgets/conflict_card.dart';

void main() {
  group('ConflictCard resolution', () {
    testWidgets('Keep both emits both choice without data loss',
        (tester) async {
      String? resolvedChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConflictCard(
                noteTitle: 'Architecture Notes',
                localDeviceName: 'Pixel 9',
                remoteDeviceName: 'Linux Desktop',
                localContent: 'Local paragraph',
                remoteContent: 'Remote paragraph',
                contentPreview: 'Remote paragraph',
                onResolved: (choice) => resolvedChoice = choice,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conflict: Architecture Notes'), findsOneWidget);
      expect(find.text('Keep this device'), findsOneWidget);
      expect(find.text('Keep incoming'), findsOneWidget);
      expect(find.text('Keep both'), findsOneWidget);

      await tester.tap(find.text('Keep both'));
      await tester.pumpAndSettle();

      expect(resolvedChoice, equals('both'));
    });

    testWidgets('Keep this device and Keep incoming emit local/remote',
        (tester) async {
      final choices = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConflictCard(
                noteTitle: 'Sync Spec',
                localDeviceName: 'Phone',
                remoteDeviceName: 'Tablet',
                onResolved: choices.add,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Keep this device'));
      await tester.pump();
      await tester.tap(find.text('Keep incoming'));
      await tester.pump();

      expect(choices, equals(['local', 'remote']));
    });
  });
}
