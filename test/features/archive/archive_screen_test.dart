import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/archive/archive_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('ArchiveScreen lists archived notes and unarchives on tap',
      (tester) async {
    final repo = NoteRepository(db);
    final note = await repo.createNote(
      title: 'Tax 2025',
      type: NoteType.text,
      deviceOriginId: 'd1',
    );
    await repo.archiveNote(note.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ArchiveScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tax 2025'), findsOneWidget);

    await tester.tap(find.byTooltip('Unarchive'));
    await tester.pumpAndSettle();

    expect(find.text('Tax 2025'), findsNothing);
    expect(find.text('No archived notes'), findsOneWidget);
    expect((await repo.getAllNotes()).map((n) => n.id), [note.id]);
  });
}
