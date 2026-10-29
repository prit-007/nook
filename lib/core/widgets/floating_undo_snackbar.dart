import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a floating Material 3 Undo SnackBar with haptics and rounded pill shape.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required Future<void> Function() onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  final scheme = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: scheme.inverseSurface,
      elevation: 6,
      content: Text(
        message,
        style: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      action: SnackBarAction(
        label: 'Undo',
        textColor: scheme.inversePrimary,
        onPressed: () {
          HapticFeedback.mediumImpact();
          onUndo();
        },
      ),
      duration: duration,
    ),
  );
}
