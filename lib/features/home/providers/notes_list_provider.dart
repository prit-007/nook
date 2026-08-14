import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/talker_provider.dart';
import '../../../data/database.dart';

/// Reactive stream of non-deleted notes, ordered by pinned desc then updatedAt desc.
final notesListProvider = StreamProvider<List<Note>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.notes)
    ..where((t) => t.deleted.equals(false))
    ..orderBy([
      (t) => OrderingTerm.desc(t.pinned),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);
  return query.watch().map((notes) {
    nookLog(
        NookLogKey.database, 'Notes loaded: ${notes.length}', LogLevel.debug);
    return notes;
  });
});
