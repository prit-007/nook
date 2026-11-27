import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/voice_capture_service.dart';
import 'package:nook/core/providers/voice_preference_provider.dart';
import 'package:nook/features/editor/widgets/voice_capture_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeVoiceService implements VoiceCaptureService {
  _FakeVoiceService({this.available = true, this.simulatedWords = ''});

  final bool available;
  final String simulatedWords;
  bool listening = false;
  bool cancelled = false;
  bool initialized = false;
  bool permissionChecked = false;
  bool permissionRequested = false;

  @override
  bool get isListening => listening;

  @override
  Future<bool> hasPermission() async {
    permissionChecked = true;
    return false;
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    permissionRequested = true;
    return true;
  }

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
    initialized = true;
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('VoicePreference defaults to disabled and disclosure unaccepted',
      () async {
    final pref = await VoicePreference.load();
    expect(pref.enabled, isFalse);
    expect(pref.disclosureAccepted, isFalse);
  });

  testWidgets(
      'VoiceCaptureSheet shows one-time disclosure before requesting mic',
      (tester) async {
    final fake = _FakeVoiceService(simulatedWords: 'Buy oat milk tomorrow');
    final pref = VoicePreference(enabled: true, disclosureAccepted: false);
    String? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceCaptureServiceProvider.overrideWithValue(fake),
          voicePreferenceProvider.overrideWith((ref) => pref),
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

    expect(find.text('Voice speech service'), findsOneWidget);
    expect(find.textContaining('Marmalade STT'), findsOneWidget);
    expect(fake.initialized, isFalse);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(pref.disclosureAccepted, isTrue);
    expect(fake.permissionChecked, isTrue);
    expect(fake.permissionRequested, isTrue);
    expect(fake.initialized, isTrue);
    expect(find.text('Buy oat milk tomorrow'), findsOneWidget);

    await tester.tap(find.text('Use Text'));
    await tester.pumpAndSettle();

    expect(result, 'Buy oat milk tomorrow');
  });

  testWidgets('VoiceCaptureSheet handles unavailable recognizer gracefully',
      (tester) async {
    final fake = _FakeVoiceService(available: false);
    final pref = VoicePreference(enabled: true, disclosureAccepted: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceCaptureServiceProvider.overrideWithValue(fake),
          voicePreferenceProvider.overrideWith((ref) => pref),
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

  testWidgets(
      'verifies requestMicrophonePermission is called when permission not granted',
      (tester) async {
    final fake = _FakeVoiceService(available: true);
    final pref = VoicePreference(enabled: true, disclosureAccepted: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceCaptureServiceProvider.overrideWithValue(fake),
          voicePreferenceProvider.overrideWith((ref) => pref),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showVoiceCaptureSheet(context),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(fake.permissionChecked, isFalse);
    expect(fake.permissionRequested, isFalse);

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(fake.permissionChecked, isTrue);
    expect(fake.permissionRequested, isTrue);
  });

  test('SpeechToTextVoiceCaptureService handles permission methods safely',
      () async {
    final service = SpeechToTextVoiceCaptureService();
    expect(await service.hasPermission(), isFalse);
    expect(await service.requestMicrophonePermission(), isFalse);
  });
}
