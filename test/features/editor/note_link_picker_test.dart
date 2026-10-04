import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/widgets/note_link_picker.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('picker lists notes and returns selection', (tester) async {
    final note = await NoteRepository(db).createNote(
      title: 'Link target',
      type: NoteType.text,
      deviceOriginId: 'd1',
    );

    NoteLinkPick? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showNoteLinkPicker(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Link to note'), findsOneWidget);
    expect(find.text('Link target'), findsOneWidget);
    await tester.tap(find.text('Link target'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.noteId, note.id);
  });

  testWidgets('links sheet shows empty state without links', (tester) async {
    final note = await NoteRepository(db).createNote(
      title: 'Lonely note',
      type: NoteType.text,
      deviceOriginId: 'd1',
    );

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showNoteLinksSheet(
              context,
              noteId: note.id,
              noteTitle: 'Lonely note',
            ),
            child: const Text('links'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('links'));
    await tester.pumpAndSettle();

    expect(find.text('Linked notes'), findsOneWidget);
    expect(find.textContaining('No links yet'), findsOneWidget);
  });

  testWidgets('links sheet shows backlinks after rebuild', (tester) async {
    final a = await NoteRepository(db).createNote(
      title: 'Source',
      type: NoteType.text,
      deviceOriginId: 'd1',
    );
    final b = await NoteRepository(db).createNote(
      title: 'Target',
      type: NoteType.text,
      deviceOriginId: 'd1',
    );
    await NoteRepository(db).updateContent(
      a.id,
      deltaContent:
          '{"document":{"children":[{"type":"paragraph","delta":[{"insert":"x","attributes":{"href":"nook://note/${b.id}"}}]}]}}',
      plainText: 'x',
    );

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showNoteLinksSheet(
              context,
              noteId: b.id,
              noteTitle: 'Target',
            ),
            child: const Text('links'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('links'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Referenced in 1 note'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });
}
