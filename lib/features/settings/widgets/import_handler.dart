import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/talker_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/tables/attachments.dart';
import '../../../sync/media_path_rewriter.dart';
import '../../../sync/protocol/merge_resolver.dart';
import '../../../sync/protocol/sync_bundle.dart';

/// Result of an import run.
class ImportResult {
  const ImportResult({
    this.notesImported = 0,
    this.duplicateNotes = 0,
    this.attachmentsRestored = 0,
    this.notebooksRestored = 0,
    this.error,
  });

  final int notesImported;

  /// Notes whose original id collided with an existing row and were re-created
  /// under a fresh id instead of overwriting anything.
  final int duplicateNotes;
  final int attachmentsRestored;

  /// Notebooks that were missing on this device and created from the vault.
  final int notebooksRestored;
  final String? error;

  bool get isSuccessful => error == null;
}

/// Restores a `.nook` backup produced by [NookExporter].
///
/// Uses the same insert semantics as sync's [MergeResolver.insertAsNew]: a
/// note whose id does not exist locally is created with that id; an id
/// collision is given a fresh UUID. Import never clobbers existing notes.
///
/// Notebooks listed in the vault are created first (missing ones only) so the
/// `notes.notebook_id` foreign key can never abort an import. Attachments are
/// re-materialised in the app's normal on-disk layout and every image url /
/// doodle thumbnail path inside `deltaContent` is re-pointed at the restored
/// files, so media renders on the target device exactly as on the source.
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
    nookLog(
      NookLogKey.database,
      'Import started: ${file.path}',
      LogLevel.info,
    );
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      nookLog(
        NookLogKey.database,
        'Vault opened: ${archive.files.length} file(s), '
        '${bytes.length} bytes',
        LogLevel.debug,
      );

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
      nookLog(
        NookLogKey.database,
        'Vault manifest OK: format v${manifest['formatVersion']}, '
        'exported ${manifest['exportedAt']}',
        LogLevel.debug,
      );

      final noteRepo = NoteRepository(_db);
      final resolver = MergeResolver(noteRepo);
      final notebookRepo = NotebookRepository(_db);

      // Restore notebooks before any note insert so the notes.notebook_id FK
      // always resolves, even when the vault was created on another device.
      final notebooksRestored = await _restoreNotebooks(archive, notebookRepo);

      final noteFiles = archive.files
          .where((f) => RegExp(r'^notes/[^/]+/note\.json$').hasMatch(f.name))
          .toList();
      nookLog(
        NookLogKey.database,
        'Importing ${noteFiles.length} note(s)',
        LogLevel.info,
      );

      var imported = 0;
      var duplicates = 0;
      var restoredAttachments = 0;

      for (final entryFile in noteFiles) {
        final noteMap = jsonDecode(utf8.decode(entryFile.content as List<int>))
            as Map<String, dynamic>;
        final entry = _toSyncNoteEntry(noteMap);

        // Resolve the notebook reference so a missing notebook (vault created
        // on another device, or an older archive without notebooks.json) can
        // never fail the insert with a FOREIGN KEY error.
        final notebookId = entry.noteFields['notebookId'] as String?;
        if (notebookId != null) {
          entry.noteFields['notebookId'] =
              await _resolveNotebookId(notebookId, notebookRepo);
        }

        final existed = await noteRepo.getNoteById(entry.noteId) != null;
        await resolver.insertAsNew(entry);
        final finalId = existed ? await _findDuplicateId(entry) : entry.noteId;
        if (existed) duplicates++;
        nookLog(
          NookLogKey.database,
          'Imported note ${entry.noteId} "${entry.noteFields['title']}"'
          '${existed ? ' (id collision -> new id $finalId)' : ''}',
          LogLevel.debug,
        );

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

        // Restore attachments and remember old->new path mappings so the note's
        // delta (image urls + doodle thumbnail paths) can be re-pointed.
        final baseDir = _restoredAttachmentsDirectory ??
            await getApplicationDocumentsDirectory();
        final restored = <RestoredMedia>[];
        for (final rawAttachment in (noteMap['attachments'] as List? ?? [])) {
          final restoredAttachment = await _restoreAttachment(
            rawAttachment as Map<String, dynamic>,
            finalId,
            baseDir,
          );
          if (restoredAttachment != null) {
            restored.add(restoredAttachment);
            restoredAttachments++;
          }
        }

        // Re-point the delta's media paths at the freshly restored files, or
        // the note's images/doodles would silently render as nothing. Parsed
        // structurally so a Windows-source vault (`C:\Users\...` paths, escaped
        // in JSON) is rewritten correctly onto this device.
        final originalDelta = entry.noteFields['deltaContent'] as String? ?? '';
        final rewrittenDelta = rewriteMediaPaths(originalDelta, restored);
        if (rewrittenDelta != originalDelta) {
          await noteRepo.updateContent(
            finalId,
            deltaContent: rewrittenDelta,
            plainText: entry.noteFields['plainText'] as String?,
            updatedAt: entry.updatedAt,
          );
          nookLog(
            NookLogKey.database,
            'Delta media paths re-pointed for $finalId '
            '(${restored.length} attachment(s))',
            LogLevel.debug,
          );
        } else if (restored.isNotEmpty) {
          nookLog(
            NookLogKey.database,
            'Delta for $finalId unchanged after attachment restore',
            LogLevel.debug,
          );
        }

        imported++;
      }

      nookLog(
        NookLogKey.database,
        'Import complete: $imported note(s), $duplicates duplicate(s), '
        '$restoredAttachments attachment(s), $notebooksRestored notebook(s)',
        LogLevel.info,
      );

      return ImportResult(
        notesImported: imported,
        duplicateNotes: duplicates,
        attachmentsRestored: restoredAttachments,
        notebooksRestored: notebooksRestored,
      );
    } catch (e) {
      nookLog(NookLogKey.database, 'Import failed: $e', LogLevel.error);
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

  /// Creates every notebook in `notebooks.json` that does not already exist on
  /// this device, preserving ids so repeated imports of the same vault are
  /// idempotent. Returns how many were newly created.
  Future<int> _restoreNotebooks(
    Archive archive,
    NotebookRepository repo,
  ) async {
    final notebooksFile = archive.findFile('notebooks.json');
    if (notebooksFile == null) return 0;

    final notebooks =
        jsonDecode(utf8.decode(notebooksFile.content as List<int>))
                as List<dynamic>? ??
            [];
    var restored = 0;
    for (final raw in notebooks) {
      final notebook = raw as Map<String, dynamic>;
      final id = notebook['id'] as String? ?? '';
      if (id.isEmpty) continue;
      if (await repo.getNotebookById(id) != null) continue;

      await _db.into(_db.notebooks).insert(
            NotebooksCompanion.insert(
              id: Value(id),
              name: notebook['name'] as String? ?? 'Imported Notebook',
              colorSeed: notebook['colorSeed'] as String? ?? '#6750A4',
              icon: Value(notebook['icon'] as String? ?? 'notebook'),
              sortOrder: Value(notebook['sortOrder'] as int? ?? 0),
            ),
          );
      restored++;
    }
    if (restored > 0) {
      nookLog(NookLogKey.database, 'Import restored $restored notebook(s)',
          LogLevel.info);
    }
    return restored;
  }

  /// Returns a [notebookId] that exists on this device. If the referenced
  /// notebook is missing (vault from another device, or an old archive with no
  /// `notebooks.json`), a placeholder is created under the same id so the note
  /// keeps its grouping instead of silently dropping to "All notes" — and the
  /// foreign key can never fail.
  Future<String> _resolveNotebookId(
    String notebookId,
    NotebookRepository repo,
  ) async {
    if (await repo.getNotebookById(notebookId) != null) return notebookId;

    await _db.into(_db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(notebookId),
            name: 'Imported Notebook',
            colorSeed: '#6750A4',
            icon: const Value('notebook'),
          ),
        );
    nookLog(NookLogKey.database, 'Notebook created during import: $notebookId',
        LogLevel.info);
    return notebookId;
  }

  /// Restores one attachment into the app's normal on-disk layout — images as
  /// `attachments/<id>.<ext>` (+ thumbnail), doodles as `<id>.doodle.json`
  /// sidecar (+ `<id>_thumb.png`) so `DoodleStorage` can still edit them — and
  /// records the old->new path mapping for the delta rewrite.
  Future<RestoredMedia?> _restoreAttachment(
    Map<String, dynamic> attachment,
    String noteId,
    Directory baseDir,
  ) async {
    final rawBytes = base64Decode(attachment['bytes'] as String? ?? '');
    if (rawBytes.isEmpty) return null;

    final type = attachment['type'] == 'doodleLayer'
        ? AttachmentType.doodleLayer
        : AttachmentType.image;
    final originalFilePath = attachment['filePath'] as String? ?? '';
    final originalThumbnailPath = attachment['thumbnailPath'] as String? ?? '';
    final thumbBytes =
        base64Decode(attachment['thumbnailBytes'] as String? ?? '');
    final fileName = attachment['fileName'] as String? ?? '';

    // Preserve the original id where possible; fall back to a fresh id if this
    // id is already taken on the target device.
    final originalId = attachment['id'] as String? ?? '';
    final resolvedId =
        originalId.isEmpty || await _attachmentIdExists(originalId)
            ? const Uuid().v4()
            : originalId;

    String filePath;
    String? thumbnailPath;
    if (type == AttachmentType.doodleLayer) {
      // Strokes sidecar at the location DoodleStorage expects, exactly as the
      // source device laid it out, so the doodle stays editable after restore.
      await baseDir.create(recursive: true);
      filePath = '${baseDir.path}/$resolvedId.doodle.json';
      await File(filePath).writeAsBytes(rawBytes, flush: true);

      if (thumbBytes.isNotEmpty) {
        thumbnailPath = '${baseDir.path}/${resolvedId}_thumb.png';
        await File(thumbnailPath).writeAsBytes(thumbBytes, flush: true);
      }
    } else {
      final ext = _imageExtension(originalFilePath, fileName);
      final attachmentsDir = Directory('${baseDir.path}/attachments');
      await attachmentsDir.create(recursive: true);
      filePath = '${attachmentsDir.path}/$resolvedId.$ext';
      await File(filePath).writeAsBytes(rawBytes, flush: true);

      if (thumbBytes.isNotEmpty) {
        thumbnailPath = '${attachmentsDir.path}/${resolvedId}_thumb.$ext';
        await File(thumbnailPath).writeAsBytes(thumbBytes, flush: true);
      }
    }

    await _db.into(_db.attachments).insert(
          AttachmentsCompanion.insert(
            id: Value(resolvedId),
            noteId: noteId,
            type: type,
            filePath: filePath,
            thumbnailPath: Value(thumbnailPath),
            sortOrder: Value(attachment['sortOrder'] as int? ?? 0),
          ),
        );

    nookLog(
      NookLogKey.database,
      'Restored attachment ${attachment['id'] ?? resolvedId} '
      '(${type.name}) -> $filePath'
      '${thumbnailPath != null ? ' + $thumbnailPath' : ''}',
      LogLevel.debug,
    );

    return RestoredMedia(
      attachmentId: originalId,
      newAttachmentId: resolvedId != originalId ? resolvedId : null,
      originalFileName: fileName.isEmpty ? null : fileName,
      originalFilePath: originalFilePath.isEmpty ? null : originalFilePath,
      originalThumbnailPath:
          originalThumbnailPath.isEmpty ? null : originalThumbnailPath,
      newFilePath: filePath,
      newThumbnailPath: thumbnailPath,
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

  static String _imageExtension(String originalFilePath, String fileName) {
    final fromPath = p.extension(originalFilePath);
    if (fromPath.isNotEmpty) return fromPath.substring(1);
    final fromName = p.extension(fileName);
    if (fromName.isNotEmpty) return fromName.substring(1);
    return 'img';
  }
}
