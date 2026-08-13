import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
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
      expect(find.text('Select a notebook'), findsOneWidget);
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
}
