import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/sync_ui/widgets/sync_radar.dart';

void main() {
  group('SyncRadarWidget', () {
    testWidgets('renders radar rings, peer count, and disposes cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SyncRadarWidget(
                peerCount: 2,
                active: true,
                statusLabel: '2 peers nearby',
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('2 peers nearby'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
