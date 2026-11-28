import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/animated_squircle.dart';

void main() {
  group('SquircleBorder & AnimatedSquircle', () {
    test('SquircleBorder lerps cleanly between radii and with CircleBorder',
        () {
      const a = SquircleBorder(cornerRadius: 12);
      const b = SquircleBorder(cornerRadius: 28);
      final mid = ShapeBorder.lerp(a, b, 0.5) as SquircleBorder?;
      expect(mid, isNotNull);
      expect(mid!.cornerRadius, closeTo(20.0, 0.01));

      final toCircle = ShapeBorder.lerp(a, const CircleBorder(), 0.5);
      expect(toCircle, isNotNull);
    });

    testWidgets('AnimatedSquircle morphs between SquircleShape variants',
        (tester) async {
      Widget buildSquircle(SquircleShape shape) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSquircle(
                shape: shape,
                size: 72,
                child: const Text('M3'),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSquircle(SquircleShape.squircle));
      expect(find.text('M3'), findsOneWidget);
      expect(find.byType(Material), findsWidgets);

      await tester.pumpWidget(buildSquircle(SquircleShape.clover));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(find.text('M3'), findsOneWidget);

      await tester.pumpWidget(buildSquircle(SquircleShape.circle));
      await tester.pumpAndSettle();
      expect(find.text('M3'), findsOneWidget);
    });

    testWidgets('AnimatedSquircle supports tap and press scale animation',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSquircle(
                shape: SquircleShape.squircle,
                onTap: () => tapped = true,
                child: const Text('Tap'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });
}
