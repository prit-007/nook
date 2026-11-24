import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/database.dart';
import '../../data/tables/notes.dart';

/// Responsive app bar for the note editor with title, metadata, and actions.
class ResponsiveEditorAppBar extends StatelessWidget {
  const ResponsiveEditorAppBar({
    super.key,
    required this.noteScheme,
    required this.dynamicTextTheme,
    required this.title,
    required this.saving,
    this.isSaved = false,
    required this.pinned,
    required this.note,
    required this.onBack,
    this.onInsertImage,
    this.onInsertDoodle,
    required this.onTogglePin,
    required this.onExport,
    required this.onMoreOptions,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    this.notebookName,
    this.tagNames = const [],
    this.wordCount = 0,
    this.readingTime = 0,
    this.colorSeed,
    this.onPickColor,
    this.onPickPaperStyle,
    this.onShowOutline,
    this.showFocusMode = true,
    this.onEnterFocusMode,
  });

  final ColorScheme noteScheme;
  final TextTheme dynamicTextTheme;
  final String title;
  final bool saving;
  final bool isSaved;
  final bool pinned;
  final Note? note;
  final VoidCallback onBack;
  final VoidCallback? onInsertImage;
  final VoidCallback? onInsertDoodle;
  final VoidCallback onTogglePin;
  final VoidCallback onExport;
  final VoidCallback onMoreOptions;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final String? notebookName;
  final List<String> tagNames;
  final int wordCount;
  final int readingTime;
  final String? colorSeed;
  final VoidCallback? onPickColor;
  final VoidCallback? onPickPaperStyle;

  /// Opens the document outline sheet listing the note's headings.
  final VoidCallback? onShowOutline;

  /// Whether the "Focus mode" entry point is offered. Hidden while the
  /// editor is already in focus mode.
  final bool showFocusMode;

  /// Enters focus mode (chrome hidden, writing surface only).
  final VoidCallback? onEnterFocusMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;

        Widget pinButton({required bool compact}) => IconButton(
              tooltip: pinned ? 'Unpin note' : 'Pin note',
              icon: HugeIcon(
                icon: pinned
                    ? HugeIcons.strokeRoundedPinOff
                    : HugeIcons.strokeRoundedPin,
                size: compact ? 19 : 20,
                color: pinned ? noteScheme.primary : noteScheme.onSurface,
              ),
              onPressed: onTogglePin,
            );

        Widget colorButton({required bool compact}) {
          final effectiveColor = colorSeed != null && colorSeed!.isNotEmpty
              ? NookColors.parseHex(colorSeed)
              : noteScheme.primary;
          return IconButton(
            tooltip: 'Note color',
            icon: Container(
              width: compact ? 18 : 20,
              height: compact ? 18 : 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectiveColor,
                border: Border.all(
                  color: noteScheme.onSurface.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
            onPressed: onPickColor,
          );
        }

        Widget noteTypeBadge() {
          final (icon, label) = switch (note?.type) {
            NoteType.checklist => (
                HugeIcons.strokeRoundedCheckList,
                'Checklist'
              ),
            NoteType.doodle => (HugeIcons.strokeRoundedDrawingMode, 'Doodle'),
            _ => (HugeIcons.strokeRoundedNotebook01, 'Text'),
          };
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: noteScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: icon, size: 10, color: noteScheme.primary),
                const SizedBox(width: 3.5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: noteScheme.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          );
        }

        Widget lockedBadge() {
          if (note?.locked != true) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: noteScheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedLock,
                  size: 11,
                  color: noteScheme.error,
                ),
                const SizedBox(width: 3.5),
                Text(
                  'Locked',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: noteScheme.error,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          );
        }

