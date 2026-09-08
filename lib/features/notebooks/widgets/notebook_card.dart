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
/// Refined with macro typography, light-aware contrast,
/// frosted glass pill metadata, and a physical cover spine edge.
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
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(file),
        maximumColorCount: 8,
      );
      final color = palette.dominantColor?.color;
      if (mounted && color != null) {
        setState(() => _dominantColor = color);
      }
    } catch (_) {
      // Fall back to seed color when unreadable
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Theme.of(context).brightness,
    );
    final coverColor = _dominantColor ?? baseScheme.surfaceContainerLow;

    // Determine legibility colors based on the cover luminance
    final isDarkCover = coverColor.computeLuminance() < 0.45;
    final textColor = isDarkCover ? Colors.white : const Color(0xFF1A1A1A);
    final subtextColor = isDarkCover
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF1A1A1A).withValues(alpha: 0.65);

    return Container(
      decoration: BoxDecoration(
        color: coverColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: coverColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle radial glow element in top right
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    textColor.withValues(alpha: 0.12),
                    textColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Simulated book spine lighting edge (left side)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    textColor.withValues(alpha: 0.25),
                    textColor.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),

          // Card Content Layout
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Frosted Glass Header Badge
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'NOTEBOOK',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: textColor,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Macro Magazine Title (Playfair Serif). Flexible so long names
                // ellipsize instead of overflowing short portrait cards.
                Flexible(
                  child: Text(
                    widget.notebook.name,
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 32,
                      height: 0.95,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: textColor,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 12),

                // Note Count Label
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _seedColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${widget.noteCount} ${widget.noteCount == 1 ? 'entry' : 'entries'}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: subtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
