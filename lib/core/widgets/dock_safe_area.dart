import 'package:flutter/material.dart';

/// Safe-area information for content rendered underneath the shell dock.
///
/// This is intentionally separate from [MediaQuery.padding]. The dock is an
/// app overlay, not a system inset, so changing MediaQuery would corrupt
/// keyboard and modal-sheet layout calculations.
class DockSafeArea extends InheritedWidget {
  const DockSafeArea({
    super.key,
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DockSafeArea>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(DockSafeArea oldWidget) => bottom != oldWidget.bottom;
}
