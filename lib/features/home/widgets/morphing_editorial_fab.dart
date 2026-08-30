import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../data/tables/notes.dart';

/// Editorial compose FAB that owns its full-screen scrim.
///
/// This widget expands to fill its parent and renders both the dimming /
/// blurring scrim and the floating action button + options menu itself, so
/// the menu state never gets desynced (or reset) by a sibling widget being
/// inserted into the parent stack.
class MorphingEditorialFab extends StatefulWidget {
  const MorphingEditorialFab({
    super.key,
    required this.onCreateNote,
    this.mobileBottomOffset = 130,
  });

  final void Function(NoteType type) onCreateNote;

  /// Offset from the bottom edge on compact (mobile) screens.
  ///
  /// When the FAB lives inside the AppShell mobile dock the shell already
  /// offsets the body by the full dock height, so callers only need a small
  /// gap above the body's bottom edge (e.g. 16). The default of 130 is kept
  /// for standalone use outside the shell.
  final double mobileBottomOffset;

  @override
  State<MorphingEditorialFab> createState() => _MorphingEditorialFabState();
}

class _MorphingEditorialFabState extends State<MorphingEditorialFab> {
  bool _isOpen = false;

  void _toggleMenu() {
    HapticFeedback.lightImpact();
    setState(() => _isOpen = !_isOpen);
  }

  void _selectType(NoteType type) {
    HapticFeedback.mediumImpact();
    setState(() => _isOpen = false);
    widget.onCreateNote(type);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final openDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
    final closeDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    return Stack(
      children: [
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _isOpen = false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        Positioned(
          right: isWide ? 32 : 16,
          bottom: isWide ? 32 : widget.mobileBottomOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedScale(
                scale: _isOpen ? 1.0 : 0.0,
                duration: openDuration,
                curve: Curves.easeOutBack,
                alignment: Alignment.bottomRight,
                child: AnimatedOpacity(
                  opacity: _isOpen ? 1.0 : 0.0,
                  duration: closeDuration,
                  child: _isOpen
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _MenuOption(
                                label: 'Canvas Doodle',
                                icon: HugeIcons.strokeRoundedPenTool01,
                                accentColor: scheme.tertiary,
                                onTap: () => _selectType(NoteType.doodle),
                              ),
                              const SizedBox(height: 12),
                              _MenuOption(
                                label: 'Interactive Checklist',
                                icon: HugeIcons.strokeRoundedCheckList,
                                accentColor: scheme.secondary,
                                onTap: () => _selectType(NoteType.checklist),
                              ),
                              const SizedBox(height: 12),
                              _MenuOption(
                                label: 'Quick Thought',
                                icon: HugeIcons.strokeRoundedEdit01,
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
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: HugeIcon(
                    icon: _isOpen
                        ? HugeIcons.strokeRoundedAdd01
                        : HugeIcons.strokeRoundedPencil,
                    size: 24,
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
  final List<List<dynamic>> icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: label,
      button: true,
      child: Material(
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
                  child: HugeIcon(icon: icon, size: 18, color: accentColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
