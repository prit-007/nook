import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';

/// Result of a markdown import run.
class MarkdownImportResult {
  const MarkdownImportResult({
    this.notesImported = 0,
    this.filesRead = 0,
    this.error,
  });

  final int notesImported;
  final int filesRead;
  final String? error;

  bool get isSuccessful => error == null;
}

/// Heuristic: does [text] look like markdown worth converting?
bool looksLikeMarkdown(String text) {
  final t = text.trimLeft();
  if (t.isEmpty) return false;
  if (t.startsWith('#')) return true;
  if (RegExp(r'^[-*+]\s+', multiLine: true).hasMatch(text)) return true;
  if (RegExp(r'^\d+\.\s+', multiLine: true).hasMatch(text)) return true;
  if (text.contains('```')) return true;
  if (text.contains('**') || text.contains('__')) return true;
  if (RegExp(r'^>\s+', multiLine: true).hasMatch(text)) return true;
  if (RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(text)) return true;
  return false;
}

/// Converts markdown to an AppFlowy document JSON string.
///
/// Uses AppFlowy's built-in [markdownToDocument] codec (headings, todos,
/// lists, quotes, tables, images, inline styles).
String markdownToAppFlowyJson(String markdown) {
  final document = markdownToDocument(markdown);
  return jsonEncode(document.toJson());
}

/// Extracts plainText from AppFlowy document JSON (for FTS + note title).
String extractPlainTextFromAppFlowyJson(String? deltaJson) {
  if (deltaJson == null || deltaJson.isEmpty) return '';
  final Object? decoded;
  try {
    decoded = jsonDecode(deltaJson);
  } catch (_) {
    return '';
  }
  final buffer = StringBuffer();
  void walk(Object? node) {
    if (node is Map) {
      if (node['insert'] is String) {
        buffer.write(node['insert'] as String);
      } else if (node['type'] is String) {
        // Block boundary
        buffer.write('\n');
      }
      for (final value in node.values) {
        walk(value);
      }
    } else if (node is List) {
      for (final value in node) {
        walk(value);
      }
    }
  }

  walk(decoded);
  return buffer.toString().trim();
}

/// Imports markdown text as a new note.
///
/// Title: first non-empty heading line if present, else first non-empty line
/// truncated, else "Untitled".
Future<Note> importMarkdownAsNote(
  NoteRepository repo,
  String markdown, {
  String? titleOverride,
}) async {
  final deltaJson = markdownToAppFlowyJson(markdown);
  final plain = extractPlainTextFromAppFlowyJson(deltaJson);
  final title = titleOverride?.trim().isNotEmpty == true
      ? titleOverride!.trim()
      : _deriveTitle(markdown, plain);

  final isChecklist =
      RegExp(r'^\s*- \[[ xX]\]', multiLine: true).hasMatch(markdown);
  final type = isChecklist ? NoteType.checklist : NoteType.text;

  return repo.createNote(
    title: title,
    type: type,
    deviceOriginId: 'local',
    deltaContent: deltaJson,
    plainText: plain,
  );
}

String _deriveTitle(String markdown, String plain) {
  final heading = RegExp(r'^#{1,6}\s+(.+)$', multiLine: true)
      .firstMatch(markdown)
      ?.group(1)
      ?.trim();
  if (heading != null && heading.isNotEmpty) return heading;
  final firstLine = plain.split('\n').firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => '',
      );
  if (firstLine.trim().isEmpty) return 'Untitled';
  final cleaned = firstLine.trim();
  return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
}

/// Imports one or more `.md` files into notes.
class MarkdownImporter {
  MarkdownImporter(this._repo);

  final NoteRepository _repo;

  Future<MarkdownImportResult> importFiles(List<File> files) async {
    var imported = 0;
    try {
      for (final file in files) {
        final markdown = await file.readAsString();
        final baseTitle = file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
                .replaceAll(RegExp(r'\.md$', caseSensitive: false), '')
            : null;
        await importMarkdownAsNote(
          _repo,
          markdown,
          titleOverride:
              (baseTitle == null || baseTitle.isEmpty) ? null : baseTitle,
        );
        imported++;
      }
      nookLog(
        NookLogKey.database,
        'Markdown import: $imported note(s) from ${files.length} file(s)',
        LogLevel.info,
      );
      return MarkdownImportResult(
          notesImported: imported, filesRead: files.length);
    } catch (e) {
      nookLog(
          NookLogKey.database, 'Markdown import failed: $e', LogLevel.error);
      return MarkdownImportResult(
        notesImported: imported,
        filesRead: files.length,
        error: '$e',
      );
    }
  }
}
