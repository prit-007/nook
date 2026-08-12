import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/settings/settings_appearance_screen.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(home: SettingsAppearanceScreen()),
    );
  }

  testWidgets('renders AppBar with title', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('shows theme mode selector', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('THEME MODE'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('shows seed color section', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('SEED COLOR SIGNATURE'), findsOneWidget);
  });

  testWidgets('shows all 12 seed swatches', (tester) async {
    await tester.pumpWidget(buildScreen());
    // 12 NookColors.seeds entries
    final swatches = find.byType(GestureDetector);
    expect(swatches, findsAtLeastNWidgets(12));
  });
}
