import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/theme/app_theme.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/core/widgets/empty_state.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/card_tag_pill.dart';
import 'package:nook/features/home/widgets/note_banner_card.dart';
import 'package:nook/features/home/widgets/note_card.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';
import 'package:nook/features/home/widgets/note_minimal_card.dart';
import 'package:nook/features/notebooks/widgets/notebook_card.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithTheme(
    Widget child, {
    Color seed = NookColors.violet,
    bool isDark = false,
  }) {
    final theme = isDark ? buildDarkTheme(seed) : buildLightTheme(seed);
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [child],
          ),
        ),
      ),
    );
  }

  group('Component Gallery & Design System Compliance', () {
    testWidgets('Renders core component gallery without layout overflows',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final note = Note(
        id: 'gallery-note-1',
        title: 'Component Gallery Note',
        plainText:
            'Sample editorial content demonstrating typography and tokens.',
        type: NoteType.text,
        colorSeed: '#6750A4',
        pinned: false,
        locked: false,
        archived: false,
        deleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deviceOriginId: 'device-test',
        syncVersion: 0,
      );

      final notebook = Notebook(
        id: 'gallery-nb-1',
        name: 'Design System',
        colorSeed: '#6750A4',
        icon: 'notebook',
        sortOrder: 0,
        createdAt: DateTime.now(),
        deleted: false,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Tag Pills
              const Row(
                children: [
                  CardTagPill(label: 'Design', colorSeed: '#6750A4'),
                  SizedBox(width: 8),
                  CardTagPill(label: 'Research', colorSeed: '#2E6C4D'),
                  SizedBox(width: 8),
                  CardTagOverflowPill(count: 3),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Notebook Card (portrait book ratio)
              SizedBox(
                height: 280,
                width: 180,
                child: NotebookCard(notebook: notebook),
              ),
              const SizedBox(height: 16),

              // 3. NoteCard (requires bounded height due to content preview Expanded)
              SizedBox(
                width: 320,
                height: 180,
                child: NoteCard(note: note),
              ),
              const SizedBox(height: 16),

              // 4. NoteBannerCard
              SizedBox(
                width: 340,
                child: NoteBannerCard(note: note),
              ),
              const SizedBox(height: 16),

              // 5. NoteMinimalCard
              SizedBox(
                width: 320,
                child: NoteMinimalCard(note: note),
              ),
              const SizedBox(height: 16),

              // 6. NoteDoodleCard
              SizedBox(
                width: 320,
                child: NoteDoodleCard(
                  note: note.copyWith(type: NoteType.doodle),
                ),
              ),
              const SizedBox(height: 16),

              // 7. Empty State
              const EmptyState(
                icon: HugeIcons.strokeRoundedBook01,
                title: 'No Notebooks Yet',
                subtitle: 'Organize your thoughts into distinct notebooks.',
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify that components render
      expect(find.byType(CardTagPill), findsNWidgets(2));
      expect(find.byType(CardTagOverflowPill), findsOneWidget);
      expect(find.byType(NotebookCard), findsOneWidget);
      expect(find.byType(NoteCard), findsOneWidget);
      expect(find.byType(NoteBannerCard), findsOneWidget);
      expect(find.byType(NoteMinimalCard), findsOneWidget);
      expect(find.byType(NoteDoodleCard), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('Tokens extension is accessible and honors minimums in tree',
        (tester) async {
      late NookTokens capturedTokens;

      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              capturedTokens = context.tokens;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(capturedTokens.fontFloor, greaterThanOrEqualTo(12.0));
      expect(capturedTokens.minTapTarget, greaterThanOrEqualTo(48.0));
      expect(capturedTokens.radiusPill, equals(999.0));
    });
  });
}
