import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'doodle_controller.dart';

class DoodleToolbar extends StatelessWidget {
  const DoodleToolbar({
    super.key,
    required this.controller,
    this.noteScheme,
  });

  final DoodleController controller;
  final ColorScheme? noteScheme;

  @override
  Widget build(BuildContext context) {
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
                border: Border.all(
                  color: (noteScheme?.outlineVariant ?? scheme.outlineVariant)
                      .withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
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
                      Icon(
                        LucideIcons.penLine,
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
                      Icon(
                        LucideIcons.penLine,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
