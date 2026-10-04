import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/settings/privacy_explainer_copy.dart';
import 'package:nook/features/settings/privacy_explainer_screen.dart';
import 'package:nook/features/settings/settings_privacy_screen.dart';

void main() {
  group('PrivacyExplainerScreen', () {
    Widget buildExplainer() {
      return const MaterialApp(home: PrivacyExplainerScreen());
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 200,
          scrollable: find
              .byType(
                Scrollable,
              )
              .first);
    }

    testWidgets('renders all four explainer sections', (tester) async {
      await tester.pumpWidget(buildExplainer());

      await scrollTo(tester, find.text(kPrivacyWhereDataLivesTitle));
      expect(find.text(kPrivacyWhereDataLivesTitle), findsOneWidget);

      await scrollTo(tester, find.text(kPrivacyWhatSyncSendsTitle));
      expect(find.text(kPrivacyWhatSyncSendsTitle), findsOneWidget);

      await scrollTo(tester, find.text(kPrivacyNeverCollectsTitle));
      expect(find.text(kPrivacyNeverCollectsTitle), findsOneWidget);

      await scrollTo(tester, find.text(kPrivacyHowToVerifyTitle));
      expect(find.text(kPrivacyHowToVerifyTitle), findsOneWidget);
    });

    testWidgets('shows motto footer', (tester) async {
      await tester.pumpWidget(buildExplainer());
      final motto = find.textContaining('Your notes. Your device. Yours.');
      await scrollTo(tester, motto);
      expect(motto, findsOneWidget);
    });

    testWidgets('privacy screen links to explainer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsPrivacyScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('How your data stays yours'), findsOneWidget);
    });
  });
}
