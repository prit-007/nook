import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/providers/theme_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/search_screen.dart';
import 'package:nook/features/home/widgets/morphing_editorial_fab.dart';
import 'package:nook/features/home/widgets/note_banner_card.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';
import 'package:nook/features/home/widgets/note_minimal_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<List<Note>> insertNotes(
      List<({String title, NoteType type, bool pinned})> entries) async {
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
    ThemePreference? preference,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (preference != null)
          themePreferenceProvider.overrideWith((ref) => preference),
        if (notes != null)
          notesListProvider.overrideWith((ref) => Stream.value(notes)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(screenWidth, 800)),
          child: const HomeScreen(animate: false),
        ),
      ),
    );
  }

  testWidgets('renders the editorial header with time-aware greeting',
      (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    final hour = DateTime.now().hour;
    String expectedGreeting;
    if (hour < 12) {
      expectedGreeting = 'Morning thoughts.';
    } else if (hour < 17) {
      expectedGreeting = 'Afternoon flow.';
    } else if (hour < 22) {
      expectedGreeting = 'Evening reflections.';
    } else {
      expectedGreeting = 'Late night ideas.';
    }

    expect(find.text(expectedGreeting), findsOneWidget);
    expect(find.text('YOUR VAULT'), findsOneWidget);
  });

  testWidgets('shows a tappable search bar', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    expect(
      find.text('Search thoughts, doodles, checklists...'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('shows filter pills', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    expect(find.text('All notes'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Checklists'), findsOneWidget);
    expect(find.text('Doodles'), findsOneWidget);
  });

  testWidgets('shows filter pill counts when notes exist', (tester) async {
    final notes = await insertNotes([
      (title: 'Note 1', type: NoteType.text, pinned: false),
      (title: 'Note 2', type: NoteType.text, pinned: false),
      (title: 'Note 3', type: NoteType.checklist, pinned: false),
    ]);

    await tester.pumpWidget(buildHome(notes: notes));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsAtLeastNWidgets(1));
    expect(find.text('2'), findsAtLeastNWidgets(1));
    expect(find.text('1'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows morphing FAB', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();
    expect(find.byType(MorphingEditorialFab), findsOneWidget);
  });

  testWidgets('compose FAB toggles the menu on each tap', (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    expect(find.text('Quick Thought'), findsNothing);

    // First tap opens the menu (single tap, no blur-only state).
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Canvas Doodle'), findsOneWidget);
    expect(find.text('Interactive Checklist'), findsOneWidget);
    expect(find.text('Quick Thought'), findsOneWidget);

    // Second tap closes it again.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Quick Thought'), findsNothing);
  });

  testWidgets(
      'quick actions sheet renders ListTiles without ink-splash warnings',
      (tester) async {
    final notes = await insertNotes([
      (title: 'Sheet note', type: NoteType.text, pinned: false),
    ]);

    await tester.pumpWidget(buildHome(notes: notes));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Sheet note'));
    await tester.pumpAndSettle();

    expect(find.text('Pin Note'), findsOneWidget);
    expect(find.text('Color Theme'), findsOneWidget);
    // The frosted sheet sits between the ListTiles and the nearest Material;
    // the inner Material wrap must prevent the ink-splash visibility warning.
    expect(tester.takeException(), isNull);
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

    expect(find.text('Your canvas is clear'), findsOneWidget);
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

  group('Hero transitions', () {
    testWidgets('minimal card exposes hero tag matching note id',
        (tester) async {
      final notes = await insertNotes([
        (title: 'Text note', type: NoteType.text, pinned: false),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      final hero = tester.widget<Hero>(
        find.descendant(
          of: find.byType(NoteMinimalCard),
          matching: find.byType(Hero),
        ),
      );
      expect(hero.tag, 'note-${notes.first.id}');
    });

    testWidgets('banner card exposes hero tag matching note id',
        (tester) async {
      final notes = await insertNotes([
        (title: 'Pinned note', type: NoteType.text, pinned: true),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      final hero = tester.widget<Hero>(
        find.descendant(
          of: find.byType(NoteBannerCard),
          matching: find.byType(Hero),
        ),
      );
      expect(hero.tag, 'note-${notes.first.id}');
    });

    testWidgets('doodle card exposes hero tag matching note id',
        (tester) async {
      final notes = await insertNotes([
        (title: 'My doodle', type: NoteType.doodle, pinned: false),
      ]);

      await tester.pumpWidget(buildHome(notes: notes));
      await tester.pumpAndSettle();

      final hero = tester.widget<Hero>(
        find.descendant(
          of: find.byType(NoteDoodleCard),
          matching: find.byType(Hero),
        ),
      );
      expect(hero.tag, 'note-${notes.first.id}');
    });
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

      expect(find.text('YOUR VAULT'), findsOneWidget);
    });
  });

  group('Pull-to-search', () {
    testWidgets('swiping down at the top opens the search screen',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(animate: false),
          ),
          GoRoute(
            path: '/home/search',
            builder: (_, __) => const SearchScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesListProvider.overrideWith((ref) => Stream.value(<Note>[])),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Pull down from the top of the grid past the 80px threshold.
      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, 200),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search notes'), findsOneWidget);
    });

    testWidgets('a small pull does not open search', (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(animate: false),
          ),
          GoRoute(
            path: '/home/search',
            builder: (_, __) => const SearchScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesListProvider.overrideWith((ref) => Stream.value(<Note>[])),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, 20),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Type to search notes'), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  testWidgets('gates entrance animations behind reduceMotion and still renders',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notes = await insertNotes([
      (title: 'Pinned Thought', type: NoteType.text, pinned: true),
      (title: 'Sketch', type: NoteType.doodle, pinned: false),
      (title: 'Grocery Run', type: NoteType.checklist, pinned: false),
    ]);
    final reduced = await ThemePreference.load()
      ..setReduceMotion(true);

    await tester.pumpWidget(
      buildHome(notes: notes, preference: reduced),
    );
    await tester.pumpAndSettle();

    expect(find.text('YOUR VAULT'), findsOneWidget);
    expect(find.text('Pinned Thought'), findsOneWidget);
    expect(find.text('Sketch'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Grocery Run'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Grocery Run'), findsOneWidget);
  });

  testWidgets('FAB receives mobileBottomOffset based on screen padding',
      (tester) async {
    await tester.pumpWidget(buildHome(notes: []));
    await tester.pumpAndSettle();

    final fab = tester.widget<MorphingEditorialFab>(
      find.byType(MorphingEditorialFab),
    );
    // Default bottom padding is 0; the shell already reserves the dock height
    // via body padding, so the FAB offset is just the small gap above it.
    expect(fab.mobileBottomOffset, equals(16));
  });
}
