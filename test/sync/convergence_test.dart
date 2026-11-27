import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/sync/pipeline/sync_bundle_packer.dart';
import 'package:nook/sync/protocol/merge_resolver.dart';

void main() {
  test('4 peers converge deterministically after randomized sync orders',
      () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dbs = List.generate(4, (_) => AppDatabase(NativeDatabase.memory()));
    addTearDown(() async {
      for (final db in dbs) {
        await db.close();
      }
    });

    final noteRepos = dbs.map(NoteRepository.new).toList();
    final resolvers = [
      for (var i = 0; i < 4; i++)
        MergeResolver(noteRepos[i], NotebookRepository(dbs[i])),
    ];
    final packers = [for (final db in dbs) SyncBundlePacker(db: db)];

    final rng = Random(42);
    final baseTime = DateTime.utc(2026, 11, 27, 12);

    // Each peer creates 3 distinct notes and updates some of them.
    for (var p = 0; p < 4; p++) {
      for (var n = 0; n < 3; n++) {
        final note = await noteRepos[p].createNote(
          id: 'peer-$p-note-$n',
          title: 'Peer $p Note $n',
          type: NoteType.text,
          deviceOriginId: 'device-$p',
          createdAt: baseTime.add(Duration(minutes: p * 10 + n)),
        );
        if (rng.nextBool()) {
          await noteRepos[p].updateNote(
            note.id,
            title: 'Peer $p Note $n v2',
            syncVersion: 2,
            updatedAt: baseTime.add(Duration(minutes: 100 + p * 10 + n)),
          );
        }
      }
    }

    // Randomize pairwise sync order across 2 full rounds.
    final pairs = <(int, int)>[];
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        if (i != j) pairs.add((i, j));
      }
    }

    for (var round = 0; round < 2; round++) {
      pairs.shuffle(rng);
      for (final (src, dst) in pairs) {
        final notes = await noteRepos[src].getAllNotes();
        final bundle = await packers[src].pack(
          noteIds: notes.map((n) => n.id).toList(),
          senderDeviceId: 'device-$src',
          senderDeviceName: 'Peer $src',
        );
        for (final entry in bundle.notes) {
          await resolvers[dst].applyIncoming(entry);
        }
      }
    }

    // Assert every peer converged to the exact same set of note IDs and titles.
    Future<Map<String, (String, int)>> snapshot(NoteRepository repo) async {
      final notes = await repo.getAllNotes();
      return {
        for (final n in notes) n.id: (n.title, n.syncVersion),
      };
    }

    final expected = await snapshot(noteRepos[0]);
    expect(expected, hasLength(12));
    for (var p = 1; p < 4; p++) {
      expect(await snapshot(noteRepos[p]), equals(expected));
    }
  });
}
