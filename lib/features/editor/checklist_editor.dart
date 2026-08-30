import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/providers/database_provider.dart';
import '../../core/theme/note_theme_scope.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../data/repositories/checklist_item_repository.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/tables/attachments.dart';
import '../../data/repositories/note_repository.dart';
import 'widgets/media_delete_button.dart';

/// A standalone checklist editor for checklist-type notes.
/// Shows a list of items with checkboxes, add item field, and delete.
class ChecklistEditor extends ConsumerStatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.noteId,
    this.title = '',
    this.initialAttachments = const [],
    this.onTitleChanged,
    this.onInsertImage,
    this.onInsertDoodle,
    this.onOpenAttachment,
    this.onDeleteAttachment,
  });

  final String noteId;
  final String title;
  final List<Attachment> initialAttachments;
  final ValueChanged<String>? onTitleChanged;
  final Future<void> Function()? onInsertImage;
  final Future<void> Function()? onInsertDoodle;
  final Future<void> Function(Attachment attachment)? onOpenAttachment;
  final Future<void> Function(Attachment attachment)? onDeleteAttachment;

  @override
  ConsumerState<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends ConsumerState<ChecklistEditor> {
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();
  late final TextEditingController _titleController;
  Timer? _titleDebounce;
  List<_ChecklistItemView> _items = [];
  List<_ChecklistItemView> _archivedItems = [];
  bool _loading = true;
  bool _initialLoadDone = false;
  List<Attachment> _attachments = [];
  final List<List<_ChecklistItemView>> _undoStack = [];
  final List<List<_ChecklistItemView>> _redoStack = [];
  bool _completedExpanded = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _attachments = List.of(widget.initialAttachments);
    _load();
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleController.dispose();
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChecklistEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title &&
        _titleController.text != widget.title) {
      _titleController.text = widget.title;
    }
    // Sync attachments from parent when they change (instant refresh).
    if (oldWidget.initialAttachments != widget.initialAttachments) {
      _attachments = List.of(widget.initialAttachments);
    }
  }

  void _scheduleTitleSave(String value) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 500), () {
      widget.onTitleChanged?.call(value.trim());
    });
  }

  /// Pulls the first (unchecked) task into the note title.
  void _extractTitle() {
    final first = _items.firstOrNull;
    if (first == null) return;
    unawaited(HapticFeedback.selectionClick());
    _recordHistory();
    _titleController.text = first.text;
    _titleDebounce?.cancel();
    widget.onTitleChanged?.call(first.text);
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    final attachmentRepo = AttachmentRepository(db);
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
        // Auto-collapse completed on first load if more than 5 items.
        if (!_initialLoadDone && _archivedItems.length > 5) {
          _completedExpanded = false;
        }
        _initialLoadDone = true;
        _loading = false;
      });
    }
    final attachments = await attachmentRepo.getAllForNote(widget.noteId);
    if (mounted) {
      setState(() => _attachments = attachments);
    }
  }

  Future<void> _addItem(String text) async {
    if (text.trim().isEmpty) return;
    _recordHistory();
    unawaited(HapticFeedback.mediumImpact());
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    final wasEmpty = (await repo.getItems(widget.noteId)).isEmpty;
    await repo.addItem(noteId: widget.noteId, text: text.trim());
    if (wasEmpty && widget.title.isEmpty) {
      await NoteRepository(db).updateNote(widget.noteId, title: text.trim());
    }
    _addController.clear();
    await _load();
    if (mounted) _addFocusNode.requestFocus();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    unawaited(HapticFeedback.mediumImpact());
    _recordHistory();

    final movedItem = _items.removeAt(oldIndex);
    _items.insert(newIndex, movedItem);

    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.reorderItems(
      widget.noteId,
      _items.map((i) => i.id).toList(),
    );
    setState(() {});
  }

  Future<void> _toggleItem(String id) async {
    unawaited(HapticFeedback.lightImpact());
    _recordHistory();
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.toggleChecked(id);
    await _load();
  }

  Future<void> _deleteItem(String id) async {
    final item = [..._items, ..._archivedItems].firstWhere(
      (i) => i.id == id,
      orElse: () =>
          _ChecklistItemView(id: id, text: '', checked: false, sortOrder: 0),
    );
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete task?',
      message: item.text.isNotEmpty
          ? '"${item.text}" will be moved to trash.'
          : 'This task will be moved to trash.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    unawaited(HapticFeedback.selectionClick());
    _recordHistory();
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.deleteItem(id);
    await _load();
  }

  List<_ChecklistItemView> get _allItems => [..._items, ..._archivedItems]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  void _recordHistory() {
    _undoStack.add(_allItems.map((item) => item.copy()).toList());
    _redoStack.clear();
  }

  Future<void> _restore(List<_ChecklistItemView> snapshot) async {
    final repo = ChecklistItemRepository(ref.read(databaseProvider));
    await repo.replaceItems(
      widget.noteId,
      [
        for (var index = 0; index < snapshot.length; index++)
          ChecklistItemsCompanion.insert(
            id: Value(snapshot[index].id),
            noteId: widget.noteId,
            itemText: snapshot[index].text,
            checked: Value(snapshot[index].checked),
            sortOrder: Value(index),
          ),
      ],
    );
    await _load();
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_allItems.map((item) => item.copy()).toList());
    await _restore(_undoStack.removeLast());
  }

  Future<void> _redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_allItems.map((item) => item.copy()).toList());
    await _restore(_redoStack.removeLast());
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Text(
                    totalCount == 0
                        ? 'No tasks yet'
                        : '$checkedCount of $totalCount Done',
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
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: _undoStack.isEmpty ? null : _undo,
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedUndo02,
                        size: 20,
                        color: scheme.onSurface),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    onPressed: _redoStack.isEmpty ? null : _redo,
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedRedo02,
                        size: 20,
                        color: scheme.onSurface),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),

          // 2. Editable Title Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Untitled checklist',
                      hintStyle: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface.withValues(alpha: 0.3),
                      ),
                      filled: false,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _scheduleTitleSave,
                    onSubmitted: (value) {
                      _titleDebounce?.cancel();
                      widget.onTitleChanged?.call(value.trim());
                    },
                  ),
                ),
                if (_items.isNotEmpty)
                  IconButton(
                    tooltip: 'Use first task as title',
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedTextCreation,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: _extractTitle,
                  ),
              ],
            ),
          ),

          // 3. Reorderable Task List
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
                          if (_attachments.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _ChecklistMediaStrip(
                                attachments: _attachments,
                                onInsertImage: widget.onInsertImage,
                                onInsertDoodle: widget.onInsertDoodle,
                                onOpenAttachment: widget.onOpenAttachment,
                                onDeleteAttachment: widget.onDeleteAttachment,
                              ),
                            ),
                          SliverPadding(
                            padding: EdgeInsets.only(
                              top: 8,
                              left: 20,
                              right: 20,
                              bottom: viewInsets.bottom + 100,
                            ),
                            sliver: SliverReorderableList(
                              itemCount: _items.length,
                              onReorderItem: _reorder,
                              itemBuilder: (context, index) {
                                return _SwipeableTile(
                                  key: ValueKey(_items[index].id),
                                  onSwipeRight: () =>
                                      _toggleItem(_items[index].id),
                                  onSwipeLeft: () =>
                                      _toggleItem(_items[index].id),
                                  background: const _SwipeToCheckBackground(
                                    alignment: Alignment.centerRight,
                                    isChecked: false,
                                  ),
                                  leftBackground:
                                      const _SwipeToCheckBackground(
                                    alignment: Alignment.centerLeft,
                                    isChecked: false,
                                  ),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: _initialLoadDone ? 1.0 : 0.0,
                                      end: 1.0,
                                    ),
                                    duration: Duration(
                                      milliseconds:
                                          80 + (index * 40).clamp(0, 400),
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) =>
                                        Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: child,
                                      ),
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
                                );
                              },
                            ),
                          ),

                          // Completed divider + archived items (collapsible)
                          if (_archivedItems.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _completedExpanded =
                                        !_completedExpanded),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 24, 24, 12),
                                  child: Row(
                                    children: [
                                      AnimatedRotation(
                                        turns: _completedExpanded ? 0.25 : 0,
                                        duration: const Duration(
                                            milliseconds: 200),
                                        child: HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedArrowRight01,
                                          size: 16,
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'COMPLETED \u00b7 ${_archivedItems.length}',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_completedExpanded)
                              SliverPadding(
                                padding: EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  bottom: viewInsets.bottom + 100,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _ChecklistTile(
                                      key: ValueKey(
                                          _archivedItems[index].id),
                                      index: index,
                                      id: _archivedItems[index].id,
                                      text: _archivedItems[index].text,
                                      checked: true,
                                      onToggle: () => _toggleItem(
                                          _archivedItems[index].id),
                                      onDelete: () => _deleteItem(
                                          _archivedItems[index].id),
                                    ),
                                    childCount: _archivedItems.length,
                                  ),
                                ),
                              ),
                          ],
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
    if (value.trim().isEmpty) {
      if (_expanded) _collapse();
      return;
    }

    widget.onAdd(value);

    // UX FIX: Keep pill expanded for rapid multi-item entry.
    // The parent's _addItem already clears the controller and re-requests focus.
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isCircle ? 28 : 32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: pillWidth,
                height: pillHeight,
                padding: EdgeInsets.symmetric(horizontal: 8 + 12 * t),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(isCircle ? 28 : 32),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: _expanded
                          ? HugeIcons.strokeRoundedCancelCircle
                          : HugeIcons.strokeRoundedAdd01,
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
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
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

  _ChecklistItemView copy() => _ChecklistItemView(
        id: id,
        text: text,
        checked: checked,
        sortOrder: sortOrder,
      );
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
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      size: 16,
                      color: scheme.onPrimary)
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
                        child: Opacity(
                          opacity: value, // Fades in as it expands
                          child: Container(
                            height: 1.5,
                            color: scheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCancelCircle,
                size: 20,
                color: scheme.onSurface.withValues(alpha: 0.3)),
            tooltip: 'Delete item',
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
          ReorderableDragStartListener(
            index: index,
            child: HugeIcon(
                icon: HugeIcons.strokeRoundedDrag01,
                size: 22,
                color: scheme.onSurface.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }
}

/// Swipeable tile with deterministic snap-back physics.
class _SwipeableTile extends StatefulWidget {
  const _SwipeableTile({
    super.key,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.background,
    required this.leftBackground,
    required this.child,
  });

  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final Widget background;
  final Widget leftBackground;
  final Widget child;

  @override
  State<_SwipeableTile> createState() => _SwipeableTileState();
}

class _SwipeableTileState extends State<_SwipeableTile>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  late final AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _snapAnimation = const AlwaysStoppedAnimation(0);
    _snapController.addListener(() {
      if (mounted) setState(() => _dragExtent = _snapAnimation.value);
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
    final progress = (clamped.abs() / 80.0).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: progress,
            child: _dragExtent < 0 ? widget.leftBackground : widget.background,
          ),
        ),
        Transform.translate(
          offset: Offset(clamped, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              _snapController.stop();
              setState(() {
                _dragExtent =
                    (_dragExtent + details.delta.dx * 0.7).clamp(-120.0, 120.0);
              });
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final thresholdMet =
                  _dragExtent.abs() > 80 || velocity.abs() > 400;
              if (thresholdMet) {
                if (_dragExtent < 0) {
                  widget.onSwipeLeft();
                } else {
                  widget.onSwipeRight();
                }
              }
              _snapAnimation = Tween<double>(
                begin: _dragExtent,
                end: 0,
              ).animate(
                CurvedAnimation(
                  parent: _snapController,
                  curve: thresholdMet ? Curves.easeOutExpo : Curves.easeOutBack,
                ),
              );
              _snapController.forward(from: 0);
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
          HugeIcon(
            icon: isChecked
                ? HugeIcons.strokeRoundedUndo02
                : HugeIcons.strokeRoundedCheckmarkCircle01,
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

/// Horizontal strip showing checklist attachments with add buttons.
class _ChecklistMediaStrip extends StatelessWidget {
  const _ChecklistMediaStrip({
    required this.attachments,
    this.onInsertImage,
    this.onInsertDoodle,
    this.onOpenAttachment,
    this.onDeleteAttachment,
  });

  final List<dynamic> attachments;
  final Future<void> Function()? onInsertImage;
  final Future<void> Function()? onInsertDoodle;
  final Future<void> Function(Attachment attachment)? onOpenAttachment;
  final Future<void> Function(Attachment attachment)? onDeleteAttachment;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: attachments.length +
            (onInsertImage != null ? 1 : 0) +
            (onInsertDoodle != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index < attachments.length) {
            final attachment = attachments[index] as Attachment;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 84,
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    child: GestureDetector(
                      onTap: onOpenAttachment == null
                          ? null
                          : () => onOpenAttachment!(attachment),
                      child: _attachmentPreview(attachment, scheme),
                    ),
                  ),
                ),
                if (onDeleteAttachment != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: MediaDeleteButton(
                      tooltip: 'Remove attachment',
                      onPressed: () => onDeleteAttachment!(attachment),
                    ),
                  ),
              ],
            );
          }
          final isImage = index == attachments.length;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (isImage) {
                onInsertImage?.call();
              } else {
                onInsertDoodle?.call();
              }
            },
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: HugeIcon(
                icon: isImage
                    ? HugeIcons.strokeRoundedImageAdd01
                    : HugeIcons.strokeRoundedDrawingMode,
                color: scheme.primary,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _attachmentPreview(Attachment attachment, ColorScheme scheme) {
    final path = attachment.thumbnailPath ?? attachment.filePath;
    if (path.isNotEmpty && File(path).existsSync()) {
      return Image.file(File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _attachmentIcon(attachment, scheme));
    }
    return _attachmentIcon(attachment, scheme);
  }

  Widget _attachmentIcon(Attachment attachment, ColorScheme scheme) => HugeIcon(
        icon: attachment.type == AttachmentType.doodleLayer
            ? HugeIcons.strokeRoundedDrawingMode
            : HugeIcons.strokeRoundedImage01,
        color: scheme.onSurfaceVariant,
      );
}
