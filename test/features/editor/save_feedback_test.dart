import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_autosave.dart';
import 'package:nook/features/editor/editor_title.dart';

void main() {
  final now = DateTime(2026, 11, 23, 16, 30);
  final unlockedNote = Note(
    id: 'unlocked-1',
    title: 'Regular Note',
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

  final lockedNote = Note(
    id: 'locked-1',
    title: 'Secret Vault Note',
    type: NoteType.text,
    pinned: false,
    locked: true,
    archived: false,
    deleted: false,
    syncVersion: 1,
    deviceOriginId: 'local',
    createdAt: now,
    updatedAt: now,
  );

  final theme = ThemeData.light();

  group('Step 7 — Save Feedback & Locked Notes Indicator', () {
    testWidgets('ResponsiveEditorAppBar shows "Saved" when isSaved is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: ResponsiveEditorAppBar(
                noteScheme: theme.colorScheme,
                dynamicTextTheme: theme.textTheme,
                title: 'Testing Saved',
                saving: false,
                isSaved: true,
                pinned: false,
                note: unlockedNote,
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
              ),
            ),
          ),
        ),
      );

      expect(find.text('Saved'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon &&
            w.icon == HugeIcons.strokeRoundedCheckmarkCircle02),
        findsOneWidget,
      );
    });

    testWidgets(
        'ResponsiveEditorAppBar shows locked icon/badge when note.locked is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: ResponsiveEditorAppBar(
                noteScheme: theme.colorScheme,
                dynamicTextTheme: theme.textTheme,
                title: 'Vault Note',
                saving: false,
                pinned: false,
                note: lockedNote,
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
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLock),
        findsOneWidget,
      );
      expect(find.text('Locked'), findsOneWidget);
    });

    test('EditorAutosaveController notifies statusVersion on dirty/clean state',
        () {
      final controller = EditorAutosaveController();
      var notifications = 0;
      controller.statusVersion.addListener(() => notifications++);

      expect(controller.isDirty, isFalse);
      controller.markDirty();
      expect(controller.isDirty, isTrue);
      expect(notifications, 1);

      controller.markClean();
      expect(controller.isDirty, isFalse);
      expect(notifications, 2);
      controller.dispose(
        editorState: null,
        note: null,
        currentTitle: '',
        db: null,
        dirty: false,
      );
    });
  });
}
