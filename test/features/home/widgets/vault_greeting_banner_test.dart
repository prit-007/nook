import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home/widgets/vault_greeting_banner.dart';

void main() {
  group('VaultGreetingBanner', () {
    testWidgets('renders time-of-day greeting and live vault summary',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultGreetingBanner(
              now: DateTime(2026, 11, 28, 9, 30),
              noteCount: 12,
              openTaskCount: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('12 notes • 3 open tasks'), findsOneWidget);
    });

    testWidgets('adapts greeting for evening and empty vault', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultGreetingBanner(
              now: DateTime(2026, 11, 28, 20, 0),
              noteCount: 0,
              openTaskCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good evening'), findsOneWidget);
      expect(
        find.text('Quiet vault — ready for your first thought'),
        findsOneWidget,
      );
    });
  });
}
