import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/widgets/wiki_link_autocomplete.dart';

void main() {
  group('extractWikiLinkQuery', () {
    test('returns null when no [[ precedes cursor', () {
      expect(extractWikiLinkQuery('hello world', 5), isNull);
      expect(extractWikiLinkQuery('[single', 7), isNull);
    });

    test('extracts empty query right after [[', () {
      final match = extractWikiLinkQuery('See [[', 6);
      expect(match, isNotNull);
      expect(match!.startOffset, 4);
      expect(match.query, '');
      expect(match.prefixLength, 2);
    });

    test('extracts partial query after [[', () {
      final match = extractWikiLinkQuery('Check [[proj plan', 17);
      expect(match, isNotNull);
      expect(match!.startOffset, 6);
      expect(match.query, 'proj plan');
      expect(match.prefixLength, 11);
    });

    test('returns null after closing ]]', () {
      expect(extractWikiLinkQuery('See [[Note]] more', 17), isNull);
    });

    test('returns null across newline', () {
      expect(extractWikiLinkQuery('See [[\nnext line', 16), isNull);
    });
  });

  group('WikiLinkAutocomplete widget', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows filtered suggestions and inserts link on tap',
        (tester) async {
      final repo = NoteRepository(db);
      final target = await repo.createNote(
        title: 'Project Roadmap',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.createNote(
        title: 'Grocery List',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      final editorState = EditorState(
        document: Document.blank(withInitialText: true),
      );
      final node = editorState.getNodeAtPath([0])!;
      final tx = editorState.transaction;
      tx.insertText(node, 0, 'See [[pro');
      tx.afterSelection = Selection.collapsed(
        Position(path: const [0], offset: 9),
      );
      await editorState.apply(tx);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: WikiLinkAutocomplete(
                editorState: editorState,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Link matching "pro"'), findsOneWidget);
      expect(find.text('Project Roadmap'), findsOneWidget);
      expect(find.text('Grocery List'), findsNothing);

      await tester.tap(find.text('Project Roadmap'));
      await tester.pumpAndSettle();

      final updatedNode = editorState.getNodeAtPath([0])!;
      expect(updatedNode.delta!.toPlainText(), 'See Project Roadmap');
      final attrs = updatedNode.delta!.toJson().last['attributes'] as Map?;
      expect(attrs?['href'], noteLinkUri(target.id));
      expect(find.text('Link matching "pro"'), findsNothing);
    });
  });
}
