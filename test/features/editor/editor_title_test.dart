import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_title.dart';

void main() {
  final now = DateTime(2026, 11, 23, 14, 30);
  final testNote = Note(
    id: 'test-note-1',
    title: 'My Fantastic Note',
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

  Widget buildTitle({
    String title = 'My Fantastic Note',
    bool saving = false,
    bool pinned = false,
    Note? note,
    String? notebookName,
    List<String> tagNames = const [],
    int wordCount = 42,
    int readingTime = 1,
    VoidCallback? onBack,
    VoidCallback? onTogglePin,
  }) {
    final theme = ThemeData.light();
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: ResponsiveEditorAppBar(
            noteScheme: theme.colorScheme,
            dynamicTextTheme: theme.textTheme,
            title: title,
            saving: saving,
            pinned: pinned,
            note: note ?? testNote,
            onBack: onBack ?? () {},
            onInsertImage: () {},
            onInsertDoodle: () {},
            onTogglePin: onTogglePin ?? () {},
            onExport: () {},
            onMoreOptions: () {},
            canUndo: true,
            canRedo: false,
            onUndo: () {},
            onRedo: () {},
            notebookName: notebookName,
            tagNames: tagNames,
            wordCount: wordCount,
            readingTime: readingTime,
          ),
        ),
      ),
    );
  }

  group('ResponsiveEditorAppBar', () {
    testWidgets('renders note title and Text note type badge', (tester) async {
      await tester.pumpWidget(buildTitle());
      expect(find.text('My Fantastic Note'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
    });

    testWidgets('renders New Note fallback when title is empty',
        (tester) async {
      await tester.pumpWidget(buildTitle(title: ''));
      expect(find.text('New Note'), findsOneWidget);
    });

    testWidgets('renders Saving... when saving is true', (tester) async {
      await tester.pumpWidget(buildTitle(saving: true));
      expect(find.text('Saving...'), findsOneWidget);
    });

    testWidgets('renders word count and reading time', (tester) async {
      await tester.pumpWidget(buildTitle(wordCount: 150, readingTime: 1));
      expect(find.text('150 words \u00b7 1 min'), findsOneWidget);
    });

    testWidgets('toggles pin icon when pinned is true/false', (tester) async {
      await tester.pumpWidget(buildTitle(pinned: true));
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPinOff),
        findsOneWidget,
      );

      await tester.pumpWidget(buildTitle(pinned: false));
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPin),
        findsOneWidget,
      );
    });
  });
}
