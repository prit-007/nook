import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/nook_tokens.dart';
import '../controllers/collection_tree_controller.dart';

/// Expandable tree view for collections / notebooks.
///
/// Designed for wide screens, desktop sidebars, and nested dialogs.
/// Supports keyboard navigation (Right to expand, Left to collapse/move up, Up/Down to navigate),
/// animated chevrons, drag-and-drop reparenting, and full accessibility semantics.
class CollectionTreeView extends StatefulWidget {
  const CollectionTreeView({
    super.key,
    required this.controller,
    required this.onSelect,
    this.onReparent,
    this.onCreateCollection,
  });

  final CollectionTreeController controller;
  final ValueChanged<String> onSelect;
  final void Function(String childId, String? newParentId)? onReparent;
  final VoidCallback? onCreateCollection;

  @override
  State<CollectionTreeView> createState() => _CollectionTreeViewState();
}

class _CollectionTreeViewState extends State<CollectionTreeView> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.controller.moveNext();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.controller.movePrevious();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.controller.handleRightArrow();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.controller.handleLeftArrow();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (widget.controller.selectedId != null) {
        widget.onSelect(widget.controller.selectedId!);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final rows = widget.controller.flattenedVisibleRows;

        return Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount:
                rows.length + (widget.onCreateCollection != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == rows.length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextButton.icon(
                    onPressed: widget.onCreateCollection,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedPlusSign,
                      size: 16,
                    ),
                    label: const Text('New collection'),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: scheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: tokens.borderRadiusSm,
                      ),
                    ),
                  ),
                );
              }

              final row = rows[index];
              final isSelected = widget.controller.selectedId == row.id;
              final seedColor = NookColors.parseHex(row.colorSeed);
              final indent = 12.0 + (row.depth * 20.0);

              Widget content = InkWell(
                onTap: () {
                  widget.controller.selectId(row.id);
                  widget.onSelect(row.id);
                  _focusNode.requestFocus();
                },
                borderRadius: tokens.borderRadiusSm,
                child: Container(
                  height: 40,
                  padding: EdgeInsets.only(left: indent, right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: tokens.borderRadiusSm,
                  ),
                  child: Row(
                    children: [
                      // Expand / Collapse Chevron
                      if (row.hasChildren)
                        GestureDetector(
                          key: ValueKey('chevron_${row.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.controller.toggleExpand(row.id),
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            child: AnimatedRotation(
                              turns: row.isExpanded ? 0.25 : 0.0,
                              duration: AppMotion.short3,
                              curve: AppMotion.emphasizedDecelerate,
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 24),
                      const SizedBox(width: 4),

                      // Color seed pip
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: seedColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Collection name
                      Expanded(
                        child: Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isSelected ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                      ),

                      // Note count chip
                      if (row.noteCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${row.noteCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );

              // Support drag & drop reparenting
              if (widget.onReparent != null) {
                content = DragTarget<String>(
                  onWillAcceptWithDetails: (details) => details.data != row.id,
                  onAcceptWithDetails: (details) {
                    widget.onReparent?.call(details.data, row.id);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isDropTarget = candidateData.isNotEmpty;
                    return Draggable<String>(
                      data: row.id,
                      feedback: Material(
                        elevation: 4,
                        borderRadius: tokens.borderRadiusSm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: tokens.borderRadiusSm,
                          ),
                          child: Text(row.name,
                              style: TextStyle(color: scheme.onSurface)),
                        ),
                      ),
                      child: Container(
                        decoration: isDropTarget
                            ? BoxDecoration(
                                border: Border.all(
                                    color: scheme.primary, width: 1.5),
                                borderRadius: tokens.borderRadiusSm,
                              )
                            : null,
                        child: content,
                      ),
                    );
                  },
                );
              }

              return Semantics(
                key: ValueKey('row_${row.id}'),
                label: '${row.name}, level ${row.depth + 1}',
                button: true,
                excludeSemantics: true,
                expanded: row.hasChildren ? row.isExpanded : null,
                child: content,
              );
            },
          ),
        );
      },
    );
  }
}
