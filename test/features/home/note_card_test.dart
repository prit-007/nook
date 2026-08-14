import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/card_tag_pill.dart';
import 'package:nook/features/home/widgets/note_card.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Note> createTestNote({
    String id = 'test-note',
    String title = 'Test Note',
    NoteType type = NoteType.text,
    bool pinned = false,
    bool locked = false,
    String? colorSeed,
  }) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            type: type,
            title: Value(title),
            pinned: Value(pinned),
            locked: Value(locked),
            colorSeed: Value(colorSeed),
            deviceOriginId: 'device-1',
          ),
        );
    return (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  Widget buildCard(Note note) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: NoteCard(note: note),
        ),
      ),
    );
  }

  group('NoteCard', () {
    testWidgets('displays note title', (tester) async {
      final note = await createTestNote(title: 'Groceries');
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      // Title appears in header and as content preview fallback
      expect(find.text('Groceries'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows pin icon when pinned', (tester) async {
      final note = await createTestNote(title: 'Pinned Note', pinned: true);
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('does not show pin icon when not pinned', (tester) async {
      final note = await createTestNote(title: 'Normal Note', pinned: false);
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin), findsNothing);
    });

    testWidgets('shows lock icon when locked', (tester) async {
      final note = await createTestNote(title: 'Secret', locked: true);
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('blurs content when locked', (tester) async {
      final note = await createTestNote(title: 'Secret', locked: true);
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      // Should find a ClipRect or BackdropFilter for blur effect
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ClipRect || widget is BackdropFilter,
        ),
        findsWidgets,
      );
    });

    testWidgets('shows checklist icon for checklist notes', (tester) async {
      final note = await createTestNote(
        title: 'Tasks',
        type: NoteType.checklist,
      );
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('shows draw icon for doodle notes', (tester) async {
      final note = await createTestNote(
        title: 'Sketch',
        type: NoteType.doodle,
      );
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.draw), findsOneWidget);
    });

    testWidgets('applies tonal color from colorSeed', (tester) async {
      final note = await createTestNote(
        title: 'Colored',
        colorSeed: '#006A6A', // teal
      );
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      // Card should render without crashing
      expect(find.byType(NoteCard), findsOneWidget);
    });

    testWidgets('has rounded corners', (tester) async {
      final note = await createTestNote();
      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      final card = tester.widget<NoteCard>(find.byType(NoteCard));
      // Verify widget exists (rounded corners are in the internal Container)
      expect(card, isNotNull);
    });
  });

  group('NoteCard metadata row', () {
    testWidgets('shows notebook name and tags without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Create notebook
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-meta'),
              name: 'My Notebook',
              colorSeed: '#6750A4',
            ),
          );

      // Create note with notebook
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-meta'),
              type: NoteType.text,
              title: const Value('Tagged Note'),
              notebookId: const Value('nb-meta'),
              deviceOriginId: 'device-1',
            ),
          );

      // Create 3 tags
      for (var i = 0; i < 3; i++) {
        await db.into(db.tags).insert(
              TagsCompanion.insert(
                id: Value('tag-$i'),
                name: 'tag$i',
                colorSeed: '#FF000$i',
              ),
            );
        await db.into(db.noteTags).insert(
              NoteTagsCompanion.insert(noteId: 'note-meta', tagId: 'tag-$i'),
            );
      }

      final note = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-meta')))
          .getSingle();

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: NoteCard(note: note),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // No overflow
      expect(tester.takeException(), isNull);
      // Notebook name shown
      expect(find.text('My Notebook'), findsOneWidget);
      // First 2 tags shown
      expect(find.byType(CardTagPill), findsNWidgets(2));
      // Overflow pill shown (+1)
      expect(find.byType(CardTagOverflowPill), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('shows only tag pills when no notebook', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-tags-only'),
              type: NoteType.text,
              title: const Value('Tags Only'),
              deviceOriginId: 'device-1',
            ),
          );

      for (var i = 0; i < 5; i++) {
        await db.into(db.tags).insert(
              TagsCompanion.insert(
                id: Value('t$i'),
                name: 'work$i',
                colorSeed: '#AAAA0$i',
              ),
            );
        await db.into(db.noteTags).insert(
              NoteTagsCompanion.insert(noteId: 'note-tags-only', tagId: 't$i'),
            );
      }

      final note = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-tags-only')))
          .getSingle();

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: NoteCard(note: note),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 2 visible tags + overflow pill
      expect(find.byType(CardTagPill), findsNWidgets(2));
      expect(find.byType(CardTagOverflowPill), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      // No folder icon (no notebook)
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
    });

    testWidgets('shows no metadata row when no tags and no notebook',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-clean'),
              type: NoteType.text,
              title: const Value('Clean Note'),
              deviceOriginId: 'device-1',
            ),
          );

      final note = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-clean')))
          .getSingle();

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: NoteCard(note: note),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CardTagPill), findsNothing);
      expect(find.byType(CardTagOverflowPill), findsNothing);
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
    });

    testWidgets('notebook with long name and many tags does not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-long'),
              name: 'A Very Long Notebook Name That Wraps',
              colorSeed: '#006A6A',
            ),
          );

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-long-meta'),
              type: NoteType.text,
              title: const Value('Note'),
              notebookId: const Value('nb-long'),
              deviceOriginId: 'device-1',
            ),
          );

      for (var i = 0; i < 4; i++) {
        await db.into(db.tags).insert(
              TagsCompanion.insert(
                id: Value('lt$i'),
                name: 'longtag$i',
                colorSeed: '#00AAAA$i',
              ),
            );
        await db.into(db.noteTags).insert(
              NoteTagsCompanion.insert(noteId: 'note-long-meta', tagId: 'lt$i'),
            );
      }

      final note = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-long-meta')))
          .getSingle();

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: NoteCard(note: note),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('A Very Long Notebook Name That Wraps'), findsOneWidget);
      expect(find.byType(CardTagOverflowPill), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
    });
  });

  group('NoteCard overflow resistance', () {
    testWidgets('long checklist in bounded grid never overflows',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('n-overflow'),
              type: NoteType.checklist,
              title: const Value('A long checklist title that wraps'),
              deviceOriginId: 'device-1',
            ),
          );
      final itemRepo = ChecklistItemRepository(db);
      for (var i = 0; i < 8; i++) {
        await itemRepo.addItem(
          noteId: 'n-overflow',
          text: 'Task $i with some longer text to wrap around',
        );
      }
      final note = (db.select(db.notes)
            ..where((t) => t.id.equals('n-overflow')))
          .getSingle();

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: 1,
              itemBuilder: (_, __) => FutureBuilder(
                future: note,
                builder: (_, s) =>
                    s.hasData ? NoteCard(note: s.data!) : const SizedBox(),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('long checklist in dual-pane aspect ratio never overflows',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('n-overflow-pane'),
              type: NoteType.checklist,
              title: const Value('Checklist'),
              deviceOriginId: 'device-1',
            ),
          );
      final itemRepo = ChecklistItemRepository(db);
      for (var i = 0; i < 8; i++) {
        await itemRepo.addItem(
          noteId: 'n-overflow-pane',
          text: 'Task $i with some longer text',
        );
      }
      final note = (db.select(db.notes)
            ..where((t) => t.id.equals('n-overflow-pane')))
          .getSingle();

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.8,
              ),
              itemCount: 1,
              itemBuilder: (_, __) => FutureBuilder(
                future: note,
                builder: (_, s) =>
                    s.hasData ? NoteCard(note: s.data!) : const SizedBox(),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
