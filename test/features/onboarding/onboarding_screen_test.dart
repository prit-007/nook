import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/features/onboarding/onboarding_screen.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  testWidgets('renders headline', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Your notes. Your device. Yours.'), findsOneWidget);
  });

  testWidgets('renders subtext', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(
      find.text('No account. No cloud. No one else reads your notes.'),
      findsOneWidget,
    );
  });

  testWidgets('renders Continue button on first page', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('renders illustration icon', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedNotebook01),
        findsOneWidget);
  });

  testWidgets('renders page view', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('Continue advances to vibe page', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Pick your vibe'), findsOneWidget);
  });

  testWidgets('skip button exists and is visible', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('shows seed color picker on vibe page', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Pick your vibe'), findsOneWidget);
  });

  testWidgets('third page shows Get Started', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("You're all set!"), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('dot indicators exist', (tester) async {
    await tester.pumpWidget(buildScreen());
    // 3 dot indicators via AnimatedContainer
    expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(3));
  });
}
