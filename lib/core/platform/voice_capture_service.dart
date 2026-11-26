import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Platform seam for offline/on-device speech-to-text dictation.
abstract class VoiceCaptureService {
  bool get isListening;

  /// Checks whether microphone permission is granted at runtime.
  Future<bool> hasPermission();

  /// Prompts the user for runtime microphone permission.
  Future<bool> requestMicrophonePermission();

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  });

  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
  });

  Future<void> stopListening();

  Future<void> cancel();
}

/// Default [VoiceCaptureService] backed by `package:speech_to_text`
/// (uses the platform's built-in speech recognizer; no cloud API keys).
class SpeechToTextVoiceCaptureService implements VoiceCaptureService {
  SpeechToTextVoiceCaptureService([SpeechToText? speech])
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _speech.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      return await _speech.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    try {
      return await _speech.initialize(
        onStatus: onStatus,
        onError: (err) => onError?.call(err.errorMsg),
      );
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
  }) async {
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

final voiceCaptureServiceProvider = Provider<VoiceCaptureService>(
  (ref) => SpeechToTextVoiceCaptureService(),
);
