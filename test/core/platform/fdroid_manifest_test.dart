import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/voice_preference_provider.dart';

void main() {
  group('F-Droid manifest & build flag compliance', () {
    test('AndroidManifest.xml does not declare RECORD_AUDIO', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(manifest.existsSync(), isTrue);
      final content = manifest.readAsStringSync();
      expect(
        content.contains('android.permission.RECORD_AUDIO'),
        isFalse,
        reason:
            'Main AndroidManifest.xml must not declare RECORD_AUDIO so F-Droid builds never request microphone permission.',
      );
    });

    test('VoicePreference disables voice capture when NOOK_FDROID=true', () {
      const fdroidFlag = bool.fromEnvironment('NOOK_FDROID');
      expect(kIsFdroidFlavor, equals(fdroidFlag));

      final pref = VoicePreference(enabled: true, disclosureAccepted: true);
      if (fdroidFlag) {
        expect(pref.isSupported, isFalse);
        expect(pref.enabled, isFalse);
      } else {
        expect(pref.isSupported, isTrue);
        expect(pref.enabled, isTrue);
      }
    });
  });
}
