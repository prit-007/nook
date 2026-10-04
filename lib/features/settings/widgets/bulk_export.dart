import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/talker_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/tables/notes.dart';

/// Result of a bulk export run.
class BulkExportResult {
  const BulkExportResult({
    required this.path,
    required this.noteCount,
    required this.format,
  });

  final String path;
  final int noteCount;
  final BulkExportFormat format;
}

enum BulkExportFormat { markdown, html }

/// Renders a note as human-readable Markdown (shared by vault + bulk export).
String renderNoteMarkdown(Note note, List<ChecklistItem> items) {
  final buffer = StringBuffer();
  if (note.title.isNotEmpty) {
    buffer.writeln('# ${note.title}');
    buffer.writeln();
  }
  final plainText = note.type == NoteType.checklist ? null : note.plainText;
  if (plainText != null && plainText.trim().isNotEmpty) {
    buffer.writeln(plainText.trim());
    buffer.writeln();
  }
  if (items.isNotEmpty) {
    buffer.writeln('Checklist:');
    for (final item in items) {
      buffer.writeln('- [${item.checked ? 'x' : ' '}] ${item.itemText}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

String _escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Renders a standalone read-only HTML page for a note (bulk + single share).
String renderNoteHtml(Note note, List<ChecklistItem> items) {
  final title = note.title.isEmpty ? 'Untitled' : note.title;
  final plainText = note.type == NoteType.checklist ? null : note.plainText;
  final body = StringBuffer();
  if (plainText != null && plainText.trim().isNotEmpty) {
    body.writeln(
        '<p>${_escapeHtml(plainText.trim()).replaceAll('\n', '<br>')}</p>');
  }
  if (items.isNotEmpty) {
    body.writeln('<ul class="checklist">');
    for (final item in items) {
      final box = item.checked ? '☑' : '☐';
      body.writeln(
        '<li>$box ${_escapeHtml(item.itemText)}</li>',
      );
    }
    body.writeln('</ul>');
  }
  if (body.isEmpty) {
    body.writeln('<p><em>Empty note</em></p>');
  }
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_escapeHtml(title)}</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
      line-height: 1.55;
      max-width: 42rem;
      margin: 2rem auto;
      padding: 0 1.25rem;
    }
    h1 { font-size: 1.75rem; letter-spacing: -0.02em; margin-bottom: 0.25rem; }
    .meta { opacity: 0.65; font-size: 0.875rem; margin-bottom: 1.5rem; }
    .checklist { list-style: none; padding-left: 0; }
    .checklist li { padding: 0.2rem 0; }
    footer { margin-top: 2.5rem; opacity: 0.5; font-size: 0.8rem; }
  </style>
</head>
<body>
  <h1>${_escapeHtml(title)}</h1>
  <div class="meta">Exported from Nook · local-first notes</div>
  $body
  <footer>Your notes. Your device. Yours.</footer>
</body>
</html>
''';
}

/// Exports all non-deleted notes as a zip of Markdown or standalone HTML.
class BulkExporter {
  BulkExporter({
    required NoteRepository noteRepository,
    required ChecklistItemRepository checklistItemRepository,
    Directory? outputDirectory,
    DateTime Function()? clock,
  })  : _noteRepository = noteRepository,
        _checklistItemRepository = checklistItemRepository,
        _outputDirectory = outputDirectory,
        _clock = clock ?? DateTime.now;

  final NoteRepository _noteRepository;
  final ChecklistItemRepository _checklistItemRepository;
  final Directory? _outputDirectory;
  final DateTime Function() _clock;

  Future<String> exportAll(BulkExportFormat format) async {
    final notes = await _noteRepository.getAllNotes();
    if (notes.isEmpty) {
      throw StateError('No notes to export');
    }

    final archive = Archive();
    final exportedAt = _clock();
    for (final note in notes) {
      final items = await _checklistItemRepository.getItems(note.id);
      final safeName = _safeFileName(note.title.isEmpty ? note.id : note.title);
      final content = format == BulkExportFormat.markdown
          ? renderNoteMarkdown(note, items)
          : renderNoteHtml(note, items);
      final ext = format == BulkExportFormat.markdown ? 'md' : 'html';
      archive.addFile(ArchiveFile.string('notes/$safeName.$ext', content));
    }
    archive.addFile(ArchiveFile.string(
      'manifest.json',
      '{'
          '"exportedAt":"${exportedAt.toIso8601String()}",'
          '"format":"${format.name}",'
          '"noteCount":${notes.length}'
          '}',
    ));

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw StateError('Failed to encode export archive');
    }

    final dir = _outputDirectory ?? await getTemporaryDirectory();
    final stamp = _timestamp(exportedAt);
    final fileName = 'nook-export-${format.name}-$stamp.zip';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    nookLog(
      NookLogKey.database,
      'Bulk ${format.name} export: ${notes.length} note(s) → ${file.path}',
      LogLevel.info,
    );
    return file.path;
  }

  /// Single-note standalone HTML (used by note share).
  Future<String> exportNoteHtml(Note note) async {
    final items = await _checklistItemRepository.getItems(note.id);
    final dir = _outputDirectory ?? await getTemporaryDirectory();
    final safeName = _safeFileName(note.title.isEmpty ? note.id : note.title);
    final file = File(p.join(dir.path, '$safeName.html'));
    await file.writeAsString(renderNoteHtml(note, items), flush: true);
    return file.path;
  }

  static String _safeFileName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'note';
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }

  static String _timestamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '-${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}
