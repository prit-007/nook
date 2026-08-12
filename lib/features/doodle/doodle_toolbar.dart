import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'doodle_controller.dart';

class DoodleToolbar extends StatelessWidget {
  const DoodleToolbar({super.key, required this.controller});

  final DoodleController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final colors = [
      scheme.onSurface,
      scheme.surface,
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.amber,
      Colors.deepPurpleAccent,
    ];

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Pen tool',
                        button: true,
                        selected: controller.currentTool == DoodleTool.pen,
                        child: _TactileTool(
                          icon: LucideIcons.penLine,
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
                          icon: LucideIcons.highlighter,
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
                          icon: LucideIcons.eraser,
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
                          icon: LucideIcons.wandSparkles,
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
                          icon: Icon(
                            LucideIcons.trash2,
                            color: scheme.error,
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
                    child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: colors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final color = colors[index];
                        final isSelected = controller.currentColor == color;
                        return Semantics(
                          label: 'Color ${index + 1}',
                          button: true,
                          selected: isSelected,
                          child: GestureDetector(
                            onTap: () => controller.setCurrentColor(color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              width: isSelected ? 32 : 24,
                              height: isSelected ? 32 : 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                border: Border.all(
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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

class _TactileTool extends StatelessWidget {
  const _TactileTool({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final IconData icon;
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
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? color : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
