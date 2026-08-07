import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/widgets/morphing_editorial_fab.dart';
import 'package:nook/features/home/widgets/note_banner_card.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';
import 'package:nook/features/home/widgets/note_minimal_card.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  int counter = 0;

  Future<List<Note>> insertNotes(List<({String title, NoteType type, bool pinned})> entries) async {
    final notes = <Note>[];
    for (final entry in entries) {
      final id = 'home-note-${++counter}';
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: Value(id),
              title: Value(entry.title),
              type: entry.type,
              deviceOriginId: 'device-1',
              pinned: Value(entry.pinned),
            ),
          );
      notes.add(
        await (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle(),
      );
    }
    return notes;
  }

  Widget buildHome({
    List<Note>? notes,
    double screenWidth = 400,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (notes != null)
          notesListProvider.overrideWith((ref) => Stream.value(notes)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(screenWidth, 800)),
          child: const HomeScreen(),
        ),
      ),
    );
  }

  testWidgets('renders the editorial header', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();
    expect(find.text('Own Your Notes.'), findsOneWidget);
  });

  testWidgets('shows a search text field', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows filter pills', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    expect(find.text('All notes'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Checklists'), findsOneWidget);
    expect(find.text('Doodles'), findsOneWidget);
  });

  testWidgets('shows morphing FAB', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();
    expect(find.byType(MorphingEditorialFab), findsOneWidget);
  });

  testWidgets('displays notes', (tester) async {
    final notes = await insertNotes([
      (title: 'Note 1', type: NoteType.text, pinned: false),
      (title: 'Note 2', type: NoteType.text, pinned: false),
    ]);

    await tester.pumpWidget(buildHome(notes: notes));
    await tester.pumpAndSettle();

    expect(find.text('Note 1'), findsAtLeastNWidgets(1));
    expect(find.text('Note 2'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows empty state when no notes', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    expect(find.textContaining('No notes'), findsOneWidget);
  });

  testWidgets('pinned note uses banner card', (tester) async {
    final notes = await insertNotes([
      (title: 'Pinned note', type: NoteType.text, pinned: true),
    ]);

    await tester.pumpWidget(buildHome(notes: notes));
    await tester.pumpAndSettle();

    expect(find.byType(NoteBannerCard), findsOneWidget);
  });

  testWidgets('text note uses minimal card', (tester) async {
    final notes = await insertNotes([
      (title: 'Text note', type: NoteType.text, pinned: false),
    ]);

    await tester.pumpWidget(buildHome(notes: notes));
    await tester.pumpAndSettle();

    expect(find.byType(NoteMinimalCard), findsOneWidget);
  });

  testWidgets('doodle note uses doodle card', (tester) async {
    final notes = await insertNotes([
      (title: 'My doodle', type: NoteType.doodle, pinned: false),
    ]);

    await tester.pumpWidget(buildHome(notes: notes));
    await tester.pumpAndSettle();

    expect(find.byType(NoteDoodleCard), findsOneWidget);
  });

  testWidgets('search field accepts text input', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'search query');
    await tester.pumpAndSettle();

    expect(find.text('search query'), findsOneWidget);
  });

  group('Responsive layout', () {
    testWidgets('mobile uses single-column stream', (tester) async {
      final notes = await insertNotes([
        (title: 'Note 1', type: NoteType.text, pinned: false),
        (title: 'Note 2', type: NoteType.text, pinned: false),
      ]);

      await tester.pumpWidget(buildHome(notes: notes, screenWidth: 400));
      await tester.pumpAndSettle();

      expect(find.byType(NoteMinimalCard), findsAtLeastNWidgets(1));
    });

    testWidgets('wide screen uses 2-column grid', (tester) async {
      final notes = await insertNotes([
        (title: 'Note A', type: NoteType.text, pinned: false),
        (title: 'Note B', type: NoteType.text, pinned: false),
      ]);

      await tester.pumpWidget(buildHome(notes: notes, screenWidth: 800));
      await tester.pumpAndSettle();

      expect(find.text('Note A'), findsAtLeastNWidgets(1));
      expect(find.text('Note B'), findsAtLeastNWidgets(1));
    });

    testWidgets('header scales down on wide screen', (tester) async {
      await tester.pumpWidget(buildHome(notes: [], screenWidth: 800));
      await tester.pumpAndSettle();

      expect(find.text('Own Your Notes.'), findsOneWidget);
    });
  });
}
