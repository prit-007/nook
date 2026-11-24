import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/l10n/generated/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('supports English, Hindi, and Gujarati', () {
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('hi')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('gu')));
    });

    testWidgets('resolves English strings correctly', (tester) async {
      late AppLocalizations loc;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              loc = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(loc.appTitle, 'Nook');
      expect(loc.allNotes, 'All notes');
      expect(loc.favorites, 'Favorites');
      expect(loc.encryptedOnDevice, 'Encrypted on this device');
      expect(loc.backupRecoveryKey, 'Backup Recovery Key');
    });

    testWidgets('resolves Hindi strings correctly', (tester) async {
      late AppLocalizations loc;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('hi'),
          home: Builder(
            builder: (context) {
              loc = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(loc.appTitle, 'नूक');
      expect(loc.allNotes, 'सभी नोट्स');
      expect(loc.favorites, 'पसंदीदा');
      expect(loc.encryptedOnDevice, 'इस डिवाइस पर एन्क्रिप्टेड');
      expect(loc.backupRecoveryKey, 'रिकवरी कुंजी का बैकअप लें');
    });

    testWidgets('resolves Gujarati strings correctly', (tester) async {
      late AppLocalizations loc;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('gu'),
          home: Builder(
            builder: (context) {
              loc = AppLocalizations.of(context)!;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(loc.appTitle, 'નૂક');
      expect(loc.allNotes, 'બધી નોંધો');
      expect(loc.favorites, 'મનપસંદ');
      expect(loc.encryptedOnDevice, 'આ ઉપકરણ પર એન્ક્રિપ્ટેડ');
      expect(loc.backupRecoveryKey, 'રિકવરી કીનો બેકઅપ લો');
    });
  });
}
