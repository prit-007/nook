import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';

import 'fixtures/legacy_db_fixtures.dart';
import 'schema_snapshots/schema_snapshots.dart';

void main() {
  group('Schema migration upgrade tests (Phase 1.2)', () {
    for (final fromVersion in [8, 9, 10]) {
      test('upgrades v$fromVersion fixture to v11 preserving all rows',
          () async {
        final tempDir =
            await Directory.systemTemp.createTemp('nook_mig_fixture_');
        addTearDown(() => tempDir.delete(recursive: true));

        final fixtureFile = await createLegacyFixtureDb(
          tempDir,
          fromVersion: fromVersion,
        );

        final migrated = AppDatabase(NativeDatabase(fixtureFile));
        addTearDown(migrated.close);
        expect(migrated.schemaVersion, SchemaSnapshots.currentVersion);

        final notebooks = await migrated.select(migrated.notebooks).get();
        expect(notebooks.map((n) => n.id), contains('nb-legacy-1'));

        final notes = await migrated.select(migrated.notes).get();
        expect(notes.map((n) => n.id), contains('note-legacy-1'));
        expect(notes.first.plainText, 'Preserved across upgrade');
        expect(notes.first.archived, isFalse);

        // Verify schema snapshot tables exist.
        final tableRows = await migrated
            .customSelect("SELECT name FROM sqlite_master WHERE type='table';")
            .get();
        final tableNames = tableRows.map((r) => r.read<String>('name')).toSet();
        for (final expected in SchemaSnapshots.v11Tables) {
          expect(tableNames, contains(expected));
        }

        // Verify note columns match v11 snapshot.
        final colRows =
            await migrated.customSelect('PRAGMA table_info(notes);').get();
        final colNames = colRows.map((r) => r.read<String>('name')).toSet();
        for (final expectedCol in SchemaSnapshots.v11NoteColumns) {
          expect(colNames, contains(expectedCol));
        }
      });
    }
  });
}
