import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/sync_ui/widgets/conflict_diff_sheet.dart';

void main() {
  Widget buildSheet({
    String noteTitle = 'Shopping List',
    String localDeviceName = 'Pixel 7',
    String remoteDeviceName = 'MacBook Pro',
    String localText = 'Apples\nBananas\nMilk',
    String remoteText = 'Apples\nBlueberries\nMilk\nBread',
    DateTime? localUpdatedAt,
    DateTime? remoteUpdatedAt,
    void Function(String choice)? onResolved,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showConflictDiffSheet(
                  context,
                  noteTitle: noteTitle,
                  localDeviceName: localDeviceName,
                  remoteDeviceName: remoteDeviceName,
                  localText: localText,
                  remoteText: remoteText,
                  localUpdatedAt: localUpdatedAt,
                  remoteUpdatedAt: remoteUpdatedAt,
                  onResolved: onResolved,
                );
              },
              child: const Text('Open Sheet'),
            );
          },
        ),
      ),
    );
  }

  testWidgets('renders diff stats, title, and device labels', (tester) async {
    await tester.pumpWidget(buildSheet(
      localText: 'Hello World\nLine 2',
      remoteText: 'Hello Brave World\nLine 2\nLine 3',
    ));

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Shopping List'), findsWidgets);
    expect(find.textContaining('Pixel 7'), findsWidgets);
    expect(find.textContaining('MacBook Pro'), findsWidgets);
    // Badges should exist (+2 additions)
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
  });

  testWidgets('can toggle between diff view and side-by-side view',
      (tester) async {
    await tester.pumpWidget(buildSheet(
      localText: 'Alpha\nBeta',
      remoteText: 'Alpha\nGamma',
    ));

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Changes'), findsOneWidget);
    expect(find.text('Side by Side'), findsOneWidget);

    // Switch to side-by-side
    await tester.tap(find.text('Side by Side'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Beta'), findsOneWidget);
    expect(find.textContaining('Gamma'), findsOneWidget);
  });

  testWidgets('resolution buttons invoke callback and pop sheet',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(buildSheet(
      onResolved: (choice) => chosen = choice,
    ));

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Keep this device'), findsOneWidget);
    expect(find.text('Keep incoming'), findsOneWidget);
    expect(find.text('Keep both'), findsOneWidget);

    // Tap Keep incoming
    await tester.tap(find.text('Keep incoming'));
    await tester.pumpAndSettle();

    expect(chosen, 'remote');
    expect(find.byType(ConflictDiffSheet), findsNothing);
  });

  testWidgets('tapping keep this device returns local', (tester) async {
    String? chosen;
    await tester.pumpWidget(buildSheet(
      onResolved: (choice) => chosen = choice,
    ));

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep this device'));
    await tester.pumpAndSettle();

    expect(chosen, 'local');
    expect(find.byType(ConflictDiffSheet), findsNothing);
  });

  testWidgets('tapping keep both returns both', (tester) async {
    String? chosen;
    await tester.pumpWidget(buildSheet(
      onResolved: (choice) => chosen = choice,
    ));

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep both'));
    await tester.pumpAndSettle();

    expect(chosen, 'both');
    expect(find.byType(ConflictDiffSheet), findsNothing);
  });
}
