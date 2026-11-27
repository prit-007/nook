import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
      final granted = await _speech.hasPermission;
      if (granted) return true;
      // SpeechToText triggers the OS runtime permission request dialog during initialize()
      return await _speech.initialize();
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

/// Manages user-imported offline speech-to-text model files with mandatory
/// SHA-256 checksum verification (zero network downloads).
class OfflineVoiceModelManager {
  OfflineVoiceModelManager({Directory? storageDirectory})
      : _storageDirectory = storageDirectory;

  final Directory? _storageDirectory;

  Future<File> importModel({
    required File sourceFile,
    required String expectedSha256,
  }) async {
    if (!await sourceFile.exists()) {
      throw FileSystemException('Model file not found', sourceFile.path);
    }
    final bytes = await sourceFile.readAsBytes();
    final actualHash = sha256.convert(bytes).toString().toLowerCase();
    if (actualHash != expectedSha256.trim().toLowerCase()) {
      throw FormatException(
        'Model SHA-256 mismatch: expected $expectedSha256, got $actualHash',
      );
    }

    final dir = _storageDirectory ?? await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(dir.path, 'stt_models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    final dest = File(p.join(modelsDir.path, p.basename(sourceFile.path)));
    if (sourceFile.path != dest.path) {
      await dest.writeAsBytes(bytes, flush: true);
    }
    return dest;
  }
}
