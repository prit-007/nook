import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/database.dart';

/// Single node in the collection tree hierarchy.
class CollectionTreeNode {
  const CollectionTreeNode({
    required this.id,
    required this.name,
    required this.colorSeed,
    this.parentId,
    this.noteCount = 0,
    this.children = const [],
  });

  final String id;
  final String name;
  final String colorSeed;
  final String? parentId;
  final int noteCount;
  final List<CollectionTreeNode> children;
}

/// A flattened representation of a visible row in the tree view.
class CollectionTreeRow {
  const CollectionTreeRow({
    required this.id,
    required this.name,
    required this.colorSeed,
    required this.parentId,
    required this.noteCount,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.node,
  });

  final String id;
  final String name;
  final String colorSeed;
  final String? parentId;
  final int noteCount;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final CollectionTreeNode node;
}

/// Controller managing collection hierarchy tree state:
/// expansion, persistence to SharedPreferences, selection, and keyboard navigation.
class CollectionTreeController extends ChangeNotifier {
  CollectionTreeController({Set<String>? initialExpanded})
      : _expandedIds = initialExpanded ?? {};

  static const String prefsKey = 'nook_collections_expanded_ids';

  final Set<String> _expandedIds;
  List<CollectionTreeNode> _roots = [];
  String? _selectedId;

  String? get selectedId => _selectedId;
  Set<String> get expandedIds => Set.unmodifiable(_expandedIds);

  void setNodes(List<CollectionTreeNode> roots) {
    _roots = roots;
    notifyListeners();
  }

  bool isExpanded(String id) => _expandedIds.contains(id);

  void toggleExpand(String id) {
    if (_expandedIds.contains(id)) {
      _expandedIds.remove(id);
    } else {
      _expandedIds.add(id);
    }
    _save();
    notifyListeners();
  }

  void expand(String id) {
    if (_expandedIds.add(id)) {
      _save();
      notifyListeners();
    }
  }

  void collapse(String id) {
    if (_expandedIds.remove(id)) {
      _save();
      notifyListeners();
    }
  }

  void selectId(String? id) {
    _selectedId = id;
    notifyListeners();
  }

  void selectIndex(int index) {
    final rows = flattenedVisibleRows;
    if (index >= 0 && index < rows.length) {
      _selectedId = rows[index].id;
      notifyListeners();
    }
  }

  /// Flattened list of visible rows respecting expansion states.
  List<CollectionTreeRow> get flattenedVisibleRows {
    final results = <CollectionTreeRow>[];

    void traverse(CollectionTreeNode node, int depth) {
      final expanded = _expandedIds.contains(node.id);
      final hasKids = node.children.isNotEmpty;

      results.add(
        CollectionTreeRow(
          id: node.id,
          name: node.name,
          colorSeed: node.colorSeed,
          parentId: node.parentId,
          noteCount: node.noteCount,
          depth: depth,
          hasChildren: hasKids,
          isExpanded: expanded,
          node: node,
        ),
      );

      if (expanded && hasKids) {
        for (final child in node.children) {
          traverse(child, depth + 1);
        }
      }
    }

    for (final root in _roots) {
      traverse(root, 0);
    }
    return results;
  }

  void moveNext() {
    final rows = flattenedVisibleRows;
    if (rows.isEmpty) return;
    if (_selectedId == null) {
      _selectedId = rows.first.id;
    } else {
      final idx = rows.indexWhere((r) => r.id == _selectedId);
      if (idx >= 0 && idx + 1 < rows.length) {
        _selectedId = rows[idx + 1].id;
      }
    }
    notifyListeners();
  }

  void movePrevious() {
    final rows = flattenedVisibleRows;
    if (rows.isEmpty) return;
    if (_selectedId == null) {
      _selectedId = rows.last.id;
    } else {
      final idx = rows.indexWhere((r) => r.id == _selectedId);
      if (idx > 0) {
        _selectedId = rows[idx - 1].id;
      }
    }
    notifyListeners();
  }

  void handleRightArrow() {
    if (_selectedId == null) return;
    final rows = flattenedVisibleRows;
    final row = rows.where((r) => r.id == _selectedId).firstOrNull;
    if (row != null && row.hasChildren && !row.isExpanded) {
      expand(row.id);
    }
  }

  void handleLeftArrow() {
    if (_selectedId == null) return;
    final rows = flattenedVisibleRows;
    final row = rows.where((r) => r.id == _selectedId).firstOrNull;
    if (row == null) return;

    if (row.hasChildren && row.isExpanded) {
      collapse(row.id);
    } else if (row.parentId != null) {
      _selectedId = row.parentId;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, _expandedIds.toList());
    } catch (_) {
      // Ignore in tests with memory mock
    }
  }

  static Future<CollectionTreeController> create() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(prefsKey) ?? [];
    return CollectionTreeController(initialExpanded: list.toSet());
  }

  /// Builds a tree structure of [CollectionTreeNode] from flat [notebooks]
  /// and aggregate note [counts].
  static List<CollectionTreeNode> buildTree(
    List<Notebook> notebooks,
    Map<String, int> counts,
  ) {
    final parentMap = <String?, List<Notebook>>{};
    for (final nb in notebooks) {
      parentMap.putIfAbsent(nb.parentId, () => []).add(nb);
    }

    CollectionTreeNode buildNode(Notebook nb) {
      final kids = parentMap[nb.id] ?? [];
      return CollectionTreeNode(
        id: nb.id,
        name: nb.name,
        colorSeed: nb.colorSeed,
        parentId: nb.parentId,
        noteCount: counts[nb.id] ?? 0,
        children: kids.map(buildNode).toList(),
      );
    }

    final roots = parentMap[null] ?? [];
    return roots.map(buildNode).toList();
  }
}