        return Row(
          children: [
            IconButton(
              tooltip: 'Back',
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: noteScheme.onSurface,
              ),
              onPressed: onBack,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title.isNotEmpty ? title : 'New Note',
                          style: dynamicTextTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      noteTypeBadge(),
                      lockedBadge(),
                    ],
                  ),
                  saving
                      ? Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: noteScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : isSaved
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon:
                                      HugeIcons.strokeRoundedCheckmarkCircle02,
                                  size: 13,
                                  color: noteScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Saved',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: noteScheme.primary,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _subtitle(
                                      note?.updatedAt ?? DateTime.now(),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: noteScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (wordCount > 0 && !isNarrow) ...[
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 90),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: noteScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$wordCount words \u00b7 $readingTime min',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: noteScheme.primary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                ],
              ),
            ),
            if (isNarrow) ...[
              if (note?.type == NoteType.doodle)
                IconButton(
                  tooltip: 'Draw',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedDrawingMode,
                    size: 19,
                    color: noteScheme.primary,
                  ),
                  onPressed: onInsertDoodle,
                ),
              colorButton(compact: true),
              pinButton(compact: true),
              PopupMenuButton<String>(
                tooltip: 'More options',
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMore01,
                  color: noteScheme.onSurface,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'undo':
                      onUndo();
                    case 'redo':
                      onRedo();
                    case 'paper':
                      onPickPaperStyle?.call();
                    case 'outline':
                      onShowOutline?.call();
                    case 'image':
                      onInsertImage?.call();
                    case 'doodle':
                      onInsertDoodle?.call();
                    case 'pin':
                      onTogglePin();
                    case 'focus':
                      onEnterFocusMode?.call();
                    case 'export':
                      onExport();
                    case 'more':
                      onMoreOptions();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'undo',
                    enabled: canUndo,
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedUndo02,
                          size: 20,
                          color: noteScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Undo'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'redo',
                    enabled: canRedo,
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedRedo02,
                          size: 20,
                          color: noteScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Redo'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'paper',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedGrid,
                          size: 20,
                          color: noteScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Paper style'),
                      ],
                    ),
                  ),
                  if (onShowOutline != null)
                    PopupMenuItem(
                      value: 'outline',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedMenuSquare,
                            size: 20,
                            color: noteScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text(
                              'Document outline',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (onInsertImage != null)
                    if (onInsertImage != null)
                      PopupMenuItem(
                        value: 'image',
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedImageAdd01,
                              size: 20,
                              color: noteScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            const Text('Insert image'),
                          ],
                        ),
                      ),
                  if (onInsertDoodle != null)
                    PopupMenuItem(
                      value: 'doodle',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedDrawingMode,
                            size: 20,
                            color: noteScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Text('Insert doodle'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: pinned
                              ? HugeIcons.strokeRoundedPinOff
                              : HugeIcons.strokeRoundedPin,
                          size: 20,
                          color: pinned
                              ? noteScheme.primary
                              : noteScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(pinned ? 'Unpin note' : 'Pin note'),
                      ],
                    ),
                  ),
                  if (showFocusMode && onEnterFocusMode != null)
                    PopupMenuItem(
                      value: 'focus',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedView,
                            size: 20,
                            color: noteScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Flexible(
                            child: Text(
                              'Focus mode',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedShare01,
                          size: 20,
                          color: noteScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Export note'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'more',
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedSettings02,
                          size: 20,
                          color: noteScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        const Text('Note options'),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              IconButton(
                tooltip: 'Undo',
                onPressed: canUndo ? onUndo : null,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedUndo02,
                  color: noteScheme.onSurface,
                ),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: canRedo ? onRedo : null,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedRedo02,
                  color: noteScheme.onSurface,
                ),
              ),
              if (onPickPaperStyle != null)
                IconButton(
                  tooltip: 'Paper style',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedGrid,
                    color: noteScheme.onSurface,
                    size: 20,
                  ),
                  onPressed: onPickPaperStyle,
                ),
              if (onShowOutline != null)
                IconButton(
                  tooltip: 'Document outline',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMenuSquare,
                    color: noteScheme.onSurface,
                    size: 20,
                  ),
                  onPressed: onShowOutline,
                ),
              if (onInsertImage != null)
                IconButton(
                  tooltip: 'Insert image',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedImageAdd01,
                    color: noteScheme.onSurface,
                  ),
                  onPressed: onInsertImage,
                ),
              if (onInsertDoodle != null)
                IconButton(
                  tooltip: 'Insert doodle',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedDrawingMode,
                    color: note?.type == NoteType.doodle
                        ? noteScheme.primary
                        : noteScheme.onSurface,
                  ),
                  onPressed: onInsertDoodle,
                ),
              colorButton(compact: false),
              pinButton(compact: false),
              IconButton(
                tooltip: 'Export note',
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedShare01,
                  color: noteScheme.onSurface,
                  size: 20,
                ),
                onPressed: onExport,
              ),
              if (showFocusMode && onEnterFocusMode != null)
                IconButton(
                  tooltip: 'Focus mode',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedView,
                    color: noteScheme.onSurface,
                    size: 20,
                  ),
                  onPressed: onEnterFocusMode,
                ),
              IconButton(
                tooltip: 'More options',
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMore01,
                  color: noteScheme.onSurface,
                ),
                onPressed: onMoreOptions,
              ),
            ],
          ],
        );
      },
    );
  }

  String _subtitle(DateTime updatedAt) {
    final date = DateFormat('MMMM d, yyyy').format(updatedAt);
    final parts = <String>[];
    if (notebookName != null) {
      parts.add(notebookName!);
    }
    if (tagNames.isNotEmpty) {
      parts.addAll(tagNames.take(3).map((t) => '#$t'));
      if (tagNames.length > 3) {
        parts.add('+${tagNames.length - 3}');
      }
    }
    if (parts.isEmpty) return date;
    return '$date \u00b7 ${parts.join(' | ')}';
  }
}
