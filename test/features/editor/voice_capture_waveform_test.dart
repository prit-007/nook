import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/editor/widgets/voice_capture_sheet.dart';

void main() {
  group('ListeningWaveform', () {
    testWidgets('renders animated waveform bars and disposes cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ListeningWaveform(active: true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
