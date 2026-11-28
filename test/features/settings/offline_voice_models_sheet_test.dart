import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/voice_capture_service.dart';
import 'package:nook/features/settings/widgets/offline_voice_models_sheet.dart';

void main() {
  group('OfflineVoiceModelsSheet', () {
    testWidgets('lists, imports with SHA-256, and deletes offline models',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('nook_stt_sheet_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final src = File('${tempDir.path}/whisper-tiny.bin');
      final bytes = [10, 20, 30, 40];
      src.writeAsBytesSync(bytes);
      final hash = sha256.convert(bytes).toString();

      final mgr = OfflineVoiceModelManager(storageDirectory: tempDir);
      await tester.runAsync(() async {
        await mgr.importModel(sourceFile: src, expectedSha256: hash);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            offlineVoiceModelManagerProvider.overrideWithValue(mgr),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineVoiceModelsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline Voice Models'), findsOneWidget);
      expect(find.text('whisper-tiny.bin'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete model'));
      await tester.pumpAndSettle();
      expect(find.text('whisper-tiny.bin'), findsNothing);
    });
  });
}
