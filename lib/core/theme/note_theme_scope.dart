import 'package:flutter/material.dart';

/// InheritedWidget that provides the current note's derived ColorScheme
/// to all child widgets (editor blocks, toolbar, etc.).
class NoteThemeScope extends InheritedWidget {
  const NoteThemeScope({
    super.key,
    required this.colorScheme,
    required super.child,
  });

  final ColorScheme colorScheme;

  static ColorScheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NoteThemeScope>();
    assert(scope != null, 'No NoteThemeScope found in context');
    return scope!.colorScheme;
  }

  @override
  bool updateShouldNotify(NoteThemeScope oldWidget) {
    return colorScheme != oldWidget.colorScheme;
  }
}
