import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/providers/theme_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/search_screen.dart';
import 'package:nook/features/notebooks/notebooks_screen.dart';
import 'package:nook/features/tags/tags_screen.dart';
import 'package:nook/features/tags/tag_detail_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() async => db.close());

  Widget wrap(Widget child, {bool reduceMotion = true}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          themePreferenceProvider.overrideWith(
            (_) => ThemePreference(themeMode: ThemeMode.light)
              ..setReduceMotion(reduceMotion),
          ),
        ],
        child: MaterialApp(home: child),
      );

  /// Asserts that every render object in the tree has a semantic label when
  /// it is marked interactive (has a tap/button semantics) — catches bare
  /// GestureDetectors that a screen reader could not announce.
  void expectEveryInteractiveNodeLabeled(WidgetTester tester) {
    final root =
        tester.binding.rootPipelineOwner.semanticsOwner!.rootSemanticsNode;
    final errors = <String>[];

    bool hasLabelDeep(SemanticsNode node, {bool ancestorHasLabel = false}) {
      final data = node.getSemanticsData();
      if (ancestorHasLabel ||
          data.label.isNotEmpty ||
          data.tooltip.isNotEmpty) {
        return true;
      }
      var found = false;
      node.visitChildren((child) {
        found =
            hasLabelDeep(child, ancestorHasLabel: ancestorHasLabel) || found;
        return true;
      });
      return found;
    }

    void visit(SemanticsNode? node, bool ancestorHasLabel) {
      if (node == null || node.isMergedIntoParent) return;
      final data = node.getSemanticsData();
      final isButton =
          data.flagsCollection.isButton || data.hasAction(SemanticsAction.tap);
      final descendantHasLabel = hasLabelDeep(node);
      final hasLabel = ancestorHasLabel || descendantHasLabel;
      final isFocusable = data.flagsCollection.isFocused != Tristate.none;
      if (isButton && !hasLabel) {
        final rect = node.rect;
        errors.add('Interactive node ${node.id} (${node.toStringShort()}) '
            'missing a label. rect=$rect');
      }
      if (isFocusable && !hasLabel && !isButton) {
        errors.add('Focusable node ${node.id} (${node.toStringShort()}) is '
            'missing a label');
      }
      node.visitChildren((child) {
        visit(child, ancestorHasLabel || descendantHasLabel);
        return true;
      });
    }

    visit(root, false);
    expect(errors, isEmpty, reason: errors.join('\n'));
  }

  /// Asserts every interactive semantics node (tap/long-press/button) has a
  /// touch target of at least [minSize]x[minSize] logical pixels — the
  /// WCAG 2.5.5 / Material minimum of 48x48 — to make taps reliable for
  /// low-vision and motor-impaired users.
  void expectTouchTargetsAtLeast48(WidgetTester tester, {double minSize = 48}) {
    final root =
        tester.binding.rootPipelineOwner.semanticsOwner!.rootSemanticsNode;
    final errors = <String>[];

    bool visit(SemanticsNode? node) {
      if (node == null || node.isMergedIntoParent) return true;
      final data = node.getSemanticsData();
      final isInteractive = data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress) ||
          data.flagsCollection.isButton;
      if (isInteractive) {
        final bound = node.rect;
        if (bound.isFinite &&
            bound.width > 0 &&
            bound.height > 0 &&
            (bound.width < minSize || bound.height < minSize)) {
          errors.add(
            'Touch target ${node.id} (${node.toStringShort()}) is '
            '${bound.width.toInt()}x${bound.height.toInt()} '
            '(< $minSize x $minSize)',
          );
        }
      }
      node.visitChildren(visit);
      return true;
    }

    visit(root);
    expect(errors, isEmpty, reason: errors.join('\n'));
  }

  testWidgets('home screen exposes labeled interactive elements',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesListProvider.overrideWith((ref) => Stream.value(<Note>[])),
        ],
        child: const MaterialApp(home: HomeScreen(animate: false)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Search thoughts, doodles, checklists...',
      ),
      findsOneWidget,
    );
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('search screen exposes labeled interactive elements + results',
      (tester) async {
    final handle = tester.ensureSemantics();
    final noteRepo = NoteRepository(db);
    await noteRepo.createNote(
      title: 'Groceries',
      type: NoteType.text,
      deviceOriginId: 'local',
      plainText: 'Milk and bread',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Groc');
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('notebooks screen exposes labeled interactive elements',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(const NotebooksScreen()));
    await tester.pumpAndSettle();

    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('tags screen exposes labeled interactive elements',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = TagRepository(db);
    await repo.createTag(name: 'Ideas', colorSeed: '#2196F3');

    await tester.pumpWidget(wrap(const TagsScreen()));
    // Empty-state animation would otherwise loop; settle with fixed frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ideas'), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('tag detail screen exposes labeled interactive elements',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = TagRepository(db);
    final tag = await repo.createTag(name: 'Work', colorSeed: '#4CAF50');

    await tester.pumpWidget(
      wrap(TagDetailScreen(tagId: tag.id)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Scaffold), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });
}
