import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../../../data/repositories/attachment_repository.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/tables/attachments.dart';
import '../../../data/tables/notes.dart';
import '../../../core/providers/talker_provider.dart';

/// Builds a `.nook` backup bundle: a zip with a manifest, one folder per note
/// containing human-readable `note.md` and lossless `note.json`, plus raw
/// attachment binaries so the archive stays openable even by tools that ignore
/// the JSON — "no lock-in, made real".
///
/// The archive also carries `notebooks.json` (so `notes.notebook_id` foreign
/// keys always resolve on a fresh device) and, per attachment, the original
/// `filePath`/`thumbnailPath` plus base64 thumbnail bytes. An import uses those
/// to re-write image urls and doodle thumbnails inside `deltaContent`, so
/// restored media actually renders on the target device.
class NookExporter {
  NookExporter({
    required NoteRepository noteRepository,
    required ChecklistItemRepository checklistItemRepository,
    required AttachmentRepository attachmentRepository,
    required NotebookRepository notebookRepository,
    Directory? outputDirectory,
    DateTime Function()? clock,
    String? deviceOriginId,
  })  : _noteRepository = noteRepository,
        _checklistItemRepository = checklistItemRepository,
        _attachmentRepository = attachmentRepository,
        _notebookRepository = notebookRepository,
        _outputDirectory = outputDirectory,
        _clock = clock ?? DateTime.now,
        _deviceOriginId = deviceOriginId ?? const Uuid().v4();

  static const int formatVersion = 1;

  final NoteRepository _noteRepository;
  final ChecklistItemRepository _checklistItemRepository;
  final AttachmentRepository _attachmentRepository;
  final NotebookRepository _notebookRepository;
  final Directory? _outputDirectory;
  final DateTime Function() _clock;
  final String _deviceOriginId;

  /// Exports every non-deleted note (plus checklists and attachments) into a
  /// `.nook` zip in the app's temporary directory, returning the file path.
  Future<String> exportAll() async {
    final exportedAt = _clock();
    final notes = await _noteRepository.getAllNotes();
    nookLog(
      NookLogKey.database,
      'Export started: ${notes.length} note(s) at '
      '${exportedAt.toIso8601String()}',
      LogLevel.info,
    );

    final archive = Archive();
    var totalAttachments = 0;
    var totalThumbnails = 0;
    for (final note in notes) {
      final items = await _checklistItemRepository.getItems(note.id);

      final attachmentBytes = <Attachment, Uint8List?>{};
      final attachmentThumbBytes = <Attachment, Uint8List?>{};
      final attachments = await _attachmentRepository.getAllForNote(note.id);
      for (final attachment in attachments) {
        attachmentBytes[attachment] = await _readAttachmentBytes(attachment);
        attachmentThumbBytes[attachment] =
            await _readThumbnailBytes(attachment);
      }

      final noteDir = 'notes/${note.id}';
      archive.addFile(ArchiveFile.string(
        '$noteDir/note.md',
        _renderMarkdown(note, items, attachmentBytes),
      ));
      archive.addFile(ArchiveFile.string(
        '$noteDir/note.json',
        jsonEncode(_buildNoteJson(
            note, items, attachmentBytes, attachmentThumbBytes, exportedAt)),
      ));

      var noteAttachments = 0;
      for (final attachment in attachments) {
        final bytes = attachmentBytes[attachment];
        if (bytes == null) {
          nookLog(
            NookLogKey.database,
            'Attachment ${attachment.id} missing on disk during export: '
            '${attachment.filePath}',
            LogLevel.warning,
          );
          continue;
        }
        final fileName = '${attachment.id}.${_fileExtensionFor(attachment)}';
        archive.addFile(ArchiveFile(
          '$noteDir/attachments/$fileName',
          bytes.length,
          bytes,
        ));

        // Bundle thumbnail binaries too: doodle thumbnails are rendered from
        // strokes + theme colors on the source device and cannot be regenerated
        // offline on the target.
        final thumbBytes = attachmentThumbBytes[attachment];
        final thumbPath = attachment.thumbnailPath;
        if (thumbBytes != null && thumbPath != null && thumbPath.isNotEmpty) {
          archive.addFile(ArchiveFile(
            '$noteDir/attachments/${p.basename(thumbPath)}',
            thumbBytes.length,
            thumbBytes,
          ));
          totalThumbnails++;
        }
        noteAttachments++;
      }
      totalAttachments += noteAttachments;
      nookLog(
        NookLogKey.database,
        'Exported note ${note.id} "${note.title}": '
        '${items.length} checklist item(s), $noteAttachments attachment(s)',
        LogLevel.debug,
      );
    }

    archive.addFile(ArchiveFile.string(
      'manifest.json',
      jsonEncode({
        'formatVersion': formatVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'deviceOriginId': _deviceOriginId,
        'noteCount': notes.length,
      }),
    ));

    // Notebooks travel with the vault so an import never hits a missing
    // `notes.notebook_id` foreign key on a fresh device.
    final notebooks = await _notebookRepository.getAllNotebooks();
    archive.addFile(ArchiveFile.string(
      'notebooks.json',
      jsonEncode([
        for (final notebook in notebooks)
          {
            'id': notebook.id,
            'name': notebook.name,
            'colorSeed': notebook.colorSeed,
            'icon': notebook.icon,
            'sortOrder': notebook.sortOrder,
          },
      ]),
    ));
    nookLog(
      NookLogKey.database,
      'Export bundled ${notebooks.length} notebook(s) into vault',
      LogLevel.debug,
    );

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('Could not compress vault');
    }

