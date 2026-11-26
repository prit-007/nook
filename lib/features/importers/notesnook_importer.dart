import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import '../editor/markdown_import.dart';
import 'import_summary.dart';

/// Importer for Notesnook backup formats (JSON or ZIP exports).
class NotesnookImporter {
  NotesnookImporter(this._repo);

  final NoteRepository _repo;

  /// Imports Notesnook JSON backup.
  ///
  /// Can be either `{ "notes": [ ... ] }` or a direct list of note entries.
  Future<ImportSummary> importJson(String jsonStr) async {
    final errors = <String>[];
    var imported = 0;

    try {
      final decoded = jsonDecode(jsonStr);
      List<dynamic> noteItems = [];
      if (decoded is List) {
        noteItems = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['notes'] is List) {
          noteItems = decoded['notes'] as List<dynamic>;
        } else {
          noteItems = [decoded];
        }
      }

      for (final item in noteItems) {
        if (item is Map<String, dynamic>) {
          final ok = await _importNoteItem(item);
          if (ok) imported++;
        }
      }
    } catch (e) {
      errors.add('Notesnook JSON parse error: $e');
      nookLog(
        NookLogKey.database,
        'NotesnookImporter JSON error: $e',
        LogLevel.error,
      );
    }

    return ImportSummary(
      notesImported: imported,
      filesProcessed: 1,
      errors: errors,
    );
  }

  /// Imports a list of Notesnook JSON or markdown export files.
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
        if (file.path.toLowerCase().endsWith('.json')) {
          final summary = await importJson(content);
          imported += summary.notesImported;
          errors.addAll(summary.errors);
        } else {
          // Markdown / text fallback
          final ok = await _importMarkdownNote(content, file.path);
          if (ok) imported++;
        }
      } catch (e) {
        errors.add('Error reading ${file.path}: $e');
      }
    }

    return ImportSummary(
      notesImported: imported,
      filesProcessed: files.length,
      errors: errors,
    );
  }

  /// Imports a Notesnook `.zip` archive.
  Future<ImportSummary> importZip(List<int> zipBytes) async {
    var imported = 0;
    var filesProcessed = 0;
    final errors = <String>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        filesProcessed++;
        try {
          final content = utf8.decode(file.content as List<int>);
          if (file.name.toLowerCase().endsWith('.json')) {
            final summary = await importJson(content);
            imported += summary.notesImported;
            errors.addAll(summary.errors);
          } else if (file.name.toLowerCase().endsWith('.md') ||
              file.name.toLowerCase().endsWith('.txt')) {
            final ok = await _importMarkdownNote(content, file.name);
            if (ok) imported++;
          }
        } catch (e) {
          errors.add('Error in ${file.name}: $e');
        }
      }
    } catch (e) {
      errors.add('Failed to decode zip: $e');
    }

    return ImportSummary(
      notesImported: imported,
      filesProcessed: filesProcessed,
      errors: errors,
    );
  }

  Future<bool> _importNoteItem(Map<String, dynamic> item) async {
    final rawTitle =
        (item['title'] ?? item['headline'] ?? item['topic']) as String?;
    final rawContent =
        (item['content'] ?? item['body'] ?? item['text']) as String? ?? '';
    final isPinned = item['pinned'] == true || item['favorite'] == true;

    DateTime? createdAt;
    final createdRaw = item['createdAt'] ?? item['created_at'];
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    } else if (createdRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdRaw);
    }

    if (rawContent.trim().isEmpty &&
        (rawTitle == null || rawTitle.trim().isEmpty)) {
      return false;
    }

    final isChecklist =
        RegExp(r'^\s*- \[[ xX]\]', multiLine: true).hasMatch(rawContent);
    final deltaJson = markdownToAppFlowyJson(rawContent);
    final plain = extractPlainTextFromAppFlowyJson(deltaJson);

    final title = (rawTitle != null && rawTitle.trim().isNotEmpty)
        ? rawTitle.trim()
        : (plain.isNotEmpty ? plain.split('\n').first.trim() : 'Untitled');

    await _repo.createNote(
      title: title.length > 80 ? title.substring(0, 80) : title,
      type: isChecklist ? NoteType.checklist : NoteType.text,
      pinned: isPinned,
      deviceOriginId: 'local',
      deltaContent: deltaJson,
      plainText: plain.isNotEmpty ? plain : rawContent,
      createdAt: createdAt,
    );

    return true;
  }

  Future<bool> _importMarkdownNote(String content, String path) async {
    if (content.trim().isEmpty) return false;
    final deltaJson = markdownToAppFlowyJson(content);
    final plain = extractPlainTextFromAppFlowyJson(deltaJson);
    final isChecklist =
        RegExp(r'^\s*- \[[ xX]\]', multiLine: true).hasMatch(content);

    final title =
        plain.isNotEmpty ? plain.split('\n').first.trim() : 'Untitled';

    await _repo.createNote(
      title: title.length > 80 ? title.substring(0, 80) : title,
      type: isChecklist ? NoteType.checklist : NoteType.text,
      deviceOriginId: 'local',
      deltaContent: deltaJson,
      plainText: plain.isNotEmpty ? plain : content,
    );
    return true;
  }
}
