import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/providers/talker_provider.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import '../editor/markdown_import.dart';
import 'import_summary.dart';

/// Importer for plain text files (`.txt`) and delimiter-separated text blobs.
class PlainTextImporter {
  PlainTextImporter(this._repo);

  final NoteRepository _repo;

  /// Imports a raw string as one or multiple notes.
  ///
  /// If [delimiter] is provided (e.g. `\n---\n` or `\n===+\n`), splits the
  /// content into multiple notes.
  Future<ImportSummary> importText(
    String content, {
    String? defaultTitle,
    String? delimiter,
  }) async {
    final errors = <String>[];
    var imported = 0;

    final chunks = delimiter != null && delimiter.isNotEmpty
        ? content.split(RegExp(delimiter, multiLine: true))
        : [content];

    for (final rawChunk in chunks) {
      final chunk = rawChunk.trim();
      if (chunk.isEmpty) continue;
      try {
        final title = defaultTitle ?? _deriveTitle(chunk);
        final deltaJson = markdownToAppFlowyJson(chunk);
        final plain = extractPlainTextFromAppFlowyJson(deltaJson);
        final isChecklist =
            RegExp(r'^\s*- \[[ xX]\]', multiLine: true).hasMatch(chunk);

        await _repo.createNote(
          title: title,
          type: isChecklist ? NoteType.checklist : NoteType.text,
          deviceOriginId: 'local',
          deltaContent: deltaJson,
          plainText: plain.isNotEmpty ? plain : chunk,
        );
        imported++;
      } catch (e) {
        errors.add('Failed to import text chunk: $e');
        nookLog(
          NookLogKey.database,
          'PlainTextImporter error: $e',
          LogLevel.error,
        );
      }
    }

    return ImportSummary(
      notesImported: imported,
      filesProcessed: 1,
      errors: errors,
    );
  }

  /// Imports multiple plain text files.
  Future<ImportSummary> importFiles(List<File> files) async {
    var imported = 0;
    final errors = <String>[];

    for (final file in files) {
      try {
        if (!await file.exists()) {
          errors.add('File not found: ${file.path}');
          continue;
        }
        final content = await file.readAsString();
        if (content.trim().isEmpty) continue;

        final fileName = p.basenameWithoutExtension(file.path);
        final title = fileName.isNotEmpty ? fileName : _deriveTitle(content);
        final deltaJson = markdownToAppFlowyJson(content);
        final plain = extractPlainTextFromAppFlowyJson(deltaJson);
        final isChecklist =
            RegExp(r'^\s*- \[[ xX]\]', multiLine: true).hasMatch(content);

        await _repo.createNote(
          title: title,
          type: isChecklist ? NoteType.checklist : NoteType.text,
          deviceOriginId: 'local',
          deltaContent: deltaJson,
          plainText: plain.isNotEmpty ? plain : content.trim(),
        );
        imported++;
      } catch (e) {
        errors.add('Error reading ${file.path}: $e');
        nookLog(
          NookLogKey.database,
          'PlainTextImporter file error: $e',
          LogLevel.error,
        );
      }
    }

    return ImportSummary(
      notesImported: imported,
      filesProcessed: files.length,
      errors: errors,
    );
  }

  String _deriveTitle(String content) {
    final firstLine = content.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => 'Untitled',
        );
    final cleaned = firstLine.trim();
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }
}
