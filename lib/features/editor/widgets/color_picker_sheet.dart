import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/semantics.dart';

/// Bottom sheet for picking a note's seed color.
/// Returns the selected hex string on pop, or null if cancelled.
class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({super.key, this.currentSeed});

  final String? currentSeed;

  static Future<String?> show(BuildContext context, {String? currentSeed}) {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ColorPickerSheet(currentSeed: currentSeed),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentSeed != null
        ? NookColors.parseHex(widget.currentSeed)
        : null;
  }

  String _hexFromColor(Color color) =>
      color.toARGB32().toRadixString(16).substring(2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _selectedColor = null);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHighest,
                    border: _selectedColor == null
                        ? Border.all(color: scheme.primary, width: 3)
                        : null,
                  ),
                  child: _selectedColor == null
                      ? HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                          color: scheme.primary,
                          size: 20)
                      : HugeIcon(
                          icon: HugeIcons.strokeRoundedCancelCircle,
                          color: scheme.onSurface.withValues(alpha: 0.3),
                          size: 18,
                        ),
                ),
              ),
              // Color swatches
              for (int i = 0; i < NookColors.seeds.length; i++)
                GestureDetector(
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _selectedColor = NookColors.seeds[i]);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NookColors.seeds[i],
                      border: _selectedColor == NookColors.seeds[i]
                          ? Border.all(color: scheme.onSurface, width: 3)
                          : null,
                      boxShadow: _selectedColor == NookColors.seeds[i]
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
                    child: _selectedColor == NookColors.seeds[i]
                        ? HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                            color: NookSemantics.contrastForeground(
                                NookColors.seeds[i]),
                            size: 20,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                Navigator.pop(
                  context,
                  _selectedColor != null ? _hexFromColor(_selectedColor!) : '',
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
