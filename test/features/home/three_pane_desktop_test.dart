import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/providers/selection_providers.dart';
import 'package:nook/core/theme/app_theme.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/core/widgets/app_shell.dart';
import 'package:nook/core/widgets/resizable_split_view.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/widgets/desktop_navigation_sidebar.dart';
import 'package:nook/features/home/widgets/note_preview_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/ascii_layout.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late Note testNote1;
  late Note testNote2;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);

    testNote1 = await noteRepo.createNote(
      id: 'note-1',
      title: 'First Note Title',
      plainText: 'Initial content of note 1',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    testNote2 = await noteRepo.createNote(
      id: 'note-2',
      title: 'Second Note Title',
      plainText: 'Initial content of note 2',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildDesktopApp({
    required Size size,
    String initialLocation = '/home',
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(animate: false),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesListProvider
            .overrideWith((ref) => Stream.value([testNote1, testNote2])),
        checklistItemsRevisionProvider
            .overrideWith((ref) => const Stream<void>.empty()),
      ],
      child: MaterialApp.router(
        theme: buildLightTheme(NookColors.seeds.first),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
          ),
          child: child!,
        ),
      ),
    );
  }

  group('Phase 13b: Three-Pane Desktop Wire-up', () {
    testWidgets(
        'Data-safety: edit note, switch before debounce fires, edit is flushed',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesListProvider
              .overrideWith((ref) => Stream.value([testNote1, testNote2])),
          checklistItemsRevisionProvider
              .overrideWith((ref) => const Stream<void>.empty()),
        ],
      );
      container.read(selectedNoteIdProvider.notifier).state = 'note-1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: NotePreviewPane(isDesktopEditor: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Edit note-1 text
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Updated unsaved content for note 1');

      // Immediately switch selected note to note-2 without waiting for debounce timer!
      container.read(selectedNoteIdProvider.notifier).state = 'note-2';
      await tester.pumpAndSettle();

      // Verify note-1 was flushed and saved to DB
      final savedNote1 = await noteRepo.getNoteById('note-1');
      expect(savedNote1!.plainText, 'Updated unsaved content for note 1');
    });

    testWidgets(
        '1440x900 renders 3 panes with left-to-right ordering and no NavigationRail',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildDesktopApp(size: const Size(1440, 900)),
      );
      await tester.pumpAndSettle();

      // Sidebar exists
      final sidebarFinder = find.byType(DesktopNavigationSidebar);
      expect(sidebarFinder, findsOneWidget);

      // Editor / Preview pane exists
      final editorFinder = find.byType(NotePreviewPane);
      expect(editorFinder, findsOneWidget);

      // Split view exists
      final splitViewFinder = find.byType(ResizableSplitView);
      expect(splitViewFinder, findsOneWidget);

      // NavigationRail MUST NOT render alongside DesktopNavigationSidebar
      expect(find.byType(NavigationRail), findsNothing);

      // Left-to-right ordering: Sidebar Left < SplitView Left < Editor Left
      final sidebarRect = tester.getRect(sidebarFinder);
      final splitRect = tester.getRect(splitViewFinder);
      final editorRect = tester.getRect(editorFinder);

      expect(sidebarRect.left, equals(0.0));
      expect(sidebarRect.width, greaterThanOrEqualTo(240.0));
      expect(splitRect.left, greaterThanOrEqualTo(sidebarRect.right));
      expect(editorRect.left, greaterThan(splitRect.left));
      expect(editorRect.width, greaterThanOrEqualTo(400.0));

      final snap = asciiLayout(
        tester,
        {
          'sidebar': sidebarFinder,
          'editor': editorFinder,
        },
        cols: 60,
        rows: 15,
      );
      expect(snap, isNotEmpty);
      expectLayoutSnap(snap, 'three_pane_desktop_1440x900');
    });

    testWidgets('responsive degradation across 1440, 1000, 700, and 400',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesListProvider
              .overrideWith((ref) => Stream.value([testNote1, testNote2])),
          checklistItemsRevisionProvider
              .overrideWith((ref) => const Stream<void>.empty()),
        ],
      );
      container.read(selectedNoteIdProvider.notifier).state = 'note-1';

      Widget buildWithCurrentSize(Size size) {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildLightTheme(NookColors.seeds.first),
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: const Scaffold(
                body: HomeScreen(animate: false),
              ),
            ),
          ),
        );
      }

      // 1. 1440 (Large: Three-pane)
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(buildWithCurrentSize(const Size(1440, 900)));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopNavigationSidebar), findsOneWidget);
      expect(find.byType(NotePreviewPane), findsOneWidget);
      expect(container.read(selectedNoteIdProvider), 'note-1');

      // 2. 1000 (Expanded: Dual-pane)
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpWidget(buildWithCurrentSize(const Size(1000, 800)));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopNavigationSidebar), findsNothing);
      expect(find.byType(NotePreviewPane), findsOneWidget);
      expect(container.read(selectedNoteIdProvider), 'note-1');

      // 3. 700 (Medium: Single-pane with wide shell, dual-pane begins at expanded >= 840)
      tester.view.physicalSize = const Size(700, 800);
      await tester.pumpWidget(buildWithCurrentSize(const Size(700, 800)));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopNavigationSidebar), findsNothing);
      expect(find.byType(NotePreviewPane), findsNothing);
      expect(container.read(selectedNoteIdProvider), 'note-1');

      // 4. 400 (Compact: Single-pane)
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(buildWithCurrentSize(const Size(400, 800)));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopNavigationSidebar), findsNothing);
      expect(find.byType(NotePreviewPane), findsNothing);
      expect(container.read(selectedNoteIdProvider), 'note-1');
    });

    testWidgets(
        'selection behavior: quiet placeholder when null, selecting note loads pane',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesListProvider
              .overrideWith((ref) => Stream.value([testNote1, testNote2])),
          checklistItemsRevisionProvider
              .overrideWith((ref) => const Stream<void>.empty()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: NotePreviewPane(isDesktopEditor: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing selected shows placeholder
      expect(find.text('Select a note'), findsOneWidget);

      // Select note-1
      container.read(selectedNoteIdProvider.notifier).state = 'note-1';
      await tester.pumpAndSettle();

      expect(find.text('First Note Title'), findsOneWidget);
      expect(find.text('Select a note'), findsNothing);

      // Delete note-1: pane clears
      await noteRepo.softDelete('note-1');
      container.read(selectedNoteIdProvider.notifier).state = null;
      await tester.pumpAndSettle();

      expect(find.text('Select a note'), findsOneWidget);
    });
  });
}
