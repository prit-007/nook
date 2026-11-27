import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/notebooks/controllers/collection_tree_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CollectionTreeController', () {
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

    test('flattens tree with depth respecting expand/collapse', () async {
      final controller = CollectionTreeController();
      controller.setNodes(nodes);

      // By default all root nodes visible, children collapsed unless expanded
      var visible = controller.flattenedVisibleRows;
      expect(visible.map((r) => r.id).toList(), ['work', 'personal']);
      expect(visible[0].depth, 0);
      expect(visible[0].hasChildren, isTrue);
      expect(visible[0].isExpanded, isFalse);

      // Expand 'work'
      controller.toggleExpand('work');
      visible = controller.flattenedVisibleRows;
      expect(visible.map((r) => r.id).toList(),
          ['work', 'projects', 'meetings', 'personal']);
      expect(visible[1].depth, 1);
      expect(visible[1].id, 'projects');
      expect(visible[1].hasChildren, isTrue);
      expect(visible[1].isExpanded, isFalse);

      // Expand 'projects'
      controller.toggleExpand('projects');
      visible = controller.flattenedVisibleRows;
      expect(visible.map((r) => r.id).toList(),
          ['work', 'projects', 'nook', 'meetings', 'personal']);
      expect(visible[2].depth, 2);
      expect(visible[2].id, 'nook');
      expect(visible[2].hasChildren, isFalse);
    });

    test('persists expanded state to SharedPreferences across restarts',
        () async {
      SharedPreferences.setMockInitialValues({
        CollectionTreeController.prefsKey: ['work', 'projects'],
      });

      final controller = await CollectionTreeController.create();
      controller.setNodes(nodes);

      final visible = controller.flattenedVisibleRows;
      expect(visible.map((r) => r.id).toList(),
          ['work', 'projects', 'nook', 'meetings', 'personal']);

      // Collapse work
      controller.collapse('work');
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(CollectionTreeController.prefsKey);
      expect(saved, isNot(contains('work')));
    });

    test(
        'keyboard navigation: arrows move, expand, collapse, and navigate to parent',
        () {
      final controller = CollectionTreeController();
      controller.setNodes(nodes);
      controller.expand('work');
      controller.expand('projects');
      // Visible: work (0), projects (1), nook (2), meetings (3), personal (4)

      controller.selectIndex(0); // work
      expect(controller.selectedId, 'work');

      controller.moveNext(); // Down
      expect(controller.selectedId, 'projects');

      controller.moveNext(); // Down
      expect(controller.selectedId, 'nook');

      // Left on leaf 'nook' moves selection to parent 'projects'
      controller.handleLeftArrow();
      expect(controller.selectedId, 'projects');

      // Left on expanded 'projects' collapses it
      controller.handleLeftArrow();
      expect(controller.isExpanded('projects'), isFalse);
      expect(controller.selectedId, 'projects');

      // Right on collapsed 'projects' expands it
      controller.handleRightArrow();
      expect(controller.isExpanded('projects'), isTrue);
    });
  });
}
