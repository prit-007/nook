import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/revision_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/version_history_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildHistory(String noteId) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: VersionHistoryScreen(noteId: noteId)),
    );
  }

  testWidgets('shows empty state when no revisions', (tester) async {
    final note = await NoteRepository(db).createNote(
      title: 'Lonely',
      type: NoteType.text,
      deviceOriginId: 'd1',
    );

    await tester.pumpWidget(buildHistory(note.id));
    await tester.pumpAndSettle();

    expect(find.textContaining('No versions yet'), findsOneWidget);
  });

  testWidgets('lists revisions with restore tap targets', (tester) async {
    final noteRepo = NoteRepository(db);
    final note = await noteRepo.createNote(
      title: 'Draft',
      type: NoteType.text,
      deviceOriginId: 'd1',
      plainText: 'first body',
    );
    final revRepo = RevisionRepository(db);
    await revRepo.maybeSnapshot(
      noteId: note.id,
      title: 'Draft',
      deltaContent: '{"v":1}',
      plainText: 'first body',
      source: RevisionSource.manual,
    );

    await tester.pumpWidget(buildHistory(note.id));
    await tester.pumpAndSettle();

    expect(find.text('Version history'), findsOneWidget);
    expect(find.text('first body'), findsOneWidget);
    expect(find.text('Tap to restore'), findsOneWidget);
    expect(find.text('manual'), findsOneWidget);
  });
}
