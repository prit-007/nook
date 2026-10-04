import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/settings/privacy_explainer_copy.dart';

void main() {
  group('Privacy explainer copy', () {
    test('all four section titles exist and are non-empty', () {
      expect(kPrivacyWhereDataLivesTitle, isNotEmpty);
      expect(kPrivacyWhatSyncSendsTitle, isNotEmpty);
      expect(kPrivacyNeverCollectsTitle, isNotEmpty);
      expect(kPrivacyHowToVerifyTitle, isNotEmpty);
    });

    test('bodies mention local storage / keystore / P2P / no account', () {
      expect(kPrivacyWhereDataLivesBody.toLowerCase(), contains('device'));
      expect(kPrivacyWhereDataLivesBody.toLowerCase(), contains('keystore'));
      expect(kPrivacyWhatSyncSendsBody.toLowerCase(), contains('pairing'));
      expect(kPrivacyNeverCollectsBody.toLowerCase(), contains('no account'));
      expect(kPrivacyNeverCollectsBody.toLowerCase(), contains('analytics'));
      expect(kPrivacyHowToVerifyBody.toLowerCase(), contains('export'));
      expect(kPrivacyHowToVerifyBody.toLowerCase(), contains('source'));
    });

    test('copy never contains forbidden marketing phrases', () {
      final corpus = [
        kPrivacyWhereDataLivesBody,
        kPrivacyWhatSyncSendsBody,
        kPrivacyNeverCollectsBody,
        kPrivacyHowToVerifyBody,
        kPrivacyWhereDataLivesTitle,
        kPrivacyWhatSyncSendsTitle,
        kPrivacyNeverCollectsTitle,
        kPrivacyHowToVerifyTitle,
      ].join('\n').toLowerCase();

      for (final phrase in kPrivacyForbiddenPhrases) {
        expect(
          corpus.contains(phrase.toLowerCase()),
          isFalse,
          reason: 'Forbidden phrase "$phrase" found in privacy copy',
        );
      }
    });
  });
}
