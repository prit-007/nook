import 'dart:async';

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
  List<_ChecklistItemView> _archivedItems = [];
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
            .where((i) => !i.checked)
            .map((i) => _ChecklistItemView(
                  id: i.id,
                  text: i.itemText,
                  checked: i.checked,
                  sortOrder: i.sortOrder,
                ))
            .toList();
        _archivedItems = items
            .where((i) => i.checked)
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

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    final textTheme = NoteThemeScope.textThemeOf(context);
    final checkedCount = _archivedItems.length;
    final totalCount = _items.length + _archivedItems.length;
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
                : _items.isEmpty && _archivedItems.isEmpty
                    ? Center(
                        child: Text(
                          'A fresh start.',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.only(
                              top: 8,
                              left: 20,
                              right: 20,
                              bottom: viewInsets.bottom + 100,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // Active items
                                for (var index = 0;
                                    index < _items.length;
                                    index++)
                                  _SwipeableTile(
                                    key: ValueKey(_items[index].id),
                                    onSwipe: () =>
                                        _toggleItem(_items[index].id),
                                    background: const _SwipeToCheckBackground(
                                      alignment: Alignment.centerRight,
                                      isChecked: false,
                                    ),
                                    child: _ChecklistTile(
                                      key: ValueKey(_items[index].id),
                                      index: index,
                                      id: _items[index].id,
                                      text: _items[index].text,
                                      checked: false,
                                      onToggle: () =>
                                          _toggleItem(_items[index].id),
                                      onDelete: () =>
                                          _deleteItem(_items[index].id),
                                    ),
                                  ),

                                // Completed divider + archived items
                                if (_archivedItems.isNotEmpty) ...[
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(4, 24, 4, 12),
                                    child: Text(
                                      'COMPLETED',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  for (var index = 0;
                                      index < _archivedItems.length;
                                      index++)
                                    _ChecklistTile(
                                      key: ValueKey(_archivedItems[index].id),
                                      index: index,
                                      id: _archivedItems[index].id,
                                      text: _archivedItems[index].text,
                                      checked: true,
                                      onToggle: () =>
                                          _toggleItem(_archivedItems[index].id),
                                      onDelete: () =>
                                          _deleteItem(_archivedItems[index].id),
                                    ),
                                ],
                              ]),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
      // 3. Morphing Input Pill
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _MorphingInputPill(
        addController: _addController,
        addFocusNode: _addFocusNode,
        onAdd: _addItem,
      ),
    );
  }
}

/// Morphing input pill: starts as a circular FAB, expands to full input on tap.
class _MorphingInputPill extends StatefulWidget {
  const _MorphingInputPill({
    required this.addController,
    required this.addFocusNode,
    required this.onAdd,
  });

  final TextEditingController addController;
  final FocusNode addFocusNode;
  final Future<void> Function(String) onAdd;

  @override
  State<_MorphingInputPill> createState() => _MorphingInputPillState();
}

class _MorphingInputPillState extends State<_MorphingInputPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    widget.addFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.addFocusNode.removeListener(_onFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.addFocusNode.hasFocus && !_expanded) {
      _expand();
    } else if (!widget.addFocusNode.hasFocus &&
        widget.addController.text.isEmpty &&
        _expanded) {
      _collapse();
    }
  }

  void _expand() {
    setState(() => _expanded = true);
    _controller.forward();
  }

  void _collapse() {
    _controller.reverse().then((_) {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _handleSubmit(String value) {
    widget.onAdd(value);
    if (_expanded) _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    final textTheme = NoteThemeScope.textThemeOf(context);

    return AnimatedBuilder(
      animation: _expandAnim,
      builder: (context, child) {
        final t = _expandAnim.value;
        final maxPillWidth = MediaQuery.sizeOf(context).width - 40;
        final pillWidth = 56.0 + (maxPillWidth - 56) * t;
        final pillHeight = 56.0;
        final isCircle = t < 0.05;

        return GestureDetector(
          onTap: _expanded ? null : _expand,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 20),
            width: pillWidth,
            height: pillHeight,
            padding: EdgeInsets.symmetric(horizontal: 8 + 12 * t),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(isCircle ? 28 : 32),
            ),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.close_rounded : Icons.add_rounded,
                  color: scheme.primary,
                  size: 24,
                ),
                if (t > 0.1) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: TextField(
                        controller: widget.addController,
                        focusNode: widget.addFocusNode,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Add a new task...',
                          hintStyle: textTheme.bodyLarge?.copyWith(
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: _handleSubmit,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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

/// Swipeable tile with horizontal squish feedback.
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

class _SwipeableTileState extends State<_SwipeableTile>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  late final AnimationController _snapController;
  double _snapTarget = 0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_snapController.isCompleted || _snapController.isDismissed) return;
        setState(() {
          _dragExtent = _dragExtent + (_snapTarget - _dragExtent) * 0.15;
        });
      });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clamped = _dragExtent.clamp(-120.0, 120.0);
    final squishFactor = (clamped.abs() / 120.0) * 0.05;
    final iconScale = 1.0 + (clamped.abs() / 120.0) * 0.4;

    return Stack(
      children: [
        if (_dragExtent.abs() > 10)
          Transform.scale(
            scale: iconScale,
            child: widget.background,
          ),
        Transform.translate(
          offset: Offset(clamped, 0),
          child: Transform.scale(
            scaleX: 1.0 - squishFactor,
            scaleY: 1.0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                _snapController.stop();
                setState(() => _dragExtent += details.delta.dx);
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_dragExtent.abs() > 80 || velocity.abs() > 400) {
                  widget.onSwipe();
                  setState(() => _dragExtent = 0);
                } else {
                  _snapTarget = 0;
                  _snapController.forward(from: 0);
                }
              },
              child: widget.child,
            ),
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
