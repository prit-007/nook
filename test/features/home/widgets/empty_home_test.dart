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
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('renders the empty state message', (tester) async {
      await tester.pumpWidget(buildEmptyHome());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Your canvas is clear'), findsOneWidget);
    });

    testWidgets('renders the hint text', (tester) async {
      await tester.pumpWidget(buildEmptyHome());
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Tap "New Note" below to capture a thought or sketch.'),
        findsOneWidget,
      );
    });
  });
}
