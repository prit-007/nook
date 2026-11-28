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
    id: 'readonly-note-1',
    title: 'Read Only',
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
    VoidCallback? onInsertImage,
    VoidCallback? onInsertDoodle,
  }) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: ResponsiveEditorAppBar(
            noteScheme: theme.colorScheme,
            dynamicTextTheme: theme.textTheme,
            title: 'Read Only',
            saving: false,
            pinned: false,
            note: testNote,
            onBack: () {},
            onInsertImage: onInsertImage,
            onInsertDoodle: onInsertDoodle,
            onTogglePin: () {},
            onExport: () {},
            onMoreOptions: () {},
            canUndo: false,
            canRedo: false,
            onUndo: () {},
            onRedo: () {},
            onShowOutline: () {},
            showFocusMode: false,
            onEnterFocusMode: () {},
          ),
        ),
      ),
    );
  }

  group('Step 7 — Read-only mode: insert actions hidden', () {
    testWidgets('insert image button is hidden when no callback',
        (tester) async {
      await tester.pumpWidget(buildAppBar(onInsertImage: null));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedImageAdd01),
        findsNothing,
      );
    });

    testWidgets('insert image button shows when callback provided',
        (tester) async {
      await tester.pumpWidget(buildAppBar(onInsertImage: () {}));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedImageAdd01),
        findsOneWidget,
      );
    });

    testWidgets('insert doodle button is hidden when no callback',
        (tester) async {
      await tester.pumpWidget(buildAppBar(onInsertDoodle: null));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedDrawingMode),
        findsNothing,
      );
    });
  });

  group('Step 7 — Read-only mode: NoteEditorScreen integration', () {
    late AppDatabase db;
    late NoteRepository noteRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      noteRepo = NoteRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildScreen(WidgetTester tester, {required String noteId}) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      return ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: NoteEditorScreen(noteId: noteId),
        ),
      );
    }

    Future<bool> editorEditable(WidgetTester tester) async {
      final editorWidget =
          tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      return editorWidget.editable;
    }

    testWidgets('toggling read-only makes the editor non-editable',
        (tester) async {
      final note = await noteRepo.createNote(
        title: 'Readonly',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await tester.pumpWidget(buildScreen(tester, noteId: note.id));
      await tester.pumpAndSettle();

      expect(await editorEditable(tester), isTrue);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      final readOnlyTile = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Read-only mode');
      await tester.tap(readOnlyTile);
      await tester.pumpAndSettle();
      expect(await editorEditable(tester), isFalse);

      await tester.tap(readOnlyTile);
      await tester.pumpAndSettle();
      expect(await editorEditable(tester), isTrue);
    });

    testWidgets('read-only hides the insert image action', (tester) async {
      final note = await noteRepo.createNote(
        title: 'Readonly',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await tester.pumpWidget(buildScreen(tester, noteId: note.id));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      final readOnlyTile = find.byWidgetPredicate((w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data == 'Read-only mode');
      await tester.tap(readOnlyTile);
      await tester.pumpAndSettle();

      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedImageAdd01),
          findsNothing);
    });
  });
}
