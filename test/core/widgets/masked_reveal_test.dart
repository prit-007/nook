import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/masked_reveal.dart';

void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: child,
          ),
        ),
      ),
    );
  }

  group('MaskedReveal', () {
    testWidgets('animates by default (slide + clip)', (tester) async {
      await tester.pumpWidget(
        wrap(const MaskedReveal(child: Text('Revealed'))),
      );
      await tester.pump();

      expect(find.text('Revealed'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaskedReveal),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(MaskedReveal),
          matching: find.byType(ClipRect),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('fade variant adds a FadeTransition', (tester) async {
      await tester.pumpWidget(
        wrap(const MaskedReveal(fade: true, child: Text('Revealed'))),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(MaskedReveal),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('renders the final state immediately with reduce motion',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const MaskedReveal(child: Text('Revealed')),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('Revealed'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaskedReveal),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(MaskedReveal),
          matching: find.byType(ClipRect),
        ),
        findsNothing,
      );
    });

    testWidgets('calls onComplete even with reduce motion', (tester) async {
      var completed = false;
      await tester.pumpWidget(
        wrap(
          MaskedReveal(
            onComplete: () => completed = true,
            child: const Text('Revealed'),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });
  });
}
