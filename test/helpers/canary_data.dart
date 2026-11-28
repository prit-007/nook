import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';

import 'fake_clock.dart';

const String kCanarySecret = 'CANARY_SECRET_TOKEN_9F3A';

class SeededCanaryVault {
  const SeededCanaryVault({
    required this.notebook,
    required this.unlockedNote,
    required this.lockedNote,
  });

  final Notebook notebook;
  final Note unlockedNote;
  final Note lockedNote;
}

/// Seeds deterministic synthetic unlocked + locked canary notes for leak and
/// round-trip tests.
Future<SeededCanaryVault> seedCanaryVault(
  AppDatabase db, {
  FakeClock? clock,
}) async {
  final c = clock ?? FakeClock();
  final nbRepo = NotebookRepository(db);
  final noteRepo = NoteRepository(db);

  final notebook = await nbRepo.createNotebookWithId(
    'canary-nb-1',
    name: 'Canary Notebook',
    colorSeed: '#4CAF50',
  );

  final unlockedNote = await noteRepo.createNote(
    id: 'canary-unlocked-1',
    title: 'Public Canary Note',
    type: NoteType.text,
    deviceOriginId: 'harness-dev-1',
    notebookId: notebook.id,
    plainText: 'Ordinary unlocked content',
    createdAt: c.now(),
  );

  c.advance(const Duration(minutes: 1));
  final lockedNote = await noteRepo.createNote(
    id: 'canary-locked-1',
    title: 'Locked Canary Note',
    type: NoteType.text,
    deviceOriginId: 'harness-dev-1',
    notebookId: notebook.id,
    plainText: 'Top secret: $kCanarySecret',
    createdAt: c.now(),
  );
  await noteRepo.updateNote(lockedNote.id, locked: true, updatedAt: c.now());
  final updatedLocked = (await noteRepo.getNoteById(lockedNote.id))!;

  return SeededCanaryVault(
    notebook: notebook,
    unlockedNote: unlockedNote,
    lockedNote: updatedLocked,
  );
}
