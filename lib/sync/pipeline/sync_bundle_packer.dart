import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/providers/talker_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/notes.dart';
import '../protocol/sync_bundle.dart';

/// Extracts note records, attachments, tags, checklist items, and CAS hashes
/// from Drift and builds a cryptographically integral [SyncBundle].
class SyncBundlePacker {
  SyncBundlePacker({
    required this.db,
    NoteRepository? noteRepo,
    AttachmentRepository? attachmentRepo,
    TagRepository? tagRepo,
    NotebookRepository? notebookRepo,
  })  : noteRepo = noteRepo ?? NoteRepository(db),
        attachmentRepo = attachmentRepo ?? AttachmentRepository(db),
        tagRepo = tagRepo ?? TagRepository(db),
        notebookRepo = notebookRepo ?? NotebookRepository(db);

  final AppDatabase db;
  final NoteRepository noteRepo;
  final AttachmentRepository attachmentRepo;
  final TagRepository tagRepo;
  final NotebookRepository notebookRepo;

  /// Serializes the notes designated by [noteIds] into a [SyncBundle].
  Future<SyncBundle> pack({
    required List<String> noteIds,
    required String senderDeviceId,
    required String senderDeviceName,
    void Function(int packedCount, int totalCount, String currentTitle)?
        onProgress,
  }) async {
    // Pre-fetch tags for all requested notes in a single query
    final tagMap = await tagRepo.getTagsForNotes(noteIds);
    final entries = <SyncNoteEntry>[];

    for (final noteId in noteIds) {
      final note = await noteRepo.getNoteById(noteId);
      if (note == null) continue;

      // Pack attachments and read their on-disk bytes
      final attachments = <SyncAttachment>[];
      final attachmentRows = await attachmentRepo.getAllForNote(noteId);
      for (final row in attachmentRows) {
        final file = File(row.filePath);
        if (await file.exists()) {
          Uint8List? thumbBytes;
          final thumbPath = row.thumbnailPath;
          if (thumbPath != null && thumbPath.isNotEmpty) {
            final thumbFile = File(thumbPath);
            if (await thumbFile.exists()) {
              thumbBytes = await thumbFile.readAsBytes();
            }
          }
          attachments.add(SyncAttachment(
            id: row.id,
            type: row.type.name,
            sortOrder: row.sortOrder,
            bytes: await file.readAsBytes(),
            filePath: row.filePath,
            thumbnailPath: thumbPath,
            thumbnailBytes: thumbBytes,
          ));
        } else {
          nookLog(
            NookLogKey.sync,
            'Attachment ${row.id} missing on disk: ${row.filePath}',
            LogLevel.warning,
          );
        }
      }

      // Pack checklist items for checklist or mixed notes
      List<Map<String, dynamic>>? checklistItems;
      if (note.type == NoteType.checklist || note.type == NoteType.mixed) {
        final items = await (db.select(db.checklistItems)
              ..where((t) => t.noteId.equals(noteId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
        if (items.isNotEmpty) {
          checklistItems = items
              .map((item) => {
                    'id': item.id,
                    'itemText': item.itemText,
                    'checked': item.checked,
                    'sortOrder': item.sortOrder,
                  })
              .toList();
        }
      }

      // Pack tags for this note
      final noteTags = tagMap[noteId];
      final tagsPayload = noteTags
          ?.map((t) => {
                'id': t.id,
                'name': t.name,
                'colorSeed': t.colorSeed,
              })
          .toList();

      // Pack notebook metadata so the receiver can create/link properly
      String? notebookName;
      String? notebookColorSeed;
      String? notebookIcon;
      String? notebookParentId;
      if (note.notebookId != null) {
        final notebook = await notebookRepo.getNotebookById(note.notebookId!);
        if (notebook != null) {
          notebookName = notebook.name;
          notebookColorSeed = notebook.colorSeed;
          notebookIcon = notebook.icon;
          notebookParentId = notebook.parentId;
        }
      }

      entries.add(SyncNoteEntry(
        noteId: note.id,
        syncVersion: note.syncVersion,
        updatedAt: note.updatedAt,
        deviceOriginId: note.deviceOriginId,
        noteFields: {
          'title': note.title,
          'type': note.type.name,
          'colorSeed': note.colorSeed,
          'pinned': note.pinned,
          'locked': note.locked,
          'notebookId': note.notebookId,
          'deltaContent': note.deltaContent,
          'plainText': note.plainText,
          'coverImagePath': note.coverImagePath,
          'createdAt': note.createdAt.millisecondsSinceEpoch,
          if (tagsPayload != null && tagsPayload.isNotEmpty)
            'tags': tagsPayload,
          if (notebookName != null) 'notebookName': notebookName,
          if (notebookColorSeed != null) 'notebookColorSeed': notebookColorSeed,
          if (notebookIcon != null) 'notebookIcon': notebookIcon,
          if (notebookParentId != null) 'notebookParentId': notebookParentId,
        },
        checklistItems: checklistItems != null && checklistItems.isNotEmpty
            ? checklistItems
            : null,
        attachments: attachments.isEmpty ? null : attachments,
      ));

      onProgress?.call(entries.length, noteIds.length, note.title);
    }

    return SyncBundle(
      protocolVersion: '1.0',
      senderDeviceId: senderDeviceId,
      senderDeviceName: senderDeviceName,
      sentAt: DateTime.now(),
      notes: entries,
    );
  }

  /// Splits [bytes] into indexed [PayloadChunk]s for resumable attachment/doodle
  /// transfers. Each chunk carries its own SHA-256 digest.
  static List<PayloadChunk> chunkPayload(
    Uint8List bytes, {
    int chunkSize = 64 * 1024,
  }) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be positive');
    }
    if (bytes.isEmpty) {
      return [
        PayloadChunk(
          index: 0,
          totalChunks: 1,
          data: Uint8List(0),
          sha256Hex: sha256.convert(const []).toString(),
        ),
      ];
    }

    final totalChunks = (bytes.length / chunkSize).ceil();
    final chunks = <PayloadChunk>[];
    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, bytes.length);
      final slice = Uint8List.sublistView(bytes, start, end);
      chunks.add(
        PayloadChunk(
          index: i,
          totalChunks: totalChunks,
          data: slice,
          sha256Hex: sha256.convert(slice).toString(),
        ),
      );
    }
    return chunks;
  }

  /// Verifies and reassembles [chunks] (supports out-of-order or resumed chunks).
  static Uint8List reassembleChunks(List<PayloadChunk> chunks) {
    if (chunks.isEmpty) {
      throw const FormatException('No chunks provided');
    }
    final expectedTotal = chunks.first.totalChunks;
    final byIndex = <int, PayloadChunk>{};
    for (final chunk in chunks) {
      if (chunk.totalChunks != expectedTotal) {
        throw const FormatException('Mismatched totalChunks in chunk stream');
      }
      final actualHash = sha256.convert(chunk.data).toString();
      if (actualHash != chunk.sha256Hex) {
        throw FormatException('Checksum mismatch at chunk ${chunk.index}');
      }
      byIndex[chunk.index] = chunk;
    }

    if (byIndex.length != expectedTotal) {
      throw FormatException(
        'Incomplete chunk stream: got ${byIndex.length}/$expectedTotal',
      );
    }

    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < expectedTotal; i++) {
      final chunk = byIndex[i];
      if (chunk == null) {
        throw FormatException('Missing chunk index $i');
      }
      builder.add(chunk.data);
    }
    return builder.toBytes();
  }
}

/// A single resumable payload chunk with SHA-256 integrity.
class PayloadChunk {
  const PayloadChunk({
    required this.index,
    required this.totalChunks,
    required this.data,
    required this.sha256Hex,
  });

  final int index;
  final int totalChunks;
  final Uint8List data;
  final String sha256Hex;
}
