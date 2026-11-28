import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';

/// Result of an on-device FOSS OCR extraction.
class OcrResult {
  const OcrResult({
    required this.text,
    this.error,
  });

  final String text;
  final String? error;

  bool get isSuccess => error == null;
}

/// Platform seam for 100% offline, F-Droid-safe Optical Character Recognition.
abstract class OcrService {
  Future<OcrResult> extractText(String imagePath);
}

/// Default FOSS [OcrService]:
/// - Desktop (Linux/macOS/Windows): delegates to system `tesseract` CLI when
///   installed (Apache-2.0, zero proprietary Play Services).
/// - Mobile (Android/iOS): delegates to optional `com.nook/ocr` platform
///   channel; degrades gracefully if no local OCR engine is installed.
class LocalFossOcrService implements OcrService {
  static const MethodChannel _channel = MethodChannel('com.nook/ocr');

  @override
  Future<OcrResult> extractText(String imagePath) async {
    if (kIsWeb) {
      return const OcrResult(
        text: '',
        error: 'Offline OCR is not available in the Web companion.',
      );
    }
    if (imagePath.isEmpty || !File(imagePath).existsSync()) {
      return const OcrResult(text: '', error: 'Image file not found.');
    }

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        final proc = await Process.run(
          'tesseract',
          [imagePath, 'stdout', '--psm', '6'],
        );
        if (proc.exitCode == 0) {
          return OcrResult(text: (proc.stdout as String).trim());
        }
        return OcrResult(
          text: '',
          error: 'Tesseract exited with code ${proc.exitCode}.',
        );
      } on ProcessException {
        return const OcrResult(
          text: '',
          error: 'Install Tesseract OCR (`tesseract-ocr`) for offline desktop '
              'text recognition.',
        );
      }
    }

    try {
      final text = await _channel.invokeMethod<String>('extractText', {
        'imagePath': imagePath,
      });
      return OcrResult(text: (text ?? '').trim());
    } on MissingPluginException {
      return const OcrResult(
        text: '',
        error: 'No offline FOSS OCR engine is installed on this device.',
      );
    } catch (e) {
      return OcrResult(text: '', error: e.toString());
    }
  }
}

final ocrServiceProvider = Provider<OcrService>(
  (ref) => LocalFossOcrService(),
);

/// Indexes OCR-extracted handwriting/doodle text into FTS5 for unlocked notes.
class HandwritingSearchIndexer {
  HandwritingSearchIndexer({
    required AppDatabase db,
    OcrService? ocrService,
  })  : _db = db,
        _ocrService = ocrService ?? LocalFossOcrService();

  final AppDatabase _db;
  final OcrService _ocrService;

  Future<bool> indexDoodleThumbnail({
    required String noteId,
    required String thumbnailPath,
  }) async {
    final noteRepo = NoteRepository(_db);
    final note = await noteRepo.getNoteById(noteId);
    if (note == null || note.locked || note.deleted) {
      return false;
    }

    final result = await _ocrService.extractText(thumbnailPath);
    if (!result.isSuccess || result.text.trim().isEmpty) {
      return false;
    }

    final combinedPlainText = [
      if (note.plainText != null && note.plainText!.trim().isNotEmpty)
        note.plainText!.trim(),
      result.text.trim(),
    ].join('\n');

    await noteRepo.updateContent(
      noteId,
      deltaContent: note.deltaContent,
      plainText: combinedPlainText,
      updatedAt: note.updatedAt,
    );
    return true;
  }
}
