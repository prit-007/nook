import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/talker_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/attachment_repository.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/tables/attachments.dart';
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

/// Attachment bytes loaded for export (file + optional doodle thumbnail).
class ExportAttachment {
  const ExportAttachment({
    required this.attachment,
    required this.bytes,
    this.thumbnailBytes,
  });

  final Attachment attachment;
  final Uint8List bytes;
  final Uint8List? thumbnailBytes;

  String get fileExtension {
    if (attachment.type == AttachmentType.doodleLayer) return 'png';
    if (attachment.filePath.isNotEmpty) {
      final ext = p.extension(attachment.filePath);
      if (ext.isNotEmpty) return ext.substring(1);
    }
    return 'bin';
  }

  String get archiveName => '${attachment.id}.$fileExtension';
}

String _escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

String _base64DataUri(Uint8List bytes, String mime) =>
    'data:$mime;base64,${base64Encode(bytes)}';

String _mimeForExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    default:
      return 'application/octet-stream';
  }
}

/// Renders a note as human-readable Markdown.
///
/// [attachmentRefs] maps attachment id → path used inside the markdown
/// (relative to the note file, e.g. `attachments/<file>`).
String renderNoteMarkdown(
  Note note,
  List<ChecklistItem> items, {
  Map<String, String> attachmentRefs = const {},
  List<ExportAttachment> attachments = const [],
}) {
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
  if (attachments.isNotEmpty) {
    buffer.writeln('Attachments:');
    for (final att in attachments) {
      final ref = attachmentRefs[att.attachment.id];
      if (ref == null) continue;
      if (att.attachment.type == AttachmentType.doodleLayer) {
        buffer.writeln('- [doodle: ${att.attachment.id}]($ref)');
      } else {
        buffer.writeln('- ![image]($ref)');
      }
    }
    buffer.writeln();
  }
  return buffer.toString();
}

