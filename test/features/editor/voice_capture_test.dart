import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/voice_capture_service.dart';
import 'package:nook/features/editor/widgets/voice_capture_sheet.dart';

class _FakeVoiceService implements VoiceCaptureService {
  _FakeVoiceService({this.available = true, this.simulatedWords = ''});

  final bool available;
  final String simulatedWords;
  bool listening = false;
  bool cancelled = false;

  @override
  bool get isListening => listening;

  @override
  Future<void> cancel() async {
    listening = false;
    cancelled = true;
  }

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    return available;
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
  }) async {
    listening = true;
    if (simulatedWords.isNotEmpty) {
      onResult(simulatedWords, true);
      listening = false;
    }
  }

  @override
  Future<void> stopListening() async {
    listening = false;
  }
}

void main() {
  testWidgets('VoiceCaptureSheet displays transcript and returns text',
      (tester) async {
    final fake = _FakeVoiceService(simulatedWords: 'Buy oat milk tomorrow');
    String? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceCaptureServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showVoiceCaptureSheet(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Buy oat milk tomorrow'), findsOneWidget);
    await tester.tap(find.text('Use Text'));
    await tester.pumpAndSettle();

    expect(result, 'Buy oat milk tomorrow');
  });

  testWidgets('VoiceCaptureSheet handles unavailable recognizer gracefully',
      (tester) async {
    final fake = _FakeVoiceService(available: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceCaptureServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showVoiceCaptureSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Speech recognition is not available on this device.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
