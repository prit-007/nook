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

import 'simulator/sync_simulator.dart';

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

  test('SyncSimulator converges under drops, duplicates, and reordering',
      () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dbs = List.generate(3, (_) => AppDatabase(NativeDatabase.memory()));
    addTearDown(() async {
      for (final db in dbs) {
        await db.close();
      }
    });

    final noteRepos = dbs.map(NoteRepository.new).toList();
    final resolvers = [
      for (var i = 0; i < 3; i++)
        MergeResolver(noteRepos[i], NotebookRepository(dbs[i])),
    ];
    final packers = [for (final db in dbs) SyncBundlePacker(db: db)];
    final simulator = SyncSimulator(
      seed: 1337,
      dropProbability: 0.25,
      duplicateProbability: 0.30,
    );

    final baseTime = DateTime.utc(2026, 11, 28, 8);
    for (var p = 0; p < 3; p++) {
      for (var n = 0; n < 3; n++) {
        await noteRepos[p].createNote(
          id: 'sim-p$p-n$n',
          title: 'Sim Note $p.$n',
          type: NoteType.text,
          deviceOriginId: 'sim-dev-$p',
          createdAt: baseTime.add(Duration(minutes: p * 5 + n)),
        );
      }
    }

    // 3 chaotic rounds with drops, duplicates, and shuffling.
    for (var round = 0; round < 3; round++) {
      for (var src = 0; src < 3; src++) {
        final notes = await noteRepos[src].getAllNotes();
        final bundle = await packers[src].pack(
          noteIds: notes.map((n) => n.id).toList(),
          senderDeviceId: 'sim-dev-$src',
          senderDeviceName: 'Sim $src',
        );
        for (var dst = 0; dst < 3; dst++) {
          if (src == dst) continue;
          final delivered = simulator.simulateDelivery(bundle);
          await simulator.applyEntries(resolvers[dst], delivered);
        }
      }
    }

    // Final reliable catch-up round ensures eventual convergence.
    for (var src = 0; src < 3; src++) {
      final notes = await noteRepos[src].getAllNotes();
      final bundle = await packers[src].pack(
        noteIds: notes.map((n) => n.id).toList(),
        senderDeviceId: 'sim-dev-$src',
        senderDeviceName: 'Sim $src',
      );
      for (var dst = 0; dst < 3; dst++) {
        if (src == dst) continue;
        await simulator.applyEntries(resolvers[dst], bundle.notes);
      }
    }

    Future<Map<String, (String, int)>> snapshot(NoteRepository repo) async {
      final notes = await repo.getAllNotes();
      return {for (final n in notes) n.id: (n.title, n.syncVersion)};
    }

    final expected = await snapshot(noteRepos[0]);
    expect(expected, hasLength(9));
    expect(await snapshot(noteRepos[1]), equals(expected));
    expect(await snapshot(noteRepos[2]), equals(expected));
  });
}
