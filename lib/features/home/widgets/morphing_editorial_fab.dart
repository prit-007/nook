import 'package:flutter/material.dart';

import '../../../data/tables/notes.dart';

/// Morphing editorial FAB that expands into a staggered menu.
/// Uses AnimatedScale + AnimatedOpacity for smooth open/close transitions.
class MorphingEditorialFab extends StatefulWidget {
  const MorphingEditorialFab({super.key, required this.onCreateNote});

  final void Function(NoteType type) onCreateNote;

  @override
  State<MorphingEditorialFab> createState() => _MorphingEditorialFabState();
}

class _MorphingEditorialFabState extends State<MorphingEditorialFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  void _toggleMenu() {
    setState(() => _isOpen = !_isOpen);
  }

  void _selectType(NoteType type) {
    setState(() => _isOpen = false);
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
          duration: const Duration(milliseconds: 250),
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
                          onTap: () => _selectType(NoteType.doodle),
                        ),
                        const SizedBox(height: 12),
                        _MenuOption(
                          label: 'Interactive Checklist',
                          icon: Icons.checklist_rounded,
                          onTap: () => _selectType(NoteType.checklist),
                        ),
                        const SizedBox(height: 12),
                        _MenuOption(
                          label: 'Quick Text Note',
                          icon: Icons.edit_note_rounded,
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
          elevation: 0,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isOpen ? Icons.add_rounded : Icons.create_rounded),
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 20, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
