import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/masked_reveal_text.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  SlideTransition slideOf(WidgetTester tester) =>
      tester.widget<SlideTransition>(
        find.descendant(
          of: find.byType(MaskedRevealText),
          matching: find.byType(SlideTransition),
        ),
      );

  group('MaskedRevealText', () {
    testWidgets('renders the text', (tester) async {
      await tester.pumpWidget(wrap(const MaskedRevealText('Archive')));
      await tester.pump();

      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('starts fully below the mask', (tester) async {
      await tester.pumpWidget(wrap(const MaskedRevealText('Archive')));
      await tester.pump();

      expect(slideOf(tester).position.value, const Offset(0, 1));
    });

    testWidgets('slides up to its resting position', (tester) async {
      await tester.pumpWidget(wrap(const MaskedRevealText('Archive')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(slideOf(tester).position.value, Offset.zero);
    });

    testWidgets('mid-animation is strictly between mask and rest',
        (tester) async {
      await tester.pumpWidget(
        wrap(const MaskedRevealText('Archive',
            duration: Duration(milliseconds: 700))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final dy = slideOf(tester).position.value.dy;
      expect(dy, greaterThan(0));
      expect(dy, lessThan(1));
    });

    testWidgets('respects the stagger delay', (tester) async {
      await tester.pumpWidget(
        wrap(const MaskedRevealText(
          'Archive',
          duration: Duration(milliseconds: 700),
          delay: Duration(milliseconds: 400),
        )),
      );
      await tester.pump();

      // Before the delay elapses the text must still be masked.
      await tester.pump(const Duration(milliseconds: 300));
      expect(slideOf(tester).position.value.dy, 1.0);

      // Once the delay passes, the reveal begins.
      await tester.pump(const Duration(milliseconds: 250));
      expect(slideOf(tester).position.value.dy, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(slideOf(tester).position.value, Offset.zero);
    });

    testWidgets('calls onComplete only after the animation finishes',
        (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        wrap(MaskedRevealText(
          'Archive',
          delay: const Duration(milliseconds: 200),
          onComplete: () => completed++,
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(completed, 0);

      await tester.pumpAndSettle();
      expect(completed, 1);
    });

    testWidgets('applies the provided style', (tester) async {
      const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w900);
      await tester.pumpWidget(
        wrap(const MaskedRevealText('Archive', style: style)),
      );
      await tester.pump();

      expect(tester.widget<Text>(find.text('Archive')).style, style);
    });

    testWidgets('clips text while it slides', (tester) async {
      await tester.pumpWidget(wrap(const MaskedRevealText('Archive')));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(MaskedRevealText),
          matching: find.byType(ClipRect),
        ),
        findsOneWidget,
      );
    });

    testWidgets('optionally fades the text in', (tester) async {
      await tester.pumpWidget(
        wrap(const MaskedRevealText('Archive', fade: true)),
      );
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(MaskedRevealText),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 0);

      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
    });

    testWidgets('propagates maxLines and textAlign', (tester) async {
      await tester.pumpWidget(
        wrap(const MaskedRevealText(
          'A very long archive title',
          maxLines: 2,
          textAlign: TextAlign.center,
        )),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('A very long archive title'));
      expect(text.maxLines, 2);
      expect(text.textAlign, TextAlign.center);
    });
  });
}
