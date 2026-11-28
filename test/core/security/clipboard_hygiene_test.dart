import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/window_manager.dart';
import 'package:nook/core/providers/screenshot_blocker_provider.dart';
import 'package:nook/core/security/clipboard_hygiene.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardHygiene & App-wide FLAG_SECURE (Phase 1.5)', () {
    test('ClipboardHygiene clears clipboard after 60s', () async {
      final writes = <String>[];
      final hygiene = ClipboardHygiene(
        writeClipboard: (text) async => writes.add(text),
      );

      await hygiene.copyWithAutoClear(
        'super-secret-recovery-phrase',
        clearAfter: const Duration(milliseconds: 50),
      );
      expect(writes, ['super-secret-recovery-phrase']);
      expect(hygiene.hasPendingClear, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(writes, ['super-secret-recovery-phrase', '']);
      hygiene.dispose();
    });

    test('ScreenshotBlocker applies and clears FLAG_SECURE globally', () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.nook/window_manager'),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.nook/window_manager'),
          null,
        );
      });

      final blocker = ScreenshotBlocker();
      await blocker.setBlocked(true);
      expect(
        calls.any((c) =>
            c.method == 'addFlags' &&
            c.arguments['flags'] == WindowManager.flagSecure),
        isTrue,
      );

      await blocker.setBlocked(false);
      expect(
        calls.any((c) =>
            c.method == 'clearFlags' &&
            c.arguments['flags'] == WindowManager.flagSecure),
        isTrue,
      );
    });
  });
}
