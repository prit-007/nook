import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/nook_tokens.dart';
import '../../templates/template_picker_sheet.dart';

/// Quick-capture bar anchored above the notes list.
///
/// Gives users instant capture affordances for thoughts, checklists, doodles,
/// and templates without opening a secondary menu.
class QuickCaptureBar extends StatelessWidget {
  const QuickCaptureBar({
    super.key,
    this.margin,
  });

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding:
          margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
          borderRadius: context.tokens.borderRadiusXl,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Quick note capture',
                hint: 'Opens a new text thought',
                child: InkWell(
                  borderRadius: context.tokens.borderRadiusLg,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/note/new?type=text');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Capture a thought...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _QuickActionButton(
              icon: HugeIcons.strokeRoundedCheckmarkSquare02,
              tooltip: 'New checklist',
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/note/new?type=checklist');
              },
            ),
            _QuickActionButton(
              icon: HugeIcons.strokeRoundedPen01,
              tooltip: 'New doodle',
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/note/new?type=doodle');
              },
            ),
            _QuickActionButton(
              icon: HugeIcons.strokeRoundedLayers01,
              tooltip: 'From template',
              onTap: () {
                HapticFeedback.lightImpact();
                showTemplatePickerSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: HugeIcon(
        icon: icon,
        size: 20,
        color: scheme.primary,
      ),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
    );
  }
}
