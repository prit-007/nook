import 'package:flutter/material.dart';

import '../../../core/theme/note_theme_scope.dart';

/// A small circular delete button for media blocks (doodles, images).
///
/// Designed to be positioned in a [Stack] with [Positioned] to overlay
/// the top-right corner of a media block or attachment thumbnail.
class MediaDeleteButton extends StatelessWidget {
  const MediaDeleteButton({
    super.key,
    required this.onPressed,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    return Tooltip(
      message: tooltip ?? 'Delete',
      child: Material(
        color: scheme.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
