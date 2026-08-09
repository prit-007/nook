import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/database.dart';
import '../../../data/tables/notes.dart';

class NoteMinimalCard extends StatefulWidget {
  const NoteMinimalCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  State<NoteMinimalCard> createState() => _NoteMinimalCardState();
}

class _NoteMinimalCardState extends State<NoteMinimalCard> {
  bool _isPressed = false;

  Color _seedColor(BuildContext context) {
    if (widget.note.colorSeed != null) {
      final seed = Color(
        int.parse(
          'FF${widget.note.colorSeed!.replaceFirst('#', '')}',
          radix: 16,
        ),
      );
      return ColorScheme.fromSeed(seedColor: seed).primaryContainer;
    }
    return Theme.of(context).colorScheme.surfaceContainerLow;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardBg = _seedColor(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Hero(
          tag: 'note-${widget.note.id}',
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: cardBg.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(_typeIcon, size: 15, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          _typeLabel,
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    if (widget.note.pinned)
                      Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.note.locked)
                  _lockedPreview(scheme)
                else
                  Text(
                    widget.note.title.isEmpty
                        ? (widget.note.plainText ?? 'Untitled')
                        : (widget.note.plainText ?? widget.note.title),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _typeIcon => switch (widget.note.type) {
        NoteType.checklist => Icons.checklist_rounded,
        NoteType.doodle => Icons.draw_rounded,
        NoteType.mixed => Icons.layers_rounded,
        NoteType.text => Icons.notes_rounded,
      };

  String get _typeLabel => switch (widget.note.type) {
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
        NoteType.text => 'Quick Thought',
      };

  Widget _lockedPreview(ColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 44,
          color: scheme.surface.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Biometrics required',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
