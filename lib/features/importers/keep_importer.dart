import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import '../editor/markdown_import.dart';
import 'import_summary.dart';

/// Importer for Google Keep exports (Google Takeout JSON files or zip).
class KeepImporter {
  KeepImporter(this._repo);

  final NoteRepository _repo;

  /// Imports a single Google Keep JSON string or array of note objects.
  Future<ImportSummary> importJson(
    String jsonStr, {
    bool includeTrashed = false,
  }) async {
    final errors = <String>[];
    var imported = 0;

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final ok =
                await _importKeepMap(item, includeTrashed: includeTrashed);
            if (ok) imported++;
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        final ok =
            await _importKeepMap(decoded, includeTrashed: includeTrashed);
        if (ok) imported++;
      }
    } catch (e) {
      errors.add('JSON parsing error: $e');
      nookLog(
          NookLogKey.database, 'KeepImporter JSON error: $e', LogLevel.error);
    }

    return ImportSummary(
      notesImported: imported,
      filesProcessed: 1,
      errors: errors,
    );
  }

  /// Imports a list of Google Keep JSON files.
  Future<ImportSummary> importFiles(
    List<File> files, {
    bool includeTrashed = false,
  }) async {
    var imported = 0;
    final errors = <String>[];

    for (final file in files) {
      try {
        if (!await file.exists()) {
          errors.add('File not found: ${file.path}');
          continue;
        }
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          final ok =
              await _importKeepMap(decoded, includeTrashed: includeTrashed);
          if (ok) imported++;
        }
      } catch (e) {
        errors.add('Error reading ${file.path}: $e');
        nookLog(
          NookLogKey.database,
          'KeepImporter file error: $e',
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

  /// Imports from Google Takeout `.zip` archive.
  Future<ImportSummary> importZip(
    List<int> zipBytes, {
    bool includeTrashed = false,
  }) async {
    var imported = 0;
    var filesProcessed = 0;
    final errors = <String>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final archiveFile in archive.files) {
        if (!archiveFile.isFile) continue;
        if (!archiveFile.name.toLowerCase().endsWith('.json')) continue;

        filesProcessed++;
        try {
          final content = utf8.decode(archiveFile.content as List<int>);
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            final ok =
                await _importKeepMap(decoded, includeTrashed: includeTrashed);
            if (ok) imported++;
          }
        } catch (e) {
          errors.add('Error parsing ${archiveFile.name}: $e');
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

  Future<bool> _importKeepMap(
    Map<String, dynamic> map, {
    required bool includeTrashed,
  }) async {
    final isTrashed = map['isTrashed'] == true;
    if (isTrashed && !includeTrashed) return false;

    final rawTitle = (map['title'] as String?)?.trim() ?? '';
    final textContent = (map['textContent'] as String?)?.trim() ?? '';
    final listContent = map['listContent'] as List<dynamic>?;
    final isPinned = map['isPinned'] == true;

    // Determine created/updated time
    DateTime? createdAt;
    final userEditedUsec = map['userEditedTimestampUsec'];
    final createdUsec = map['createdTimestampUsec'];
    if (userEditedUsec is int) {
      createdAt = DateTime.fromMicrosecondsSinceEpoch(userEditedUsec);
    } else if (createdUsec is int) {
      createdAt = DateTime.fromMicrosecondsSinceEpoch(createdUsec);
    }

    String markdownBody = '';
    NoteType noteType = NoteType.text;

    if (listContent != null && listContent.isNotEmpty) {
      noteType = NoteType.checklist;
      final buffer = StringBuffer();
      for (final item in listContent) {
        if (item is Map) {
          final text = (item['text'] as String?)?.trim() ?? '';
          final checked = item['isChecked'] == true;
          buffer.writeln(checked ? '- [x] $text' : '- [ ] $text');
        }
      }
      markdownBody = buffer.toString().trim();
    } else {
      markdownBody = textContent;
    }

    if (markdownBody.isEmpty && rawTitle.isEmpty) {
      return false;
    }

    final deltaJson = markdownToAppFlowyJson(markdownBody);
    final plain = extractPlainTextFromAppFlowyJson(deltaJson);

    final title = rawTitle.isNotEmpty
        ? rawTitle
        : (plain.isNotEmpty ? plain.split('\n').first.trim() : 'Untitled');

    await _repo.createNote(
      title: title.length > 80 ? title.substring(0, 80) : title,
      type: noteType,
      pinned: isPinned,
      deviceOriginId: 'local',
      deltaContent: deltaJson,
      plainText: plain.isNotEmpty ? plain : markdownBody,
      createdAt: createdAt,
    );

    return true;
  }
}
