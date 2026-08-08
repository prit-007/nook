import 'package:flutter/material.dart';

import 'doodle_controller.dart';

/// Toolbar for the doodle canvas with tool selection, colors, undo/redo.
class DoodleToolbar extends StatelessWidget {
  const DoodleToolbar({super.key, required this.controller});

  final DoodleController controller;

  static const _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tools row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ToolButton(
                      icon: Icons.brush,
                      label: 'Pen',
                      isSelected: controller.currentTool == DoodleTool.pen,
                      onTap: () =>
                          controller.setCurrentTool(DoodleTool.pen),
                    ),
                    _ToolButton(
                      icon: Icons.auto_fix_high,
                      label: 'Eraser',
                      isSelected: controller.currentTool == DoodleTool.eraser,
                      onTap: () =>
                          controller.setCurrentTool(DoodleTool.eraser),
                    ),
                    _ToolButton(
                      icon: Icons.highlight,
                      label: 'Highlight',
                      isSelected:
                          controller.currentTool == DoodleTool.highlighter,
                      onTap: () =>
                          controller.setCurrentTool(DoodleTool.highlighter),
                    ),
                    const SizedBox(width: 16),
                    // Undo / Redo
                    IconButton(
                      icon: const Icon(Icons.undo, size: 22),
                      onPressed: controller.canUndo ? controller.undo : null,
                      tooltip: 'Undo',
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo, size: 22),
                      onPressed: controller.canRedo ? controller.redo : null,
                      tooltip: 'Redo',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 22, color: scheme.error),
                      onPressed: controller.strokes.isNotEmpty
                          ? controller.clear
                          : null,
                      tooltip: 'Clear all',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Colors + width row
                Row(
                  children: [
                    // Color swatches
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _colors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final color = _colors[index];
                            final isSelected =
                                controller.currentColor == color;
                            return GestureDetector(
                              onTap: () =>
                                  controller.setCurrentColor(color),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(
                                    color: isSelected
                                        ? scheme.onSurface
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Width slider
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: controller.currentWidth,
                        min: 1,
                        max: 20,
                        onChanged: controller.setCurrentWidth,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
