import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../data/repositories/checklist_item_repository.dart';

/// A standalone checklist editor for checklist-type notes.
/// Shows a list of items with checkboxes, add item field, and delete.
class ChecklistEditor extends ConsumerStatefulWidget {
  const ChecklistEditor({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends ConsumerState<ChecklistEditor> {
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();
  List<_ChecklistItemView> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    final items = await repo.getItems(widget.noteId);
    if (mounted) {
      setState(() {
        _items = items
            .map((i) => _ChecklistItemView(
                  id: i.id,
                  text: i.itemText,
                  checked: i.checked,
                  sortOrder: i.sortOrder,
                ))
            .toList();
        _loading = false;
      });
    }
  }

  Future<void> _addItem(String text) async {
    if (text.trim().isEmpty) return;
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.addItem(noteId: widget.noteId, text: text.trim());
    _addController.clear();
    await _load();
    if (mounted) _addFocusNode.requestFocus();
  }

  Future<void> _toggleItem(String id) async {
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.toggleChecked(id);
    await _load();
  }

  Future<void> _deleteItem(String id) async {
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.deleteItem(id);
    await _load();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);

    final ids = _items.map((i) => i.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);

    await repo.reorderItems(widget.noteId, ids);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkedCount = _items.where((i) => i.checked).length;
    final totalCount = _items.length;

    return Column(
      children: [
        // Progress bar
        if (totalCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text(
                  '$checkedCount/$totalCount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: totalCount > 0 ? checkedCount / totalCount : 0,
                      minHeight: 4,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Item list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        'No items yet',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items.length,
                      onReorderItem: _reorder,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _ChecklistTile(
                          key: ValueKey(item.id),
                          index: index,
                          id: item.id,
                          text: item.text,
                          checked: item.checked,
                          onToggle: () => _toggleItem(item.id),
                          onDelete: () => _deleteItem(item.id),
                        );
                      },
                    ),
        ),

        // Add item field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Icon(Icons.add, color: scheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _addController,
                    focusNode: _addFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Add item...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: _addItem,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistItemView {
  const _ChecklistItemView({
    required this.id,
    required this.text,
    required this.checked,
    required this.sortOrder,
  });

  final String id;
  final String text;
  final bool checked;
  final int sortOrder;
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    super.key,
    required this.index,
    required this.id,
    required this.text,
    required this.checked,
    required this.onToggle,
    required this.onDelete,
  });

  final int index;
  final String id;
  final String text;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: (_) => onToggle(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                decoration:
                    checked ? TextDecoration.lineThrough : TextDecoration.none,
                color: checked
                    ? scheme.onSurface.withValues(alpha: 0.4)
                    : scheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              size: 20,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
