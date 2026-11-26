import 'package:appflowy_editor/appflowy_editor.dart';
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
    id: 'outline-note-1',
    title: 'Outline Wiring',
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

  Widget buildApp({required VoidCallback onShowOutline}) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: ResponsiveEditorAppBar(
            noteScheme: theme.colorScheme,
            dynamicTextTheme: theme.textTheme,
            title: 'Outline Test',
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
            onShowOutline: onShowOutline,
          ),
        ),
      ),
    );
  }

  group('Step 5 — Outline wiring: app bar action', () {
    testWidgets(
        'wide layout shows an outline IconButton that fires the callback',
        (tester) async {
      // Default test surface is 800x600 → wide layout (isNarrow == false).
      var fired = false;
      await tester.pumpWidget(
        buildApp(onShowOutline: () => fired = true),
      );
      await tester.pumpAndSettle();

      final outlineButton = find.byTooltip('Document outline');
      expect(outlineButton, findsOneWidget);

      await tester.tap(outlineButton);
      await tester.pumpAndSettle();
      expect(fired, isTrue);
    });

    testWidgets('wide layout outline button uses the outline icon',
        (tester) async {
      await tester.pumpWidget(
        buildApp(onShowOutline: () {}),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedMenuSquare),
        findsWidgets,
      );
    });

    testWidgets('narrow layout exposes outline inside the overflow menu',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var fired = false;
      await tester.pumpWidget(
        buildApp(onShowOutline: () => fired = true),
      );
      await tester.pumpAndSettle();

      // Wide layout would show a direct IconButton; narrow must go through
      // the overflow menu instead.
      expect(find.byTooltip('Document outline'), findsNothing);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Document outline'));
      await tester.pumpAndSettle();
      expect(fired, isTrue);
    });
  });

  group('Step 5 — Outline wiring: NoteEditorScreen integration', () {
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

    Future<EditorState> pumpScreenWithHeading(
      WidgetTester tester, {
      required String headingText,
    }) async {
      final note = await noteRepo.createNote(
        title: 'Outlined',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await tester.pumpWidget(buildScreen(noteId: note.id));
      await tester.pumpAndSettle();

      final editorState = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      insertBlockNode(
        editorState,
        headingNode(text: headingText, level: 1),
      );
      await tester.pumpAndSettle();
      return editorState;
    }

    testWidgets('screen exposes outline action that lists the note\'s headings',
        (tester) async {
      await pumpScreenWithHeading(tester, headingText: 'Section One');

      await tester.tap(find.byTooltip('Document outline'));
      await tester.pumpAndSettle();

      expect(find.text('Document Outline'), findsOneWidget);
      expect(find.text('Section One'), findsOneWidget);

      // Flush the 2s "Saved" feedback Future.delayed scheduled by the
      // autosave that ran after inserting the heading.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('selecting a heading moves the cursor to that heading',
        (tester) async {
      final editorState =
          await pumpScreenWithHeading(tester, headingText: 'Jump Target');

      final heading = editorState.document.root.children
          .firstWhere((n) => n.type == HeadingBlockKeys.type);
      final headingPath = List<int>.from(heading.path);

      await tester.tap(find.byTooltip('Document outline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jump Target'));
      await tester.pumpAndSettle();

      expect(editorState.selection, isNotNull);
      expect(editorState.selection!.start.path, headingPath);

      // Flush the 2s "Saved" feedback Future.delayed scheduled by the
      // autosave that ran after inserting the heading.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });
}
