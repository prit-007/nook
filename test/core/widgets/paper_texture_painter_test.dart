import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/paper_texture_painter.dart';

void main() {
  group('PaperSurface & PaperTexturePainter', () {
    testWidgets('renders PaperSurface for each PaperPattern', (tester) async {
      for (final pattern in PaperPattern.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PaperSurface(
                pattern: pattern,
                child: const SizedBox(
                  width: 200,
                  height: 120,
                  child: Text('Paper content'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Paper content'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    test('shouldRepaint returns true only when pattern or color changes', () {
      const p1 = PaperTexturePainter(
        pattern: PaperPattern.dotted,
        lineColor: Colors.black,
      );
      const p2 = PaperTexturePainter(
        pattern: PaperPattern.dotted,
        lineColor: Colors.black,
      );
      const p3 = PaperTexturePainter(
        pattern: PaperPattern.graph,
        lineColor: Colors.black,
      );

      expect(p1.shouldRepaint(p2), isFalse);
      expect(p1.shouldRepaint(p3), isTrue);
    });
  });
}
