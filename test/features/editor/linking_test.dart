import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_toolbar.dart';
import 'package:nook/features/editor/widgets/backlinks_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 11, 23, 15, 0);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 4 — Linking: [[ Autocomplete Shortcut', () {
    test('formatDoubleBracketToNoteLink detects [[ and calls trigger',
        () async {
      bool triggered = false;
      final shortcut = formatDoubleBracketToNoteLink(
        onTriggerNoteLink: (editorState) {
          triggered = true;
        },
      );

      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: '['),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      // Place cursor right after the first '['
      editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: 1),
      );

      final handled = await shortcut.handler(editorState);
      expect(handled, isTrue);
      expect(triggered, isTrue);
    });

    test('insertNoteLinkAtSelection inserts note link and deletes prefix',
        () async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'Check out ['),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: 11),
      );

      insertNoteLinkAtSelection(
        editorState,
        noteId: 'target-note-42',
        title: 'Project Roadmap',
        deletePrefixLength: 1,
      );

      final firstNode = editorState.document.root.children.first;
      final plainText = firstNode.delta?.toPlainText() ?? '';
      expect(plainText, equals('Check out Project Roadmap'));

      // Verify the link href attribute
      final json = firstNode.delta?.toJson() as List<dynamic>;
      Map<String, dynamic>? linkOp;
      for (final op in json) {
        if (op is Map &&
            op['insert'] == 'Project Roadmap' &&
            op['attributes']?['href'] == 'nook://note/target-note-42') {
          linkOp = Map<String, dynamic>.from(op);
          break;
        }
      }
      expect(linkOp, isNotNull);
    });
  });

  group('Step 4 — Linking: BacklinksPanel & Related Notes', () {
    testWidgets('BacklinksPanel renders empty state when no incoming links',
        (tester) async {
      final targetNote = Note(
        id: 'isolated-note-1',
        title: 'Isolated Note',
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BacklinksPanel(note: targetNote),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No incoming backlinks'), findsOneWidget);
    });

    testWidgets('BacklinksPanel renders incoming backlinks and related notes',
        (tester) async {
      final target = await NoteRepository(db).createNote(
        title: 'Target Note',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      final source = await NoteRepository(db).createNote(
        title: 'Source Note',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await NoteRepository(db).updateContent(
        source.id,
        deltaContent:
            '{"document":{"children":[{"type":"paragraph","delta":[{"insert":"See target ","attributes":{"href":"nook://note/${target.id}"}}]}]}}',
        plainText: 'See target',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BacklinksPanel(note: target),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Referenced in 1 note'), findsOneWidget);
      expect(find.text('Source Note'), findsOneWidget);
    });
  });
}
