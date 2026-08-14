import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'doodle_controller.dart';

class DoodleToolbar extends StatefulWidget {
  const DoodleToolbar({
    super.key,
    required this.controller,
    this.noteScheme,
  });

  final DoodleController controller;
  final ColorScheme? noteScheme;

  @override
  State<DoodleToolbar> createState() => _DoodleToolbarState();
}

class _DoodleToolbarState extends State<DoodleToolbar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final noteScheme = widget.noteScheme;
    final scheme = noteScheme ?? Theme.of(context).colorScheme;

    final colors = [
      scheme.onSurface,
      scheme.surface,
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.amber,
      Colors.greenAccent,
      Colors.blueAccent,
      Colors.indigoAccent,
      Colors.deepPurpleAccent,
      Colors.pinkAccent,
    ];

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Collapsed: a compact pill carrying only the expand arrow so it can
        // never obstruct the canvas while drawing.
        if (!_expanded) {
          return _CollapsedHandle(
            noteScheme: noteScheme ?? scheme,
            onTap: () => setState(() => _expanded = true),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: (noteScheme?.surfaceContainerHighest ??
                        scheme.surfaceContainerHighest)
                    .withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Collapse toolbar',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _expanded = false),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowDown01,
                        color: scheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Pen tool',
                        button: true,
                        selected: controller.currentTool == DoodleTool.pen,
                        child: _TactileTool(
                          icon: HugeIcons.strokeRoundedPen01,
                          isSelected: controller.currentTool == DoodleTool.pen,
                          onTap: () =>
                              controller.setCurrentTool(DoodleTool.pen),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Highlighter tool',
                        button: true,
                        selected:
                            controller.currentTool == DoodleTool.highlighter,
                        child: _TactileTool(
                          icon: HugeIcons.strokeRoundedHighlighter,
                          isSelected:
                              controller.currentTool == DoodleTool.highlighter,
                          onTap: () =>
                              controller.setCurrentTool(DoodleTool.highlighter),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Eraser tool',
                        button: true,
                        selected: controller.currentTool == DoodleTool.eraser,
                        child: _TactileTool(
                          icon: HugeIcons.strokeRoundedEraser01,
                          isSelected:
                              controller.currentTool == DoodleTool.eraser,
                          onTap: () =>
                              controller.setCurrentTool(DoodleTool.eraser),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: 1,
                          height: 24,
                          color: scheme.outlineVariant,
                        ),
                      ),
                      Semantics(
                        label: 'Shape assist',
                        button: true,
                        selected: controller.shapeAssistEnabled,
                        child: _TactileTool(
                          icon: HugeIcons.strokeRoundedMagicWand01,
                          isSelected: controller.shapeAssistEnabled,
                          onTap: () => controller.toggleShapeAssist(),
                          activeColor: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Clear all strokes',
                        button: true,
                        child: IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            color: scheme.error,
                            size: 24,
                          ),
                          onPressed: controller.strokes.isNotEmpty
                              ? controller.clear
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var i = 0; i < colors.length; i++) ...[
                            _ColorSwatch(
                              color: colors[i],
                              isSelected: controller.currentColor == colors[i],
                              onTap: () =>
                                  controller.setCurrentColor(colors[i]),
                            ),
                            if (i < colors.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPen01,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14,
                            ),
                          ),
                          child: Slider(
                            value: controller.currentWidth,
                            min: 1.0,
                            max: 20.0,
                            onChanged: (value) =>
                                controller.setCurrentWidth(value),
                          ),
                        ),
                      ),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPen01,
                        size: 24,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact floating handle shown while the toolbar is collapsed. It is a tiny
/// frosted circle carrying only the expand arrow, so it can never cover the
/// canvas drawing surface.
class _CollapsedHandle extends StatelessWidget {
  const _CollapsedHandle({required this.noteScheme, required this.onTap});

  final ColorScheme noteScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Expand toolbar',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: noteScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: noteScheme.outlineVariant.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowUp01,
              size: 22,
              color: noteScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isSelected ? 36 : 28,
        height: isSelected ? 36 : 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 3 : 1,
          ),
          // Keep one shadow in both states. Interpolating a shadow list with
          // null during a theme/color change can produce a negative blur.
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isSelected ? 0.4 : 0),
              blurRadius: isSelected ? 12 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TactileTool extends StatelessWidget {
  const _TactileTool({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final List<List<dynamic>> icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = activeColor ?? scheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, isSelected ? -8 : 0, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: HugeIcon(
          icon: icon,
          size: 24,
          color: isSelected ? color : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
