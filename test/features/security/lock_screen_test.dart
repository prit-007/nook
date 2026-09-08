import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/features/security/lock_screen.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(home: LockScreen()),
    );
  }

  testWidgets('renders lock title', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('nook. is locked'), findsOneWidget);
  });

  testWidgets('renders auth subtitle', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(
      find.text('Authentication required to continue'),
      findsOneWidget,
    );
  });

  testWidgets('renders fingerprint icon', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedFingerPrint),
        findsOneWidget);
  });

  testWidgets('renders PIN fallback when PIN enabled', (tester) async {
    await tester.pumpWidget(buildScreen());
    // PIN fallback is hidden by default (pin not enabled).
    expect(find.text('Use PIN instead'), findsNothing);
  });
}
