import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/database.dart';
import '../../../data/repositories/notebook_repository.dart';

/// Editorial "magazine cover" notebook card.
///
/// Portrait orientation with macro typography; the cover is tinted by the
/// dominant color extracted from the notebook's most recent image, falling
/// back to the notebook's own colorSeed.
class NotebookCard extends ConsumerStatefulWidget {
  const NotebookCard({
    super.key,
    required this.notebook,
    this.noteCount = 0,
  });

  final Notebook notebook;
  final int noteCount;

  @override
  ConsumerState<NotebookCard> createState() => _NotebookCardState();
}

class _NotebookCardState extends ConsumerState<NotebookCard> {
  Color? _dominantColor;

  Color get _seedColor => NookColors.parseHex(widget.notebook.colorSeed);

  @override
  void initState() {
    super.initState();
    _extractCoverColor();
  }

  Future<void> _extractCoverColor() async {
    final repo = NotebookRepository(ref.read(databaseProvider));
    final attachment = await repo.getLatestImageForNotebook(widget.notebook.id);
    if (attachment == null || !mounted) return;
    final path = attachment.thumbnailPath ?? attachment.filePath;
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(FileImage(file));
      final color = palette.dominantColor?.color;
      if (mounted && color != null) {
        setState(() => _dominantColor = color);
      }
    } catch (_) {
      // Fall back to the notebook's seed color when the image is unreadable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = ColorScheme.fromSeed(seedColor: _seedColor);
    final coverColor = _dominantColor ?? base.surfaceContainerLow;

    return Container(
      decoration: BoxDecoration(
        color: coverColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: coverColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _seedColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'NOTEBOOK',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: _seedColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.notebook.name,
                  style: TextStyle(
                    fontSize: 34,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.noteCount} note${widget.noteCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
