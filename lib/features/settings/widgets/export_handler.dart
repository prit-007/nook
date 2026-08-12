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
import '../../../data/repositories/note_repository.dart';
import '../../../data/tables/attachments.dart';
import '../../../data/tables/notes.dart';

/// Builds a `.nook` backup bundle: a zip with a manifest, one folder per note
/// containing human-readable `note.md` and lossless `note.json`, plus raw
/// attachment binaries so the archive stays openable even by tools that ignore
/// the JSON — "no lock-in, made real".
class NookExporter {
  NookExporter({
    required NoteRepository noteRepository,
    required ChecklistItemRepository checklistItemRepository,
    required AttachmentRepository attachmentRepository,
    Directory? outputDirectory,
    DateTime Function()? clock,
    String? deviceOriginId,
  })  : _noteRepository = noteRepository,
        _checklistItemRepository = checklistItemRepository,
        _attachmentRepository = attachmentRepository,
        _outputDirectory = outputDirectory,
        _clock = clock ?? DateTime.now,
        _deviceOriginId = deviceOriginId ?? const Uuid().v4();

  static const int formatVersion = 1;

  final NoteRepository _noteRepository;
  final ChecklistItemRepository _checklistItemRepository;
  final AttachmentRepository _attachmentRepository;
  final Directory? _outputDirectory;
  final DateTime Function() _clock;
  final String _deviceOriginId;

  /// Exports every non-deleted note (plus checklists and attachments) into a
  /// `.nook` zip in the app's temporary directory, returning the file path.
  Future<String> exportAll() async {
    final exportedAt = _clock();
    final notes = await _noteRepository.getAllNotes();

    final archive = Archive();
    for (final note in notes) {
      final items = await _checklistItemRepository.getItems(note.id);

      final attachmentBytes = <Attachment, Uint8List?>{};
      final attachments = await _attachmentRepository.getAllForNote(note.id);
      for (final attachment in attachments) {
        attachmentBytes[attachment] = await _readAttachmentBytes(attachment);
      }

      final noteDir = 'notes/${note.id}';
      archive.addFile(ArchiveFile.string(
        '$noteDir/note.md',
        _renderMarkdown(note, items, attachmentBytes),
      ));
      archive.addFile(ArchiveFile.string(
        '$noteDir/note.json',
        jsonEncode(_buildNoteJson(note, items, attachmentBytes, exportedAt)),
      ));

      for (final attachment in attachments) {
        final bytes = attachmentBytes[attachment];
        if (bytes == null) continue;
        final fileName = '${attachment.id}.${_extensionFor(attachment.type)}';
        archive.addFile(ArchiveFile(
          '$noteDir/attachments/$fileName',
          bytes.length,
          bytes,
        ));
      }
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
    return file.path;
  }

  /// Lossless JSON: every note field, checklist items, and attachments
  /// (id / type / sortOrder / base64 bytes) so an import can rebuild the row
  /// exactly as it was exporting-device-side.
  Map<String, dynamic> _buildNoteJson(
    Note note,
    List<ChecklistItem> items,
    Map<Attachment, Uint8List?> attachmentBytes,
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
            'fileName': '${attachment.id}.${_extensionFor(attachment.type)}',
            'bytes': base64Encode(attachmentBytes[attachment] ?? Uint8List(0)),
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
      final fileName = '${entry.key.id}.${_extensionFor(entry.key.type)}';
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

  static String _extensionFor(AttachmentType type) =>
      type == AttachmentType.doodleLayer ? 'drawn' : 'img';

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
