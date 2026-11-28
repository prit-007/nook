@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/theme/app_theme.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';
import 'package:nook/features/home/widgets/note_banner_card.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';
import 'package:nook/features/notebooks/widgets/notebook_card.dart';

void main() {
  group(
      'Card family golden matrix (NoteBannerCard, NoteDoodleCard, NotebookCard)',
      () {
    testWidgets('NoteBannerCard renders across seed, pinned, and locked states',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      for (final (pinned, locked, seedHex) in [
        (false, false, '#4CAF50'),
        (true, false, '#FF7043'),
        (true, true, '#5C6BC0'),
      ]) {
        final note = Note(
          id: 'banner-$pinned-$locked',
          title: 'Banner Note',
          type: NoteType.text,
          plainText: 'Body preview text',
          colorSeed: seedHex,
          pinned: pinned,
          locked: locked,
          archived: false,
          deleted: false,
          syncVersion: 1,
          deviceOriginId: 'dev-1',
          fontStyle: 'auto',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: buildLightTheme(NookColors.seeds.first),
              home: Scaffold(
                body: SizedBox(
                  width: 360,
                  height: 200,
                  child: NoteBannerCard(
                    note: note,
                    preloadedMetadata: const NoteCardMetadata(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(NoteBannerCard), findsOneWidget);
        if (locked) {
          expect(find.text('Locked note — unlock to view'), findsOneWidget);
        }
      }
    });

    testWidgets('NoteDoodleCard renders across seed, pinned, and locked states',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      for (final (pinned, locked, seedHex) in [
        (false, false, '#26A69A'),
        (true, true, '#7E57C2'),
      ]) {
        final note = Note(
          id: 'doodle-$pinned-$locked',
          title: 'Doodle Sketch',
          type: NoteType.doodle,
          colorSeed: seedHex,
          pinned: pinned,
          locked: locked,
          archived: false,
          deleted: false,
          syncVersion: 1,
          deviceOriginId: 'dev-1',
          fontStyle: 'auto',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: buildLightTheme(NookColors.seeds.first),
              home: Scaffold(
                body: SizedBox(
                  width: 360,
                  height: 180,
                  child: NoteDoodleCard(
                    note: note,
                    preloadedMetadata: const NoteCardMetadata(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(NoteDoodleCard), findsOneWidget);
      }
    });

    testWidgets('NotebookCard renders across color seeds', (tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      for (final seedHex in ['#4CAF50', '#FF7043', '#5C6BC0']) {
        final notebook = Notebook(
          id: 'nb-$seedHex',
          name: 'Work Notes',
          icon: 'folder',
          colorSeed: seedHex,
          sortOrder: 0,
          deleted: false,
          createdAt: DateTime(2026),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: buildLightTheme(NookColors.seeds.first),
              home: Scaffold(
                body: SizedBox(
                  width: 240,
                  height: 220,
                  child: NotebookCard(
                    notebook: notebook,
                    noteCount: 7,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(NotebookCard), findsOneWidget);
        expect(find.text('Work Notes'), findsOneWidget);
      }
    });
  });
}
