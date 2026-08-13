import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/semantics.dart';

/// Bottom sheet for picking a note's seed color.
/// Returns the selected hex string on pop, or null if cancelled.
class ColorPickerSheet extends StatelessWidget {
  const ColorPickerSheet({super.key, this.currentSeed});

  final String? currentSeed;

  static Future<String?> show(BuildContext context, {String? currentSeed}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ColorPickerSheet(currentSeed: currentSeed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentColor =
        currentSeed != null ? NookColors.parseHex(currentSeed) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Note Color',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a seed color for this note',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // "None" option
              GestureDetector(
                onTap: () => Navigator.pop(context, ''),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHighest,
                    border: currentColor == null
                        ? Border.all(color: scheme.primary, width: 3)
                        : null,
                  ),
                  child: currentColor == null
                      ? Icon(Icons.check, color: scheme.primary, size: 20)
                      : Icon(
                          Icons.close,
                          color: scheme.onSurface.withValues(alpha: 0.3),
                          size: 18,
                        ),
                ),
              ),
              // Color swatches
              for (int i = 0; i < NookColors.seeds.length; i++)
                GestureDetector(
                  onTap: () => Navigator.pop(
                    context,
                    NookColors.seeds[i]
                        .toARGB32()
                        .toRadixString(16)
                        .substring(2),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NookColors.seeds[i],
                      border: currentColor == NookColors.seeds[i]
                          ? Border.all(color: scheme.onSurface, width: 3)
                          : null,
                      boxShadow: currentColor == NookColors.seeds[i]
                          ? [
                              BoxShadow(
                                color:
                                    NookColors.seeds[i].withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: currentColor == NookColors.seeds[i]
                        ? Icon(
                            Icons.check,
                            color: NookSemantics.contrastForeground(
                                NookColors.seeds[i]),
                            size: 20,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
