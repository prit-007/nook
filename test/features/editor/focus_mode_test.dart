import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/note_editor_screen.dart';

void main() {
  final now = DateTime(2026, 11, 23, 16, 0);
  final testNote = Note(
    id: 'focus-note-1',
    title: 'Focus Test',
    type: NoteType.text,
    pinned: false,
    locked: false,
    archived: false,
    deleted: false,
    syncVersion: 1,
    deviceOriginId: 'local',
    createdAt: now,
    updatedAt: now,
  );
  final theme = ThemeData.light();

  Widget buildAppBar({
    bool showFocusMode = true,
    VoidCallback? onEnterFocusMode,
  }) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: ResponsiveEditorAppBar(
            noteScheme: theme.colorScheme,
            dynamicTextTheme: theme.textTheme,
            title: 'Focus',
            saving: false,
            pinned: false,
            note: testNote,
            onBack: () {},
            onInsertImage: () {},
            onInsertDoodle: () {},
            onTogglePin: () {},
            onExport: () {},
            onMoreOptions: () {},
            canUndo: false,
            canRedo: false,
            onUndo: () {},
            onRedo: () {},
            onShowOutline: () {},
            showFocusMode: showFocusMode,
            onEnterFocusMode: onEnterFocusMode,
          ),
        ),
      ),
    );
  }

  group('Step 6 — Focus mode: app bar action', () {
    testWidgets('wide layout shows a focus-mode button that fires the callback',
        (tester) async {
      var fired = false;
      await tester.pumpWidget(
        buildAppBar(onEnterFocusMode: () => fired = true),
      );
      await tester.pumpAndSettle();

      final focusButton = find.byTooltip('Focus mode');
      expect(focusButton, findsOneWidget);

      await tester.tap(focusButton);
      await tester.pumpAndSettle();
      expect(fired, isTrue);
    });

    testWidgets('wide layout focus button uses the view icon', (tester) async {
      await tester.pumpWidget(buildAppBar(onEnterFocusMode: () {}));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedView),
        findsOneWidget,
      );
    });

    testWidgets('focus action is hidden while already in focus mode',
        (tester) async {
      await tester.pumpWidget(
        buildAppBar(showFocusMode: false, onEnterFocusMode: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Focus mode'), findsNothing);
    });

    testWidgets('narrow layout exposes focus mode inside the overflow menu',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var fired = false;
      await tester.pumpWidget(
        buildAppBar(onEnterFocusMode: () => fired = true),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Focus mode'), findsNothing);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Focus mode'));
      await tester.pumpAndSettle();
      expect(fired, isTrue);
    });
  });

  group('Step 6 — Focus mode: NoteEditorScreen integration', () {
    late AppDatabase db;
    late NoteRepository noteRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      noteRepo = NoteRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildScreen({required String noteId}) {
      return ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: NoteEditorScreen(noteId: noteId),
        ),
      );
    }

    Future<String> pumpScreen(WidgetTester tester) async {
      final note = await noteRepo.createNote(
        title: 'Focussable',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await tester.pumpWidget(buildScreen(noteId: note.id));
      await tester.pumpAndSettle();
      return note.id;
    }

    testWidgets('entering focus mode hides the app bar and shows exit action',
        (tester) async {
      await pumpScreen(tester);

      // Normal state: back button (app bar) present, no exit action.
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Exit focus mode'), findsNothing);

      await tester.tap(find.byTooltip('Focus mode'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byTooltip('Exit focus mode'), findsOneWidget);
    });

    testWidgets('exiting focus mode restores the app bar', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Focus mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Exit focus mode'), findsOneWidget);

      await tester.tap(find.byTooltip('Exit focus mode'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Exit focus mode'), findsNothing);
    });
  });
}
