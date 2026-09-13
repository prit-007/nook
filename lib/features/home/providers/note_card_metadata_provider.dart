import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../data/database.dart';
import '../../../data/tables/attachments.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/tag_repository.dart';

/// Preloaded metadata for a single note card — eliminates per-card DB queries.
class NoteCardMetadata {
  const NoteCardMetadata({
    this.tags = const [],
    this.notebookName,
    this.checklistItems = const [],
    this.thumbnailPath,
  });

  final List<Tag> tags;
  final String? notebookName;
  final List<ChecklistItem> checklistItems;
  final String? thumbnailPath;
}

/// Batch-loads metadata (tags, notebook names, checklist items, thumbnails)
/// for all visible notes in just 4 queries instead of 2N+2.
final noteCardMetadataProvider =
    FutureProvider.family<Map<String, NoteCardMetadata>, List<Note>>(
  (ref, notes) async {
    if (notes.isEmpty) return {};

    final db = ref.read(databaseProvider);
    final noteIds = notes.map((n) => n.id).toList();

    // 4 batch queries in parallel.
    final results = await Future.wait([
      TagRepository(db).getTagsForNotes(noteIds),
      ChecklistItemRepository(db).getItemsForNotes(noteIds),
      _getThumbnails(db, noteIds),
      _getNotebookNames(db, notes),
    ]);

    final tagsMap = results[0] as Map<String, List<Tag>>;
    final checklistsMap = results[1] as Map<String, List<ChecklistItem>>;
    final thumbnailsMap = results[2] as Map<String, String>;
    final notebookNamesMap = results[3] as Map<String, String>;

    final metadata = <String, NoteCardMetadata>{};
    for (final note in notes) {
      metadata[note.id] = NoteCardMetadata(
        tags: tagsMap[note.id] ?? const [],
        notebookName: notebookNamesMap[note.notebookId],
        checklistItems: checklistsMap[note.id] ?? const [],
        thumbnailPath: thumbnailsMap[note.id],
      );
    }
    return metadata;
  },
);

Future<Map<String, String>> _getNotebookNames(
    AppDatabase db, List<Note> notes) async {
  final notebookIds =
      notes.map((n) => n.notebookId).whereType<String>().toSet().toList();
  if (notebookIds.isEmpty) return {};

  final notebooks = await NotebookRepository(db).getNotebooksByIds(notebookIds);
  return {for (final nb in notebooks) nb.id: nb.name};
}

Future<Map<String, String>> _getThumbnails(
    AppDatabase db, List<String> noteIds) async {
  if (noteIds.isEmpty) return {};
  final attachments = await (_dbSelectAttachments(db, noteIds));
  final map = <String, String>{};
  for (final a in attachments) {
    if (a.thumbnailPath != null && a.thumbnailPath!.isNotEmpty) {
      map.putIfAbsent(a.noteId, () => a.thumbnailPath!);
    }
  }
  return map;
}

Future<List<Attachment>> _dbSelectAttachments(
    AppDatabase db, List<String> noteIds) {
  return (db.select(db.attachments)
        ..where((a) =>
            a.noteId.isIn(noteIds) &
            a.type.equalsValue(AttachmentType.doodleLayer) &
            a.deleted.equals(false))
        ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
      .get();
}
