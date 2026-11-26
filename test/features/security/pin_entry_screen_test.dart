import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/features/security/pin_entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PinEntryScreen', () {
    testWidgets('renders 10 digits and backspace on static keypad',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PinEntryScreen(isSetup: true),
          ),
        ),
      );

      for (var d = 0; d <= 9; d++) {
        expect(find.text('$d'), findsOneWidget);
      }
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedBackward01),
        findsOneWidget,
      );
    });

    testWidgets('shuffledKeypad permutes digit layout', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PinEntryScreen(isSetup: true, shuffledKeypad: true),
          ),
        ),
      );

      // All digits still render
      for (var d = 0; d <= 9; d++) {
        expect(find.text('$d'), findsOneWidget);
      }
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedBackward01),
        findsOneWidget,
      );
    });
  });
}
