import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/revision_repository.dart';
import 'package:nook/data/tables/notes.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/test_database.dart';

void main() {
  test('Editor autosave flush persists content, links, and revision snapshot',
      () async {
    final harness = await createTempFileTestDatabase();
    addTearDown(harness.dispose);
    final clock = FakeClock(DateTime.utc(2026, 11, 28, 10, 0));

    final noteRepo = NoteRepository(harness.db);
    final linkRepo = NoteLinkRepository(harness.db);
    final revRepo = RevisionRepository(harness.db, clock: clock.now);

    final target = await noteRepo.createNote(
      id: 'target-note-1',
      title: 'Target Note',
      type: NoteType.text,
      deviceOriginId: 'dev-1',
    );

    final note = await noteRepo.createNote(
      id: 'source-note-1',
      title: 'Source Note',
      type: NoteType.text,
      deviceOriginId: 'dev-1',
    );

    final docJson =
        '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"See "},{"insert":"Target","attributes":{"href":"nook://note/${target.id}"}}]}}]}}';

    await noteRepo.updateContent(
      note.id,
      deltaContent: docJson,
      plainText: 'See Target',
      updatedAt: clock.now(),
    );
    await revRepo.maybeSnapshot(
      noteId: note.id,
      title: note.title,
      deltaContent: docJson,
      plainText: 'See Target',
      source: RevisionSource.autosave,
    );

    final stored = await noteRepo.getNoteById(note.id);
    expect(stored!.plainText, 'See Target');
    expect(stored.deltaContent, docJson);

    final backlinks = await linkRepo.incomingTo(target.id);
    expect(backlinks.map((b) => b.noteId), [note.id]);

    final revisions = await revRepo.listForNote(note.id);
    expect(revisions, hasLength(1));
  });
}
