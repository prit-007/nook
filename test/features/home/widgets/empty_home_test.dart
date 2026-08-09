import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home/widgets/empty_home.dart';

void main() {
  Widget buildEmptyHome() {
    return const MaterialApp(
      home: Scaffold(body: EmptyHome()),
    );
  }

  group('EmptyHome', () {
    testWidgets('renders the empty state icon', (tester) async {
      await tester.pumpWidget(buildEmptyHome());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    });

    testWidgets('renders the empty state message', (tester) async {
      await tester.pumpWidget(buildEmptyHome());
      await tester.pumpAndSettle();

      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('renders the hint text', (tester) async {
      await tester.pumpWidget(buildEmptyHome());
      await tester.pumpAndSettle();

      expect(
        find.text('Tap + to create your first note'),
        findsOneWidget,
      );
    });
  });
}
