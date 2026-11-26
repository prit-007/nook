import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/theme/app_theme.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/core/widgets/parallax_card.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/widgets/home_view_options_sheet.dart';
import 'package:nook/features/home/widgets/note_compact_tile.dart';
import 'package:nook/features/home/widgets/note_minimal_card.dart';
import 'package:nook/features/home/widgets/nook_hero.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  int counter = 0;

  setUp(() {
    db = createTestDb();

    // Awaited HapticFeedback calls never complete under the test binding
    // (there is no engine to answer the platform message), which would stall
    // confirmDismiss before it writes to the DB. Answer them immediately.
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<Note>> insertNotes(
      List<({String title, NoteType type, bool pinned, DateTime? updatedAt})>
          entries) async {
    final notes = <Note>[];
    for (final entry in entries) {
      final id = 'phase3-note-${++counter}';
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: Value(id),
              title: Value(entry.title),
              type: entry.type,
              deviceOriginId: 'device-1',
              pinned: Value(entry.pinned),
              updatedAt: entry.updatedAt != null
                  ? Value(entry.updatedAt!)
                  : const Value.absent(),
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
    double screenHeight = 1400,
    bool animate = false,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (notes != null)
          notesListProvider.overrideWith((ref) => Stream.value(notes)),
        checklistItemsRevisionProvider
            .overrideWith((ref) => const Stream<void>.empty()),
      ],
      child: MaterialApp(
        theme: buildLightTheme(NookColors.seeds.first),
        home: MediaQuery(
          data: MediaQueryData(size: Size(screenWidth, screenHeight)),
          child: HomeScreen(animate: animate),
        ),
      ),
    );
  }

  group('Phase 3 — QuickCaptureBar', () {
    testWidgets('renders capture bar in NookHero when notes are displayed',
        (tester) async {
      final notes = await insertNotes([
        (
          title: 'Thought 1',
          type: NoteType.text,
          pinned: false,
          updatedAt: null
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      expect(find.byType(NookHeroSliver), findsOneWidget);
      expect(find.text('Capture a thought'), findsOneWidget);
      expect(find.byTooltip('New checklist'), findsOneWidget);
      expect(find.byTooltip('New doodle'), findsOneWidget);
    });

    testWidgets('hides NookHero and capture bar in selection mode',
        (tester) async {
      final notes = await insertNotes([
        (
          title: 'Thought 1',
          type: NoteType.text,
          pinned: false,
          updatedAt: null
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      expect(find.byType(NookHeroSliver), findsOneWidget);
      expect(find.text('Capture a thought'), findsOneWidget);

      // Enter selection mode
      await tester.tap(find.byTooltip('Select notes'));
      await tester.pumpAndSettle();

      expect(find.byType(NookHeroSliver), findsNothing);
      expect(find.text('Capture a thought'), findsNothing);
    });
  });

  group('Phase 3 — View Modes & Options Sheet', () {
    testWidgets('default view mode is Masonry with SliverMasonryGrid',
        (tester) async {
      final notes = await insertNotes([
        (title: 'Note 1', type: NoteType.text, pinned: false, updatedAt: null),
        (title: 'Note 2', type: NoteType.text, pinned: false, updatedAt: null),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      expect(find.byType(SliverMasonryGrid), findsOneWidget);
      expect(find.byType(NoteMinimalCard), findsNWidgets(2));
    });

    testWidgets('switching to Compact mode renders NoteCompactTile rows',
        (tester) async {
      final notes = await insertNotes([
        (title: 'Note 1', type: NoteType.text, pinned: false, updatedAt: null),
        (title: 'Note 2', type: NoteType.text, pinned: false, updatedAt: null),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      // Open View Options sheet
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeViewOptionsSheet), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);

      // Select Compact mode
      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();

      // Dismiss sheet
      Navigator.of(tester.element(find.byType(HomeViewOptionsSheet))).pop();
      await tester.pumpAndSettle();

      // Verify NoteCompactTile rows appear instead of cards
      expect(find.byType(NoteCompactTile), findsNWidgets(2));
      expect(find.text('Note 1'), findsOneWidget);
      expect(find.text('Note 2'), findsOneWidget);
    });

    testWidgets('switching to List mode renders cards in list layout',
        (tester) async {
      final notes = await insertNotes([
        (title: 'Note 1', type: NoteType.text, pinned: false, updatedAt: null),
        (title: 'Note 2', type: NoteType.text, pinned: false, updatedAt: null),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      // Open View Options sheet
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();

      // Select List mode
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      // Dismiss sheet
      Navigator.of(tester.element(find.byType(HomeViewOptionsSheet))).pop();
      await tester.pumpAndSettle();

      // No longer SliverMasonryGrid
      expect(find.byType(SliverMasonryGrid), findsNothing);
      expect(find.byType(NoteMinimalCard), findsNWidgets(2));
    });
  });

  group('Phase 3 — Grouping', () {
    testWidgets('group by Pinned separates pinned and others with headers',
        (tester) async {
      final notes = await insertNotes([
        (
          title: 'Pinned Note',
          type: NoteType.text,
          pinned: true,
          updatedAt: null
        ),
        (
          title: 'Regular Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: null
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes, screenHeight: 1400));
      await tester.pumpAndSettle();

      // Open View Options sheet
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();

      // Select Group by Pinned from inside the sheet
      await tester.tap(find.descendant(
        of: find.byType(HomeViewOptionsSheet),
        matching: find.text('Pinned'),
      ));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(HomeViewOptionsSheet))).pop();
      await tester.pumpAndSettle();

      // The Pinned group sits at the top of the scroller.
      expect(find.text('Pinned'), findsAtLeastNWidgets(1));
      expect(find.text('Pinned Note'), findsOneWidget);

      // The Others group is rendered below the fold — scroll it into view.
      await tester.scrollUntilVisible(
        find.text('Others'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Others'), findsOneWidget);
      expect(find.text('Regular Note'), findsOneWidget);
    });

    testWidgets('group by Date groups notes into chronological buckets',
        (tester) async {
      final now = DateTime.now();
      final notes = await insertNotes([
        (
          title: 'Today Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: now.subtract(const Duration(minutes: 10)),
        ),
        (
          title: 'Yesterday Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: now.subtract(const Duration(hours: 26)),
        ),
        (
          title: 'Older Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: now.subtract(const Duration(days: 14)),
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes, screenHeight: 1400));
      await tester.pumpAndSettle();

      // Open View Options sheet
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();

      // Select Group by Date from inside the sheet
      await tester.tap(find.descendant(
        of: find.byType(HomeViewOptionsSheet),
        matching: find.text('Date'),
      ));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(HomeViewOptionsSheet))).pop();
      await tester.pumpAndSettle();

      // Today bucket is at the top of the scroller.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Today Note'), findsOneWidget);

      // Yesterday sits just below it.
      await tester.scrollUntilVisible(
        find.text('Yesterday'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Yesterday Note'), findsOneWidget);

      // Older is further down the scroller.
      await tester.scrollUntilVisible(
        find.text('Older'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Older'), findsOneWidget);
      expect(find.text('Older Note'), findsOneWidget);
    });
  });

  group('Phase 3 — Swipe Actions', () {
    testWidgets('swipe right toggles pin status', (tester) async {
      final notes = await insertNotes([
        (
          title: 'Swipeable Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: null
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      final dismissible = find.byType(Dismissible);
      expect(dismissible, findsOneWidget);

      // Fling right (startToEnd) to toggle pin
      await tester.fling(dismissible, const Offset(300, 0), 1000.0);
      await tester.pumpAndSettle();

      // Verify db updated to pinned
      final updatedNote = await (db.select(db.notes)
            ..where((t) => t.id.equals(notes.first.id)))
          .getSingle();
      expect(updatedNote.pinned, isTrue);
    });

    testWidgets('swipe left soft-deletes to bin with undo snackbar',
        (tester) async {
      final notes = await insertNotes([
        (
          title: 'Delete Me Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: null
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      final dismissible = find.byType(Dismissible);
      expect(dismissible, findsOneWidget);

      // Fling left (endToStart) to delete
      await tester.fling(dismissible, const Offset(-300, 0), 1000.0);
      await tester.pumpAndSettle();

      // Verify db updated to deleted
      final updatedNote = await (db.select(db.notes)
            ..where((t) => t.id.equals(notes.first.id)))
          .getSingle();
      expect(updatedNote.deleted, isTrue);

      // Verify Undo snackbar appeared
      expect(
          find.textContaining('Moved "Delete Me Note" to Bin'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final restoredNote = await (db.select(db.notes)
            ..where((t) => t.id.equals(notes.first.id)))
          .getSingle();
      expect(restoredNote.deleted, isFalse);
    });
  });

  group('Phase 3 — ParallaxCard frame budget', () {
    testWidgets('ParallaxCard is used in masonry mode when animate is true',
        (tester) async {
      final notes = await insertNotes([
        (
          title: 'Animated Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: null
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes, animate: true));
      await tester.pumpAndSettle();

      expect(find.byType(ParallaxCard), findsOneWidget);
    });

    testWidgets('ParallaxCard is NOT used in compact mode to protect scroll',
        (tester) async {
      final notes = await insertNotes([
        (
          title: 'Compact Note',
          type: NoteType.text,
          pinned: false,
          updatedAt: null
        ),
      ]);

      await tester.pumpWidget(buildHome(notes: notes, animate: true));
      await tester.pumpAndSettle();

      // Switch to compact
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compact'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(HomeViewOptionsSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(NoteCompactTile), findsOneWidget);
      expect(find.byType(ParallaxCard), findsNothing);
    });
  });
}
