import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/reminder_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/data/tables/reminders.dart';
import 'package:nook/features/editor/widgets/backlinks_panel.dart';
import 'package:nook/features/editor/widgets/editor_outline.dart';
import 'package:nook/features/editor/widgets/note_reminders_sheet.dart';
import 'package:nook/features/security/widgets/lock_illustration.dart';

class _FakeReminderScheduler implements ReminderScheduler {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelForNote(String noteId) async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required ReminderRepeat repeat,
  }) async {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
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
      if (isButton && !hasLabel) {
        errors.add('Interactive node ${node.id} (${node.toStringShort()}) '
            'missing a label. rect=${node.rect}');
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

  testWidgets('EditorOutlineSheet exposes labeled interactive elements',
      (tester) async {
    final handle = tester.ensureSemantics();
    final doc = Document(
      root: pageNode(children: [
        headingNode(level: 1, text: 'Main Header'),
        headingNode(level: 2, text: 'Sub Header'),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorOutlineSheet(
            document: doc,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Main Header'), findsOneWidget);
    expect(find.text('Sub Header'), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('NoteRemindersSheet exposes labeled interactive elements',
      (tester) async {
    final handle = tester.ensureSemantics();
    final noteRepo = NoteRepository(db);
    final note = await noteRepo.createNote(
      title: 'Doctor Appt',
      type: NoteType.text,
      deviceOriginId: 'local',
    );

    final reminderRepo = ReminderRepository(
      db,
      scheduler: _FakeReminderScheduler(),
    );
    await reminderRepo.create(
      noteId: note.id,
      title: 'Check in with clinic',
      fireAt: DateTime.now().add(const Duration(hours: 2)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: NoteRemindersSheet(
              noteId: note.id,
              noteTitle: note.title,
              scheduler: _FakeReminderScheduler(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check in with clinic'), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('BacklinksPanel exposes labeled interactive elements',
      (tester) async {
    final handle = tester.ensureSemantics();
    final noteRepo = NoteRepository(db);
    final targetNote = await noteRepo.createNote(
      title: 'Target Note',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    final sourceNote = await noteRepo.createNote(
      title: 'Referencing Note',
      type: NoteType.text,
      deviceOriginId: 'local',
      deltaContent:
          '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"See "},{"insert":"Target","attributes":{"href":"nook://note/${targetNote.id}"}}]}}]}}',
    );

    final linkRepo = NoteLinkRepository(db);
    await linkRepo.rebuildForNote(sourceNote.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BacklinksPanel(note: targetNote),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Referencing Note'), findsOneWidget);
    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });

  testWidgets('LockIllustration renders accessible tree', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: LockIllustration(
              primaryIcon: HugeIcons.strokeRoundedLock,
              badgeIcon: HugeIcons.strokeRoundedFingerPrint,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expectEveryInteractiveNodeLabeled(tester);
    expectTouchTargetsAtLeast48(tester);
    handle.dispose();
  });
}
