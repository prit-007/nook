import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const List<double> _strokePresets = [2.0, 5.0, 10.0, 16.0];

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
            currentColor: controller.currentColor,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = true);
            },
          );
        }

        final brushPreviewColor = controller.currentTool == DoodleTool.eraser
            ? scheme.outlineVariant
            : controller.currentTool == DoodleTool.highlighter
                ? controller.currentColor.withValues(alpha: 0.4)
                : controller.currentColor;

        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                color: (noteScheme?.surfaceContainerHighest ??
                        scheme.surfaceContainerHighest)
                    .withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: (noteScheme?.outlineVariant ?? scheme.outlineVariant)
                      .withValues(alpha: 0.3),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Top Collapse Bar ──────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Active tool mode indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              scheme.surfaceContainerLow.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: brushPreviewColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              switch (controller.currentTool) {
                                DoodleTool.pen => 'Pen',
                                DoodleTool.highlighter => 'Highlighter',
                                DoodleTool.eraser => 'Eraser',
                                DoodleTool.shapeAssist => 'Shape Assist',
                              },
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${controller.currentWidth.toStringAsFixed(0)}px',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Collapse toolbar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _expanded = false);
                        },
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          color: scheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Primary Tools Row ──────────────────────────────────────
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
                          activeColor: scheme.primary,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.setCurrentTool(DoodleTool.pen);
                          },
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
                          activeColor: scheme.primary,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.setCurrentTool(DoodleTool.highlighter);
                          },
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
                          activeColor: scheme.error,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.setCurrentTool(DoodleTool.eraser);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Container(
                          width: 1,
                          height: 24,
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      Semantics(
                        label: 'Shape assist',
                        button: true,
                        selected: controller.shapeAssistEnabled,
                        child: _TactileTool(
                          icon: HugeIcons.strokeRoundedMagicWand01,
                          isSelected: controller.shapeAssistEnabled,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.toggleShapeAssist();
                          },
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
                            size: 22,
                          ),
                          onPressed: controller.strokes.isNotEmpty
                              ? () {
                                  HapticFeedback.mediumImpact();
                                  controller.clear();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Color Swatches ─────────────────────────────────────────
                  SizedBox(
                    height: 44,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var i = 0; i < colors.length; i++) ...[
                            _ColorSwatch(
                              color: colors[i],
                              isSelected: controller.currentColor == colors[i],
                              onTap: () {
                                HapticFeedback.lightImpact();
                                controller.setCurrentColor(colors[i]);
                              },
                            ),
                            if (i < colors.length - 1)
                              const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Stroke Width Controls & Live Brush Tip Preview ─────────
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPen01,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                              elevation: 2,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                            activeTrackColor: scheme.primary,
                            inactiveTrackColor: scheme.surfaceContainerLow,
                            thumbColor: scheme.primary,
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
                      const SizedBox(width: 4),
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPen01,
                        size: 24,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      // Live brush tip preview circle
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surfaceContainerLow,
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: controller.currentWidth.clamp(3.0, 22.0),
                          height: controller.currentWidth.clamp(3.0, 22.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: brushPreviewColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Preset width pills
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final width in _strokePresets) ...[
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.setCurrentWidth(width);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color:
                                  (controller.currentWidth - width).abs() < 0.6
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerLow
                                          .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              switch (width) {
                                2.0 => 'Fine',
                                5.0 => 'Medium',
                                10.0 => 'Bold',
                                _ => 'Marker',
                              },
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    (controller.currentWidth - width).abs() <
                                            0.6
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color: (controller.currentWidth - width).abs() <
                                        0.6
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
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
/// frosted pill carrying only the expand arrow, so it can never cover the
/// canvas drawing surface.
class _CollapsedHandle extends StatelessWidget {
  const _CollapsedHandle({
    required this.noteScheme,
    required this.onTap,
    this.currentColor,
  });

  final ColorScheme noteScheme;
  final VoidCallback onTap;
  final Color? currentColor;

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: noteScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: noteScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowUp01,
                  size: 20,
                  color: noteScheme.onSurfaceVariant,
                ),
                if (currentColor != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentColor,
                    ),
                  ),
                ],
              ],
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
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: isSelected ? 34 : 28,
          height: isSelected ? 34 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.45 : 0),
                blurRadius: isSelected ? 12 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, isSelected ? -4 : 0, 0),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : scheme.surfaceContainerLow.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: HugeIcon(
          icon: icon,
          size: 22,
          color: isSelected ? color : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
