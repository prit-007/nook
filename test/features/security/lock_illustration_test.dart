import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/features/security/widgets/lock_illustration.dart';

void main() {
  Widget buildWidget({
    required List<List<dynamic>> primaryIcon,
    List<List<dynamic>>? badgeIcon,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: LockIllustration(
              primaryIcon: primaryIcon,
              badgeIcon: badgeIcon,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders primary icon', (tester) async {
    await tester.pumpWidget(
      buildWidget(primaryIcon: HugeIcons.strokeRoundedLock),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLock,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders badge icon when provided', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        primaryIcon: HugeIcons.strokeRoundedLock,
        badgeIcon: HugeIcons.strokeRoundedFingerPrint,
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLock,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedFingerPrint,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders without badge when not provided', (tester) async {
    await tester.pumpWidget(
      buildWidget(primaryIcon: HugeIcons.strokeRoundedLock),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedFingerPrint,
      ),
      findsNothing,
    );
  });

  testWidgets('renders with animations disabled without crash', (tester) async {
    await tester.pumpWidget(
      buildWidget(
        primaryIcon: HugeIcons.strokeRoundedLock,
        badgeIcon: HugeIcons.strokeRoundedFingerPrint,
        disableAnimations: true,
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLock,
      ),
      findsOneWidget,
    );
  });
}