    final targetDir = _outputDirectory ?? await getTemporaryDirectory();
    await targetDir.create(recursive: true);
    final file = File(
      p.join(targetDir.path, 'nook-export-${_timestamp(exportedAt)}.nook'),
    );
    await file.writeAsBytes(zipBytes, flush: true);
    nookLog(
      NookLogKey.database,
      'Export complete: ${notes.length} note(s), '
      '$totalAttachments attachment(s), $totalThumbnails thumbnail(s) -> '
      '${file.path} (${zipBytes.length} bytes)',
      LogLevel.info,
    );
    return file.path;
  }

  /// Lossless JSON: every note field, checklist items, and attachments
  /// (id / type / sortOrder / base64 bytes) so an import can rebuild the row
  /// exactly as it was exporting-device-side.
  Map<String, dynamic> _buildNoteJson(
    Note note,
    List<ChecklistItem> items,
    Map<Attachment, Uint8List?> attachmentBytes,
    Map<Attachment, Uint8List?> attachmentThumbBytes,
    DateTime exportedAt,
  ) {
    return {
      'noteId': note.id,
      'syncVersion': note.syncVersion,
      'createdAt': note.createdAt.millisecondsSinceEpoch,
      'updatedAt': note.updatedAt.millisecondsSinceEpoch,
      'deviceOriginId': note.deviceOriginId,
      'noteFields': {
        'title': note.title,
        'type': note.type.name,
        'colorSeed': note.colorSeed,
        'pinned': note.pinned,
        'locked': note.locked,
        'notebookId': note.notebookId,
        'coverImagePath': note.coverImagePath,
        'deltaContent': note.deltaContent,
        'plainText': note.plainText,
      },
      'checklistItems': [
        for (final item in items)
          {
            'id': item.id,
            'itemText': item.itemText,
            'checked': item.checked,
            'sortOrder': item.sortOrder,
          },
      ],
      'attachments': [
        for (final attachment in attachmentBytes.keys)
          {
            'id': attachment.id,
            'type': attachment.type.name,
            'sortOrder': attachment.sortOrder,
            'fileName': '${attachment.id}.${_fileExtensionFor(attachment)}',
            // Original absolute paths so an import can re-map the delta's
            // image urls / doodle thumbnail paths to the restored files.
            'filePath': attachment.filePath,
            'thumbnailPath': attachment.thumbnailPath,
            'bytes': base64Encode(attachmentBytes[attachment] ?? Uint8List(0)),
            'thumbnailBytes':
                base64Encode(attachmentThumbBytes[attachment] ?? Uint8List(0)),
          },
      ],
      'exportedAt': exportedAt.toIso8601String(),
    };
  }

  /// Human-readable markdown: title, plain text, `- [ ]` checklist lines, and
  /// relative image/doodle references.
  String _renderMarkdown(
    Note note,
    List<ChecklistItem> items,
    Map<Attachment, Uint8List?> attachmentBytes,
  ) {
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

    for (final entry in attachmentBytes.entries) {
      if (entry.value == null) continue;
      final fileName = '${entry.key.id}.${_fileExtensionFor(entry.key)}';
      if (entry.key.type == AttachmentType.doodleLayer) {
        buffer.writeln('[doodle: ${entry.key.id}]'
            '(attachments/$fileName)');
      } else {
        buffer.writeln('![image]'
            '(attachments/$fileName)');
      }
    }

    return buffer.toString();
  }

  Future<Uint8List?> _readAttachmentBytes(Attachment attachment) async {
    final file = File(attachment.filePath);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<Uint8List?> _readThumbnailBytes(Attachment attachment) async {
    final path = attachment.thumbnailPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Extension used for the raw attachment file in the archive and in the
  /// JSON `fileName`. Doodles keep the `.drawn` marker; images keep their real
  /// extension so the archive stays directly openable.
  static String _fileExtensionFor(Attachment attachment) {
    if (attachment.type == AttachmentType.doodleLayer) return 'drawn';
    if (attachment.filePath.isNotEmpty) {
      final ext = p.extension(attachment.filePath);
      if (ext.isNotEmpty) return ext.substring(1);
    }
    return 'img';
  }

  static String _timestamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}'
        '${two(time.month)}'
        '${two(time.day)}'
        '-'
        '${two(time.hour)}'
        '${two(time.minute)}'
        '${two(time.second)}';
  }
}
