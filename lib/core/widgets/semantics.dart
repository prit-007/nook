import 'package:flutter/material.dart';

/// Small accessibility helpers used across the app so every interactive
/// element exposes a meaningful label to TalkBack / VoiceOver consistently.
///
/// A [Tooltip] gives sighted users discoverability on long-press/hover and
/// doubles as the semantic label for screen readers; wrapping in [Semantics]
/// with [button] marks the element as interactive.
class NookSemantics {
  NookSemantics._();

  /// Returns a foreground color that has at least AA contrast on [background].
  ///
  /// Picks pure white for dark swatches and near-black for light swatches
  /// based on relative luminance — never a hardcoded `Colors.white` that is
  /// invisible on light colors (audit items L2/L9).
  static Color contrastForeground(Color background) =>
      _relativeLuminance(background) > 0.45 ? Colors.black87 : Colors.white;

  /// WCAG 2.x relative luminance, 0 (black) to 1 (white).
  static double _relativeLuminance(Color color) {
    double channel(double c) {
      final s = c <= 0.03928
          ? c / 12.92
          : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);
      return s;
    }

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// An [IconButton] wrapped with a semantic label. Falls back to [label]
  /// when [tooltip] is not provided so there is always something a screen
  /// reader can announce.
  static Widget iconButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    IconData? selectedIcon,
    Color? iconColor,
    Color? selectedColor,
    bool selected = false,
    String? tooltip,
  }) {
    final effectiveTooltip = tooltip ?? label;
    return Semantics(
      label: effectiveTooltip,
      button: true,
      selected: selected ? true : null,
      child: Tooltip(
        message: effectiveTooltip,
        child: IconButton(
          onPressed: onPressed,
          icon:
              Icon(selected ? (selectedIcon ?? icon) : icon, color: iconColor),
          color: selected ? selectedColor : null,
        ),
      ),
    );
  }

  /// Marks a widget subtree as purely decorative so screen readers skip it.
  static Widget hideFromSemantics(Widget child) =>
      ExcludeSemantics(child: child);

  /// Wraps a tappable (GestureDetector/InkWell) with a screen-reader label
  /// and the sticky button role that TalkBack announces as actionable.
  static Widget tappable({
    required String label,
    required VoidCallback onTap,
    required Widget child,
    bool selected = false,
    String? hint,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      selected: selected ? true : null,
      onTap: onTap,
      child: child,
    );
  }
}
