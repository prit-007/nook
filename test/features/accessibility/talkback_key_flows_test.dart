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
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/search_screen.dart';
import 'package:nook/features/settings/settings_privacy_screen.dart';
import 'package:nook/features/settings/settings_screen.dart';
import 'package:nook/features/sync_ui/sync_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    PackageInfo.setMockInitialValues(
      appName: 'nook',
      packageName: 'com.devparadise.nook',
      version: '0.9.6',
      buildNumber: '6',
      buildSignature: '',
      installerStore: null,
    );
  });

  tearDown(() async {
    await db.close();
  });

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
        errors.add('Interactive node ${node.id} (${node.toStringShort()}) '
            'missing a label. rect=${node.rect}');
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

  Widget wrapScreen(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesListProvider.overrideWith((ref) => Stream.value(<Note>[])),
        themePreferenceProvider.overrideWith(
          (_) => ThemePreference(themeMode: ThemeMode.light)
            ..setReduceMotion(true),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('TalkBack key flow 1: Home screen navigation is fully labeled',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrapScreen(const HomeScreen(animate: false)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Scaffold), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('TalkBack key flow 2: Search flow is fully labeled with results',
      (tester) async {
    final handle = tester.ensureSemantics();
    final noteRepo = NoteRepository(db);
    await noteRepo.createNote(
      title: 'Meeting Notes',
      type: NoteType.text,
      deviceOriginId: 'local',
      plainText: 'Discuss Q4 roadmap and security audit.',
    );

    await tester.pumpWidget(wrapScreen(const SearchScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Meeting');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Meeting Notes'), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('TalkBack key flow 3: Sync screen mode toggles are accessible',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrapScreen(const SyncScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Send to Device'), findsOneWidget);
    expect(find.text('Receive Notes'), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('TalkBack key flow 4: Settings & Privacy policy flows accessible',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrapScreen(const SettingsScreen()));
    await tester.pumpAndSettle();

    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);

    await tester.pumpWidget(wrapScreen(const SettingsPrivacyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Privacy Policy'), findsWidgets);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });
}
