import 'package:flutter/material.dart';

/// An accessible, high-visibility Material 3 focus ring that decorates [child]
/// when it gains keyboard focus.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.focusNode,
    this.borderRadius,
    this.ringColor,
    this.ringWidth = 2.0,
    this.onFocusChange,
  });

  final Widget child;
  final FocusNode? focusNode;
  final BorderRadius? borderRadius;
  final Color? ringColor;
  final double ringWidth;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.ringColor ?? scheme.primary;
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        widget.onFocusChange?.call(focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: _isFocused
              ? Border.all(color: color, width: widget.ringWidth)
              : Border.all(color: Colors.transparent, width: widget.ringWidth),
        ),
        child: widget.child,
      ),
    );
  }
}
