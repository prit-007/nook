import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// A modern, tactile 3-way segmented control for switching theme modes
/// (System, Light, Dark) with iconography and haptic feedback.
class ThemeModeSegmentedBar extends StatelessWidget {
  const ThemeModeSegmentedBar({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          for (final mode in ThemeMode.values)
            Expanded(
              child: _ModeSegment(
                mode: mode,
                isSelected: currentMode == mode,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onModeSelected(mode);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  List<List<dynamic>> get _icon {
    switch (mode) {
      case ThemeMode.system:
        return HugeIcons.strokeRoundedSmartPhone01;
      case ThemeMode.light:
        return HugeIcons.strokeRoundedSun01;
      case ThemeMode.dark:
        return HugeIcons.strokeRoundedMoon01;
    }
  }

  String get _label {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$_label theme mode',
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: _icon,
                  color:
                      isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(height: 5),
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