/// Renders a standalone read-only HTML page.
///
/// When [embedAttachments] is true, image/doodle bytes are inlined as
/// `data:` URIs so the single file is portable (share-as-HTML).
/// When false, [attachmentRefs] provides relative `src` paths (bulk zip).
String renderNoteHtml(
  Note note,
  List<ChecklistItem> items, {
  Map<String, String> attachmentRefs = const {},
  List<ExportAttachment> attachments = const [],
  bool embedAttachments = false,
}) {
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
  for (final att in attachments) {
    final label =
        att.attachment.type == AttachmentType.doodleLayer ? 'Doodle' : 'Image';
    String? src;
    if (embedAttachments) {
      // Prefer thumbnail for doodles (stroke JSON is not displayable);
      // fall back to full file for images.
      final bytes = att.attachment.type == AttachmentType.doodleLayer
          ? att.thumbnailBytes
          : att.bytes;
      if (bytes != null) {
        final ext = att.attachment.type == AttachmentType.doodleLayer
            ? 'png'
            : att.fileExtension;
        src = _base64DataUri(bytes, _mimeForExtension(ext));
      }
    } else {
      src = attachmentRefs[att.attachment.id];
    }
    if (src == null) continue;
    body.writeln(
      '<figure class="attachment">'
      '<img src="$src" alt="${_escapeHtml(label)}" '
      'style="max-width:100%;height:auto;border-radius:12px">'
      '<figcaption>${_escapeHtml(label)}</figcaption>'
      '</figure>',
    );
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
    .attachment { margin: 1.25rem 0; }
    .attachment figcaption { opacity: 0.65; font-size: 0.8rem; margin-top: 0.35rem; }
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

/// Exports non-deleted notes as a zip of Markdown or HTML **including**
/// image/doodle attachment binaries under `notes/<note>/attachments/`.
class BulkExporter {
  BulkExporter({
    required NoteRepository noteRepository,
    required ChecklistItemRepository checklistItemRepository,
    required AttachmentRepository attachmentRepository,
    Directory? outputDirectory,
    DateTime Function()? clock,
  })  : _noteRepository = noteRepository,
        _checklistItemRepository = checklistItemRepository,
        _attachmentRepository = attachmentRepository,
        _outputDirectory = outputDirectory,
        _clock = clock ?? DateTime.now;

  final NoteRepository _noteRepository;
  final ChecklistItemRepository _checklistItemRepository;
  final AttachmentRepository _attachmentRepository;
  final Directory? _outputDirectory;
  final DateTime Function() _clock;

  Future<List<ExportAttachment>> _loadAttachments(String noteId) async {
    final attachments = await _attachmentRepository.getAllForNote(noteId);
    final result = <ExportAttachment>[];
    for (final attachment in attachments) {
      final file = File(attachment.filePath);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      Uint8List? thumbBytes;
      final thumbPath = attachment.thumbnailPath;
      if (attachment.type == AttachmentType.doodleLayer &&
          thumbPath != null &&
          thumbPath.isNotEmpty) {
        final thumbFile = File(thumbPath);
        if (thumbFile.existsSync()) {
          thumbBytes = await thumbFile.readAsBytes();
        }
      }
      result.add(ExportAttachment(
        attachment: attachment,
        bytes: bytes,
        thumbnailBytes: thumbBytes,
      ));
    }
    return result;
  }

  Future<String> exportAll(BulkExportFormat format) async {
    final notes = await _noteRepository.getAllNotes();
    if (notes.isEmpty) {
      throw StateError('No notes to export');
    }

    final archive = Archive();
    final exportedAt = _clock();
    var attachmentCount = 0;
    for (final note in notes) {
      final items = await _checklistItemRepository.getItems(note.id);
      final attachments = await _loadAttachments(note.id);
      attachmentCount += attachments.length;
      final safeName = _safeFileName(note.title.isEmpty ? note.id : note.title);

      // Relative refs from notes/<safeName>.<ext> → notes/<safeName>/attachments/
      final refs = <String, String>{
        for (final att in attachments)
          att.attachment.id: 'attachments/${att.archiveName}',
      };

      final content = format == BulkExportFormat.markdown
          ? renderNoteMarkdown(
              note,
              items,
              attachmentRefs: refs,
              attachments: attachments,
            )
          : renderNoteHtml(
              note,
              items,
              attachmentRefs: refs,
              attachments: attachments,
              embedAttachments: false,
            );
      final ext = format == BulkExportFormat.markdown ? 'md' : 'html';
      archive.addFile(ArchiveFile.string('notes/$safeName.$ext', content));

      for (final att in attachments) {
        // Doodles export their rendered thumbnail (PNG) when available;
        // otherwise skip the unreadable stroke JSON in the portable archive.
        if (att.attachment.type == AttachmentType.doodleLayer) {
          final thumb = att.thumbnailBytes;
          if (thumb == null) continue;
          archive.addFile(ArchiveFile(
            'notes/$safeName/attachments/${att.archiveName}',
            thumb.length,
            thumb,
          ));
        } else {
          archive.addFile(ArchiveFile(
            'notes/$safeName/attachments/${att.archiveName}',
            att.bytes.length,
            att.bytes,
          ));
        }
      }
    }
    archive.addFile(ArchiveFile.string(
      'manifest.json',
      '{'
          '"exportedAt":"${exportedAt.toIso8601String()}",'
          '"format":"${format.name}",'
          '"noteCount":${notes.length},'
          '"attachmentCount":$attachmentCount'
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
      'Bulk ${format.name} export: ${notes.length} note(s), '
      '$attachmentCount attachment(s) → ${file.path}',
      LogLevel.info,
    );
    return file.path;
  }

  /// Single-note standalone HTML with **embedded** image/doodle bytes.
  Future<String> exportNoteHtml(Note note) async {
    final items = await _checklistItemRepository.getItems(note.id);
    final attachments = await _loadAttachments(note.id);
    final html = renderNoteHtml(
      note,
      items,
      attachments: attachments,
      embedAttachments: true,
    );
    final dir = _outputDirectory ?? await getTemporaryDirectory();
    final safeName = _safeFileName(note.title.isEmpty ? note.id : note.title);
    final file = File(p.join(dir.path, '$safeName.html'));
    await file.writeAsString(html, flush: true);
    return file.path;
  }

  /// Test hook: loads exportable attachments for [noteId].
  Future<List<ExportAttachment>> loadAttachmentsForTesting(String noteId) {
    return _loadAttachments(noteId);
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
