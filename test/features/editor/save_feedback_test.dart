import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_title.dart';

void main() {
  final now = DateTime(2026, 11, 23, 16, 30);
  final unlockedNote = Note(
    id: 'unlocked-1',
    title: 'Regular Note',
    type: NoteType.text,
    pinned: false,
    locked: false,
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
  });
}
