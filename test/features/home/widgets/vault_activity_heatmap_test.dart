import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home/widgets/vault_activity_heatmap.dart';

void main() {
  group('VaultActivityHeatmap', () {
    testWidgets('renders 12-week cadence grid and active day count',
        (tester) async {
      final refDate = DateTime.utc(2026, 11, 28);
      final dates = [
        refDate,
        refDate,
        refDate.subtract(const Duration(days: 2)),
        refDate.subtract(const Duration(days: 5)),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VaultActivityHeatmap(
                activityDates: dates,
                weeks: 12,
                referenceDate: refDate,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Vault Cadence'), findsOneWidget);
      expect(find.text('3 active days'), findsOneWidget);
      expect(find.byType(Tooltip), findsNWidgets(84));
    });
  });
}
