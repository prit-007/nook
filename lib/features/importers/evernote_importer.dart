import 'dart:io';

import 'package:xml/xml.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import '../editor/markdown_import.dart';
import 'import_summary.dart';

/// Importer for Evernote ENEX (`.enex`) export files.
class EvernoteImporter {
  EvernoteImporter(this._repo);

  final NoteRepository _repo;

  /// Imports notes from an ENEX XML string.
  Future<ImportSummary> importEnex(String enexXml) async {
    final errors = <String>[];
    var imported = 0;

    try {
      final document = XmlDocument.parse(enexXml);
      final noteElements = document.findAllElements('note');

      for (final noteElem in noteElements) {
        try {
          final titleElem = noteElem.findElements('title').firstOrNull;
          final title = titleElem?.innerText.trim() ?? '';

          final contentElem = noteElem.findElements('content').firstOrNull;
          final rawContent = contentElem?.innerText ?? '';
          final markdownContent = _convertEnmlToMarkdown(rawContent);

          final createdElem = noteElem.findElements('created').firstOrNull;
          DateTime? createdAt;
          if (createdElem != null) {
            createdAt = _parseEvernoteDate(createdElem.innerText.trim());
          }

          final isChecklist = RegExp(r'^\s*- \[[ xX]\]', multiLine: true)
              .hasMatch(markdownContent);
          final deltaJson = markdownToAppFlowyJson(markdownContent);
          final plain = extractPlainTextFromAppFlowyJson(deltaJson);

          final noteTitle = title.isNotEmpty
              ? title
              : (plain.isNotEmpty
                  ? plain.split('\n').first.trim()
                  : 'Untitled');

          await _repo.createNote(
            title:
                noteTitle.length > 80 ? noteTitle.substring(0, 80) : noteTitle,
            type: isChecklist ? NoteType.checklist : NoteType.text,
            deviceOriginId: 'local',
            deltaContent: deltaJson,
            plainText: plain.isNotEmpty ? plain : markdownContent,
            createdAt: createdAt,
          );
          imported++;
        } catch (e) {
          errors.add('Failed to parse Evernote note: $e');
        }
      }
    } catch (e) {
      errors.add('Invalid ENEX XML: $e');
      nookLog(
        NookLogKey.database,
        'EvernoteImporter XML error: $e',
        LogLevel.error,
      );
    }

    return ImportSummary(
      notesImported: imported,
      filesProcessed: 1,
      errors: errors,
    );
  }

  /// Imports one or more `.enex` files.
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
        final summary = await importEnex(content);
        imported += summary.notesImported;
        errors.addAll(summary.errors);
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

  /// Converts Evernote ENML (`<en-note>...`) to clean markdown.
  String _convertEnmlToMarkdown(String enml) {
    if (enml.trim().isEmpty) return '';

    // Convert checkboxes first
    var text = enml
        .replaceAll(
          RegExp(r'<en-todo\s+checked="true"\s*(/|>\s*</en-todo>)',
              caseSensitive: false),
          '- [x] ',
        )
        .replaceAll(
          RegExp(r'<en-todo(\s+checked="false")?\s*(/|>\s*</en-todo>)',
              caseSensitive: false),
          '- [ ] ',
        );

    // Convert block elements to newlines
    text = text
        .replaceAll(
            RegExp(r'<(div|p|h[1-6]|li)[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(div|p|h[1-6]|li)>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Convert formatting using replaceAllMapped
    text = text.replaceAllMapped(
      RegExp(r'<(?:b|strong)[^>]*>(.*?)</(?:b|strong)>',
          caseSensitive: false, dotAll: true),
      (m) => '**${m[1]}**',
    );
    text = text.replaceAllMapped(
      RegExp(r'<(?:i|em)[^>]*>(.*?)</(?:i|em)>',
          caseSensitive: false, dotAll: true),
      (m) => '*${m[1]}*',
    );

    // Strip any remaining XML/HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Unescape XML entities
    text = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');

    // Trim leading/trailing whitespace per line so indentation isn't treated as a code block
    text = text.split('\n').map((l) => l.trim()).join('\n');

    // Normalize multiple blank lines to double newline
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  /// Parses Evernote timestamps like `20230501T143000Z`.
  DateTime? _parseEvernoteDate(String str) {
    try {
      if (str.length >= 15 && str.contains('T')) {
        final year = int.parse(str.substring(0, 4));
        final month = int.parse(str.substring(4, 6));
        final day = int.parse(str.substring(6, 8));
        final hour = int.parse(str.substring(9, 11));
        final min = int.parse(str.substring(11, 13));
        final sec = int.parse(str.substring(13, 15));
        return DateTime.utc(year, month, day, hour, min, sec);
      }
      return DateTime.tryParse(str);
    } catch (_) {
      return null;
    }
  }
}
