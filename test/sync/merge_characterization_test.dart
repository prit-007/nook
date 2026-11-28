import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

import '../helpers/test_database.dart';

void main() {
  test(
      'MergeResolver characterization: insert, ignore, overwrite, promptUser, tombstone',
      () async {
    final harness = await createTempFileTestDatabase();
    addTearDown(harness.dispose);
    final noteRepo = NoteRepository(harness.db);
    final resolver = MergeResolver(noteRepo, NotebookRepository(harness.db));

    // 1. New note -> insertAsNew
    final newEntry = SyncNoteEntry(
      noteId: 'char-note-1',
      syncVersion: 2,
      updatedAt: DateTime.utc(2026, 11, 28, 10),
      deviceOriginId: 'peer-a',
      noteFields: const {'title': 'v2', 'type': 'text'},
    );
    expect(await resolver.resolveIncoming(newEntry), MergeAction.insertAsNew);
    await resolver.applyIncoming(newEntry);

    // 2. Older/same version -> ignore
    final olderEntry = SyncNoteEntry(
      noteId: 'char-note-1',
      syncVersion: 1,
      updatedAt: DateTime.utc(2026, 11, 28, 9),
      deviceOriginId: 'peer-a',
      noteFields: const {'title': 'v1', 'type': 'text'},
    );
    expect(await resolver.resolveIncoming(olderEntry), MergeAction.ignore);

    // 3. Same origin newer -> overwrite
    final sameOriginNewer = SyncNoteEntry(
      noteId: 'char-note-1',
      syncVersion: 3,
      updatedAt: DateTime.utc(2026, 11, 28, 11),
      deviceOriginId: 'peer-a',
      noteFields: const {'title': 'v3', 'type': 'text'},
    );
    expect(
        await resolver.resolveIncoming(sameOriginNewer), MergeAction.overwrite);

    // 4. Different origin newer -> promptUser
    final diffOriginNewer = SyncNoteEntry(
      noteId: 'char-note-1',
      syncVersion: 4,
      updatedAt: DateTime.utc(2026, 11, 28, 12),
      deviceOriginId: 'peer-b',
      noteFields: const {'title': 'conflict', 'type': 'text'},
    );
    expect(await resolver.resolveIncoming(diffOriginNewer),
        MergeAction.promptUser);

    // 5. Locally deleted -> ignore (never resurrect)
    await noteRepo.softDelete('char-note-1');
    expect(await resolver.resolveIncoming(sameOriginNewer), MergeAction.ignore);
  });
}
