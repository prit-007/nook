import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/tables/attachments.dart';
import '../../../sync/protocol/merge_resolver.dart';
import '../../../sync/protocol/sync_bundle.dart';

/// Result of an import run.
class ImportResult {
  const ImportResult({
    this.notesImported = 0,
    this.duplicateNotes = 0,
    this.attachmentsRestored = 0,
    this.error,
  });

  final int notesImported;

  /// Notes whose original id collided with an existing row and were re-created
  /// under a fresh id instead of overwriting anything.
  final int duplicateNotes;
  final int attachmentsRestored;
  final String? error;

  bool get isSuccessful => error == null;
}

/// Restores a `.nook` backup produced by [NookExporter].
///
/// Uses the same insert semantics as sync's [MergeResolver.insertAsNew]: a
/// note whose id does not exist locally is created with that id; an id
/// collision is given a fresh UUID. Import never clobbers existing notes.
class NookImporter {
  NookImporter({
    required AppDatabase database,
    Directory? restoredAttachmentsDirectory,
  })  : _db = database,
        _restoredAttachmentsDirectory = restoredAttachmentsDirectory;

  static const int supportedFormatVersion = 1;

  final AppDatabase _db;
  final Directory? _restoredAttachmentsDirectory;

  /// Imports every note in the archive, returning a summary.
  Future<ImportResult> importFrom(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return const ImportResult(
          error: 'Not a Nook vault: manifest.json missing',
        );
      }
      final manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;
      if (manifest['formatVersion'] != supportedFormatVersion) {
        return const ImportResult(
          error: 'Unsupported vault format version',
        );
      }

      final noteRepo = NoteRepository(_db);
      final resolver = MergeResolver(noteRepo);

      final noteFiles = archive.files
          .where((f) => RegExp(r'^notes/[^/]+/note\.json$').hasMatch(f.name))
          .toList();

      var imported = 0;
      var duplicates = 0;
      var restoredAttachments = 0;

      for (final entryFile in noteFiles) {
        final noteMap = jsonDecode(utf8.decode(entryFile.content as List<int>))
            as Map<String, dynamic>;
        final entry = _toSyncNoteEntry(noteMap);

        final existed = await noteRepo.getNoteById(entry.noteId) != null;
        await resolver.insertAsNew(entry);
        final finalId = existed ? await _findDuplicateId(entry) : entry.noteId;
        if (existed) duplicates++;

        for (final rawItem in (noteMap['checklistItems'] as List? ?? [])) {
          final item = rawItem as Map<String, dynamic>;
          final originalId = item['id'] as String? ?? '';
          // When the note was re-created under a fresh id, generate a fresh
          // checklist id too — otherwise re-importing an already-imported note
          // would violate the checklist_items primary key.
          final checklistId = existed
              ? const Uuid().v4()
              : (originalId.isEmpty ? const Uuid().v4() : originalId);
          await (_db).into(_db.checklistItems).insert(
                ChecklistItemsCompanion.insert(
                  id: Value(checklistId),
                  noteId: finalId,
                  itemText: item['itemText'] as String? ?? '',
                  checked: Value(item['checked'] as bool? ?? false),
                  sortOrder: Value(item['sortOrder'] as int? ?? 0),
                ),
              );
        }

        for (final rawAttachment in (noteMap['attachments'] as List? ?? [])) {
          final attachment = rawAttachment as Map<String, dynamic>;
          final rawBytes = base64Decode(attachment['bytes'] as String? ?? '');
          if (rawBytes.isEmpty) continue;

          final type = attachment['type'] == 'doodleLayer'
              ? AttachmentType.doodleLayer
              : AttachmentType.image;
          final ext = type == AttachmentType.doodleLayer ? 'drawn' : 'img';
          final baseDir = _restoredAttachmentsDirectory ??
              await getApplicationDocumentsDirectory();
          final restoreDir =
              Directory(p.join(baseDir.path, 'sync', 'attachments'));
          await restoreDir.create(recursive: true);

          final attachmentId = attachment['id'] as String? ?? '';
          final filePath = p.join(
            restoreDir.path,
            '${finalId}_$attachmentId.$ext',
          );
          await File(filePath).writeAsBytes(rawBytes, flush: true);

          final sortOrder = attachment['sortOrder'] as int? ?? 0;
          if (attachmentId.isEmpty || await _attachmentIdExists(attachmentId)) {
            // Preserve the original id/order where possible; fall back to a
            // fresh id (client default) if this id is already taken.
            await _db.into(_db.attachments).insert(
                  AttachmentsCompanion.insert(
                    noteId: finalId,
                    type: type,
                    filePath: filePath,
                    sortOrder: Value(sortOrder),
                  ),
                );
          } else {
            await _db.into(_db.attachments).insert(
                  AttachmentsCompanion.insert(
                    id: Value(attachmentId),
                    noteId: finalId,
                    type: type,
                    filePath: filePath,
                    sortOrder: Value(sortOrder),
                  ),
                );
          }
          restoredAttachments++;
        }

        imported++;
      }

      return ImportResult(
        notesImported: imported,
        duplicateNotes: duplicates,
        attachmentsRestored: restoredAttachments,
      );
    } catch (e) {
      return ImportResult(error: '$e');
    }
  }

  /// Re-builds a [SyncNoteEntry] from the lossless note.json (mirrors
  /// [SyncNoteEntry.fromCbor]'s map layout).
  SyncNoteEntry _toSyncNoteEntry(Map<String, dynamic> noteMap) {
    final noteFields = (noteMap['noteFields'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v));
    return SyncNoteEntry(
      noteId: noteMap['noteId'] as String,
      syncVersion: (noteMap['syncVersion'] as int?) ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (noteMap['updatedAt'] as int?) ?? 0),
      deviceOriginId: (noteMap['deviceOriginId'] as String?) ?? 'import',
      noteFields: noteFields,
    );
  }

  Future<bool> _attachmentIdExists(String id) async {
    final rows = await (_db.select(_db.attachments)
          ..where((a) => a.id.equals(id)))
        .get();
    return rows.isNotEmpty;
  }

  /// After a collision [MergeResolver.insertAsNew] re-created the note under a
  /// fresh UUID; find that row (same title + origin, most recently created) so
  /// checklists/attachments attach to it rather than the pre-existing note.
  Future<String> _findDuplicateId(SyncNoteEntry entry) async {
    final title = entry.noteFields['title'] as String? ?? '';
    final rows = await (_db.select(_db.notes)
          ..where((t) =>
              t.id.isNotValue(entry.noteId) &
              t.title.equals(title) &
              t.deviceOriginId.equals(entry.deviceOriginId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.isEmpty ? entry.noteId : rows.first.id;
  }
}
