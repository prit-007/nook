import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/app_theme.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/features/notebooks/controllers/collection_tree_controller.dart';
import 'package:nook/features/notebooks/widgets/collection_tree_view.dart';
import 'package:nook/features/notebooks/widgets/mobile_collection_drill_down.dart';
import '../../helpers/ascii_layout.dart';

void main() {
  final nodes = [
    const CollectionTreeNode(
      id: 'work',
      name: 'Work',
      colorSeed: '#111',
      parentId: null,
      noteCount: 12,
      children: [
        CollectionTreeNode(
          id: 'projects',
          name: 'Projects',
          colorSeed: '#222',
          parentId: 'work',
          noteCount: 7,
          children: [
            CollectionTreeNode(
              id: 'nook',
              name: 'Nook',
              colorSeed: '#333',
              parentId: 'projects',
              noteCount: 4,
            ),
          ],
        ),
        CollectionTreeNode(
          id: 'meetings',
          name: 'Meetings',
          colorSeed: '#444',
          parentId: 'work',
          noteCount: 5,
        ),
      ],
    ),
    const CollectionTreeNode(
      id: 'personal',
      name: 'Personal',
      colorSeed: '#555',
      parentId: null,
      noteCount: 9,
    ),
  ];

  Widget buildTreeHarness({
    required CollectionTreeController controller,
    ValueChanged<String>? onSelect,
    void Function(String childId, String? newParentId)? onReparent,
  }) {
    final theme = buildLightTheme(NookColors.seeds.first);
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 600,
          child: CollectionTreeView(
            controller: controller,
            onSelect: onSelect ?? (_) {},
            onReparent: onReparent,
          ),
        ),
      ),
    );
  }

  group('CollectionTreeView', () {
    testWidgets('renders rows with depth indentation and aggregate counts',
        (tester) async {
      final controller = CollectionTreeController();
      controller.setNodes(nodes);
      controller.expand('work');

      await tester.pumpWidget(buildTreeHarness(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Meetings'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // Work aggregate count
      expect(find.text('7'), findsOneWidget); // Projects count
      expect(find.text('5'), findsOneWidget); // Meetings count

      // Verify indentation: Projects row must be indented to the right of Work row
      final workLeft = tester.getTopLeft(find.text('Work')).dx;
      final projectsLeft = tester.getTopLeft(find.text('Projects')).dx;
      expect(projectsLeft, greaterThan(workLeft));
    });

    testWidgets('chevron tap expands and collapses subtree', (tester) async {
      final controller = CollectionTreeController();
      controller.setNodes(nodes);

      await tester.pumpWidget(buildTreeHarness(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Projects'), findsNothing);

      // Tap chevron for Work
      final chevronFinder = find.byKey(const ValueKey('chevron_work'));
      expect(chevronFinder, findsOneWidget);
      await tester.tap(chevronFinder);
      await tester.pumpAndSettle();

      expect(find.text('Projects'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(chevronFinder);
      await tester.pumpAndSettle();

      expect(find.text('Projects'), findsNothing);
    });

    testWidgets('keyboard navigation expands, collapses, and moves selection',
        (tester) async {
      final controller = CollectionTreeController();
      controller.setNodes(nodes);

      await tester.pumpWidget(buildTreeHarness(controller: controller));
      await tester.pumpAndSettle();

      // Focus tree view
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      expect(controller.selectedId, 'work');

      // Right arrow expands 'work'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.isExpanded('work'), isTrue);
      expect(find.text('Projects'), findsOneWidget);

      // Down arrow selects 'projects'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.selectedId, 'projects');

      // Right arrow expands 'projects'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Nook'), findsOneWidget);

      // Down arrow selects 'nook'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.selectedId, 'nook');

      // Left arrow on leaf moves selection back to parent 'projects'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.selectedId, 'projects');

      // Left arrow on expanded 'projects' collapses it
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.isExpanded('projects'), isFalse);
    });

    testWidgets('semantics expose level and expanded state', (tester) async {
      final controller = CollectionTreeController();
      controller.setNodes(nodes);

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildTreeHarness(controller: controller));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byKey(const ValueKey('row_work'))),
        matchesSemantics(
          label: 'Work, level 1',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('ASCII layout snapshot of wide screen tree', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = CollectionTreeController();
      controller.setNodes(nodes);
      controller.expand('work');
      controller.expand('projects');

      await tester.pumpWidget(buildTreeHarness(controller: controller));
      await tester.pumpAndSettle();

      final snap = asciiLayout(
        tester,
        {
          'work': find.byKey(const ValueKey('row_work')),
          'projects': find.byKey(const ValueKey('row_projects')),
          'nook': find.byKey(const ValueKey('row_nook')),
          'meetings': find.byKey(const ValueKey('row_meetings')),
        },
        cols: 60,
        rows: 15,
      );
      expect(snap, isNotEmpty);
      expectLayoutSnap(snap, 'collection_tree_wide');
    });

    testWidgets(
        'MobileCollectionDrillDown navigation and ASCII snap at 400x800',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? tappedCollection;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(NookColors.seeds.first),
          home: Scaffold(
            body: MobileCollectionDrillDown(
              nodes: nodes,
              onSelectCollection: (id) => tappedCollection = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Root level shows Work & Personal
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);

      // Drill into Work
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(tappedCollection, 'work');

      // Breadcrumb shows Work, chips show Projects & Meetings
      expect(find.text('Work'), findsWidgets);
      expect(find.text('Projects · 7'), findsOneWidget);
      expect(find.text('Meetings · 5'), findsOneWidget);

      final snap = asciiLayout(
        tester,
        {
          'drill_down': find.byKey(const Key('mobile_drill_down')),
        },
        cols: 40,
        rows: 12,
      );
      expect(snap, isNotEmpty);
      expectLayoutSnap(snap, 'collection_drill_down_mobile');
    });
  });
}
