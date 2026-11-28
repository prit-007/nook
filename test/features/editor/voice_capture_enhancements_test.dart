import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/voice_capture_service.dart';
import 'package:nook/core/providers/voice_preference_provider.dart';
import 'package:nook/features/editor/widgets/voice_capture_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubVoiceService implements VoiceCaptureService {
  @override
  bool get isListening => false;

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async =>
      true;

  @override
  Future<bool> requestMicrophonePermission() async => true;

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
  }) async {}

  @override
  Future<void> stopListening() async {}
}

void main() {
  group('OfflineVoiceModelManager & VoiceCaptureSheet enhancements', () {
    test('OfflineVoiceModelManager lists and deletes imported models',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('nook_stt_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      final src = File('${tempDir.path}/vosk-mini.bin');
      final bytes = [1, 2, 3, 4, 5, 6];
      await src.writeAsBytes(bytes);
      final hash = sha256.convert(bytes).toString();

      final mgr = OfflineVoiceModelManager(storageDirectory: tempDir);
      await mgr.importModel(sourceFile: src, expectedSha256: hash);

      final models = await mgr.listModels();
      expect(models.map((f) => f.uri.pathSegments.last), ['vosk-mini.bin']);

      await mgr.deleteModel('vosk-mini.bin');
      expect(await mgr.listModels(), isEmpty);
    });

    testWidgets(
        'VoiceCaptureSheet displays offline model status, locale, and append mode',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'voice_capture_enabled': true,
        'voice_disclosure_accepted': true,
      });
      final pref = await VoicePreference.load();
      final tempDir = Directory.systemTemp.createTempSync('nook_stt_ui_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voicePreferenceProvider.overrideWith((_) => pref),
            voiceCaptureServiceProvider.overrideWithValue(_StubVoiceService()),
            offlineVoiceModelManagerProvider.overrideWithValue(
              OfflineVoiceModelManager(storageDirectory: tempDir),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showVoiceCaptureSheet(context),
                  child: const Text('Dictate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dictate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('System speech'), findsOneWidget);
      expect(find.text('Append'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });
  });
}
