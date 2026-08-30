import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/providers/selection_providers.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/collections/collections_screen.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/widgets/note_preview_pane.dart';
import 'package:nook/features/notebooks/notebooks_screen.dart';
import 'package:nook/features/notebooks/widgets/notebook_card.dart';
import 'package:nook/features/notebooks/widgets/notebook_detail_pane.dart';
import 'package:nook/features/tags/tags_screen.dart';
import 'package:nook/features/tags/widgets/tag_detail_pane.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

const _tabletSize = Size(1200, 900);
const _phoneSize = Size(400, 800);

/// Stand-in screen shown when a route push actually happens.
class _NavStub extends StatelessWidget {
  const _NavStub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('NAVIGATED')),
    );
  }
}

void main() {
  late AppDatabase db;
  int counter = 0;

  setUp(() {
    db = createTestDb();
    counter = 0;
  });

  tearDown(() async {
    await db.close();
  });

  void setViewSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrapScreen(Widget screen) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: screen),
      );

  Widget wrapWithRouter(GoRouter router) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      );

  GoRouter makeRouter({
    required Widget screen,
    required String path,
    List<String> navRoutes = const [],
  }) {
    return GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: path, builder: (_, __) => screen),
        for (final route in navRoutes)
          GoRoute(path: route, builder: (_, __) => const _NavStub()),
      ],
    );
  }

  Future<Note> insertNote(
    String title, {
    NoteType type = NoteType.text,
    String? notebookId,
  }) async {
    final id = 'tablet-note-${++counter}';
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            notebookId:
                notebookId != null ? Value(notebookId) : const Value.absent(),
            type: type,
            title: Value(title),
            deviceOriginId: 'device-1',
          ),
        );
    return (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  group('Home master-detail', () {
    testWidgets('renders preview pane with placeholder on tablet',
        (tester) async {
      setViewSize(tester, _tabletSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesListProvider.overrideWith((ref) => Stream.value(<Note>[])),
          ],
          child: const MaterialApp(home: HomeScreen(animate: false)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotePreviewPane), findsOneWidget);
      expect(find.text('Select a note'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('tapping a note fills the pane without navigating',
        (tester) async {
      setViewSize(tester, _tabletSize);
      final notes = await Future.wait([
        insertNote('Tablet Thought'),
        insertNote('Another Note'),
      ]);
      final router = makeRouter(
        screen: const HomeScreen(animate: false),
        path: '/home',
        navRoutes: ['/note/:id'],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesListProvider.overrideWith((ref) => Stream.value(notes)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tablet Thought').first);
      await tester.pumpAndSettle();

      expect(find.text('NAVIGATED'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Select a note'), findsNothing);
    });

    testWidgets('navigates on compact screens', (tester) async {
      setViewSize(tester, _phoneSize);
      final notes = await Future.wait([
        insertNote('Phone Thought'),
      ]);
      final router = makeRouter(
        screen: const HomeScreen(animate: false),
        path: '/home',
        navRoutes: ['/note/:id'],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesListProvider.overrideWith((ref) => Stream.value(notes)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotePreviewPane), findsNothing);

      await tester.tap(find.text('Phone Thought').first);
      await tester.pumpAndSettle();

      expect(find.text('NAVIGATED'), findsOneWidget);
    });
  });

  group('Notebooks master-detail', () {
    testWidgets('renders detail pane with placeholder on tablet',
        (tester) async {
      setViewSize(tester, _tabletSize);
      await tester.pumpWidget(wrapScreen(const NotebooksScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(NotebookDetailPane), findsOneWidget);
      expect(find.text('Select a collection'), findsOneWidget);
    });

    testWidgets('tapping a notebook shows its notes without navigating',
        (tester) async {
      setViewSize(tester, _tabletSize);
      final repo = NotebookRepository(db);
      final nb = await repo.createNotebook(
        name: 'Work',
        colorSeed: '#FF5722',
      );
      await insertNote('Work Note', notebookId: nb.id);

      final router = makeRouter(
        screen: const NotebooksScreen(),
        path: '/notebooks',
        navRoutes: ['/notebooks/:id'],
      );
      await tester.pumpWidget(wrapWithRouter(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NotebookCard).first);
      await tester.pumpAndSettle();

      expect(find.text('NAVIGATED'), findsNothing);
      expect(find.text('Work Note'), findsAtLeastNWidgets(1));
      expect(find.text('Select a notebook'), findsNothing);
    });

    testWidgets('no detail pane on compact screens', (tester) async {
      setViewSize(tester, _phoneSize);
      await tester.pumpWidget(wrapScreen(const NotebooksScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(NotebookDetailPane), findsNothing);
    });
  });

  group('Tags master-detail', () {
    testWidgets('renders detail pane with placeholder on tablet',
        (tester) async {
      setViewSize(tester, _tabletSize);
      await tester.pumpWidget(wrapScreen(const TagsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TagDetailPane), findsOneWidget);
      expect(find.text('Select a tag'), findsOneWidget);
    });

    testWidgets('tapping a tag shows its notes without navigating',
        (tester) async {
      setViewSize(tester, _tabletSize);
      final repo = TagRepository(db);
      final tag = await repo.createTag(
        name: 'Ideas',
        colorSeed: '#2196F3',
      );
      final note = await insertNote('Idea Note');
      await repo.assignTagToNote(note.id, tag.id);

      final router = makeRouter(
        screen: const TagsScreen(),
        path: '/tags',
        navRoutes: ['/tags/:id'],
      );
      await tester.pumpWidget(wrapWithRouter(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ideas').first);
      await tester.pumpAndSettle();

      expect(find.text('NAVIGATED'), findsNothing);
      expect(find.text('Idea Note'), findsAtLeastNWidgets(1));
      expect(find.text('Select a tag'), findsNothing);
    });

    testWidgets('no detail pane on compact screens', (tester) async {
      setViewSize(tester, _phoneSize);
      await tester.pumpWidget(wrapScreen(const TagsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TagDetailPane), findsNothing);
    });
  });

  group('Collections dual-pane hero isolation', () {
    testWidgets('same note in notebook and tag panes does not collide heroes',
        (tester) async {
      setViewSize(tester, _tabletSize);

      final nbRepo = NotebookRepository(db);
      final nb = await nbRepo.createNotebook(
        name: 'Work',
        colorSeed: '#FF5722',
      );
      final tagRepo = TagRepository(db);
      final tag = await tagRepo.createTag(
        name: 'Ideas',
        colorSeed: '#2196F3',
      );
      // A single note belongs to both the notebook and the tag, so it would be
      // rendered in BOTH panes at once (they stay alive in the
      // CollectionsScreen IndexedStack). Previously both NoteCards shared the
      // default `note-<id>` hero tag and threw "multiple heroes that share the
      // same tag within a subtree" on every build.
      final note = await insertNote('Shared Note', notebookId: nb.id);
      await tagRepo.assignTagToNote(note.id, tag.id);

      final router = GoRouter(
        initialLocation: '/notebooks',
        routes: [
          GoRoute(
            path: '/notebooks',
            builder: (_, __) => const CollectionsScreen(initialTab: 0),
          ),
          GoRoute(
            path: '/tags',
            builder: (_, __) => const CollectionsScreen(initialTab: 1),
          ),
          GoRoute(path: '/note/:id', builder: (_, __) => const _NavStub()),
          GoRoute(path: '/tags/:id', builder: (_, __) => const _NavStub()),
          GoRoute(path: '/notebooks/:id', builder: (_, __) => const _NavStub()),
        ],
      );
      await tester.pumpWidget(wrapWithRouter(router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select the notebook in the left pane, then select the tag on the Tags
      // tab. Both detail panes stay alive in the CollectionsScreen IndexedStack
      // and render the shared note — the bug this test guards against is two
      // NoteCards sharing the same Hero tag within that subtree.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CollectionsScreen)),
      );
      container.read(selectedNotebookIdProvider.notifier).state = nb.id;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Tags'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      container.read(selectedTagIdProvider.notifier).state = tag.id;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // The shared note is rendered by the tag detail pane (notebook tab stays
      // alive underneath in the IndexedStack but is offstage).
      expect(find.text('Shared Note'), findsAtLeastNWidgets(1));
    });

    testWidgets('dual pane renders unique FAB hero tags', (tester) async {
      setViewSize(tester, _tabletSize);
      final router = GoRouter(
        initialLocation: '/notebooks',
        routes: [
          GoRoute(
            path: '/notebooks',
            builder: (_, __) => const CollectionsScreen(initialTab: 0),
          ),
          GoRoute(
            path: '/tags',
            builder: (_, __) => const CollectionsScreen(initialTab: 1),
          ),
          GoRoute(path: '/notebooks/:id', builder: (_, __) => const _NavStub()),
          GoRoute(path: '/tags/:id', builder: (_, __) => const _NavStub()),
        ],
      );
      await tester.pumpWidget(wrapWithRouter(router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The compose FAB lives on CollectionsScreen (not the embedded screens),
      // so there should be no duplicate hero tags and no framework exceptions.
      expect(tester.takeException(), isNull);
    });
  });
}
