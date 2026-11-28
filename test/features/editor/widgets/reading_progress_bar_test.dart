import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/editor/widgets/reading_progress_bar.dart';

void main() {
  group('ReadingProgressBar', () {
    testWidgets('computes word count, read time, and renders progress',
        (tester) async {
      final sampleText = List<String>.filled(250, 'word').join(' ');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingProgressBar(
              plainText: sampleText,
              scrollProgress: 0.5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('250 words • 2 min read'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    });
  });
}
