import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/theme/note_theme_scope.dart';
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
    unawaited(HapticFeedback.mediumImpact());
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.addItem(noteId: widget.noteId, text: text.trim());
    _addController.clear();
    await _load();
    if (mounted) _addFocusNode.requestFocus();
  }

  Future<void> _toggleItem(String id) async {
    unawaited(HapticFeedback.lightImpact());
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.toggleChecked(id);
    await _load();
  }

  Future<void> _deleteItem(String id) async {
    unawaited(HapticFeedback.selectionClick());
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.deleteItem(id);
    await _load();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    unawaited(HapticFeedback.selectionClick());
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
    final scheme = NoteThemeScope.of(context);
    final textTheme = NoteThemeScope.textThemeOf(context);
    final checkedCount = _items.where((i) => i.checked).length;
    final totalCount = _items.length;
    final progress = totalCount > 0 ? checkedCount / totalCount : 0.0;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 1. Dynamic Progress Capsule
          if (totalCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$checkedCount of $totalCount Done',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedProgressBar(
                          value: progress,
                          color: scheme.primary,
                          backgroundColor: scheme.surfaceContainerLow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. Reorderable Task List
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: scheme.primary))
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'A fresh start.',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: EdgeInsets.only(
                          top: 8,
                          left: 20,
                          right: 20,
                          bottom: viewInsets.bottom + 100,
                        ),
                        itemCount: _items.length,
                        onReorderItem: _reorder,
                        proxyDecorator: (child, index, animation) =>
                            Material(color: Colors.transparent, child: child),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _SwipeableTile(
                            key: ValueKey(item.id),
                            onSwipe: () => _toggleItem(item.id),
                            background: _SwipeToCheckBackground(
                              alignment: Alignment.centerRight,
                              isChecked: item.checked,
                            ),
                            child: _ChecklistTile(
                              key: ValueKey(item.id),
                              index: index,
                              id: item.id,
                              text: item.text,
                              checked: item.checked,
                              onToggle: () => _toggleItem(item.id),
                              onDelete: () => _deleteItem(item.id),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // 3. Floating Input Pill
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, color: scheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      focusNode: _addFocusNode,
                      style: textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Add a new task...',
                        hintStyle: textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
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
        ),
      ),
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  final double value;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) => LinearProgressIndicator(
        value: val,
        minHeight: 8,
        backgroundColor: backgroundColor,
        color: color,
      ),
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
    final scheme = NoteThemeScope.of(context);
    final textTheme = NoteThemeScope.textThemeOf(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: checked
            ? scheme.surfaceContainerLow.withValues(alpha: 0.4)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: checked ? 0.1 : 0.3),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: checked ? scheme.primary : scheme.outline,
                  width: 2,
                ),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    color: checked
                        ? scheme.onSurface.withValues(alpha: 0.3)
                        : scheme.onSurface,
                  ),
                  child: Text(text),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: checked ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          height: 2,
                          color: scheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 20, color: scheme.onSurface.withValues(alpha: 0.3)),
            tooltip: 'Delete item',
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_indicator_rounded,
                size: 22, color: scheme.onSurface.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }
}

class _SwipeableTile extends StatefulWidget {
  const _SwipeableTile({
    super.key,
    required this.onSwipe,
    required this.background,
    required this.child,
  });

  final VoidCallback onSwipe;
  final Widget background;
  final Widget child;

  @override
  State<_SwipeableTile> createState() => _SwipeableTileState();
}

class _SwipeableTileState extends State<_SwipeableTile> {
  double _dragExtent = 0;

  @override
  Widget build(BuildContext context) {
    final clamped = _dragExtent.clamp(-120.0, 120.0);
    return Stack(
      children: [
        if (_dragExtent.abs() > 10) widget.background,
        Transform.translate(
          offset: Offset(clamped, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() => _dragExtent += details.delta.dx);
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (_dragExtent.abs() > 80 || velocity.abs() > 400) {
                widget.onSwipe();
              }
              setState(() => _dragExtent = 0);
            },
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _SwipeToCheckBackground extends StatelessWidget {
  const _SwipeToCheckBackground({
    required this.alignment,
    required this.isChecked,
  });

  final Alignment alignment;
  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isChecked ? Icons.undo_rounded : Icons.check_circle_rounded,
            size: 24,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            isChecked ? 'Uncheck' : 'Complete',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
