import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/tables/notes.dart';

class MorphingEditorialFab extends StatefulWidget {
  const MorphingEditorialFab({
    super.key,
    required this.onCreateNote,
    this.onMenuToggle,
  });

  final void Function(NoteType type) onCreateNote;
  final ValueChanged<bool>? onMenuToggle;

  @override
  State<MorphingEditorialFab> createState() => _MorphingEditorialFabState();
}

class _MorphingEditorialFabState extends State<MorphingEditorialFab> {
  bool _isOpen = false;

  void _toggleMenu() {
    HapticFeedback.lightImpact();
    setState(() => _isOpen = !_isOpen);
    widget.onMenuToggle?.call(_isOpen);
  }

  void _selectType(NoteType type) {
    HapticFeedback.mediumImpact();
    setState(() => _isOpen = false);
    widget.onMenuToggle?.call(false);
    widget.onCreateNote(type);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedScale(
          scale: _isOpen ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          alignment: Alignment.bottomRight,
          child: AnimatedOpacity(
            opacity: _isOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _isOpen
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MenuOption(
                          label: 'Canvas Doodle',
                          icon: Icons.gesture_rounded,
                          accentColor: scheme.tertiary,
                          onTap: () => _selectType(NoteType.doodle),
                        ),
                        const SizedBox(height: 12),
                        _MenuOption(
                          label: 'Interactive Checklist',
                          icon: Icons.checklist_rounded,
                          accentColor: scheme.secondary,
                          onTap: () => _selectType(NoteType.checklist),
                        ),
                        const SizedBox(height: 12),
                        _MenuOption(
                          label: 'Quick Thought',
                          icon: Icons.edit_note_rounded,
                          accentColor: scheme.primary,
                          onTap: () => _selectType(NoteType.text),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        FloatingActionButton.extended(
          onPressed: _toggleMenu,
          elevation: 4,
          backgroundColor: _isOpen ? scheme.surface : scheme.primary,
          foregroundColor: _isOpen ? scheme.onSurface : scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          icon: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _isOpen ? Icons.add_rounded : Icons.create_rounded,
            ),
          ),
          label: Text(
            _isOpen ? 'Close' : 'New Note',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
