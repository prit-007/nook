import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';

/// A floating, glassmorphic "Quick Note" overlay for rapid capture.
///
/// Designed for desktop users who want to jot down fleeting thoughts or
/// paste code snippets without leaving their current context. Opens as a
/// modal route with a translucent backdrop and minimal chrome.
///
/// The overlay auto-saves after a short debounce, so the user can type
/// and dismiss without explicitly saving.
class QuickNoteOverlay extends ConsumerStatefulWidget {
  const QuickNoteOverlay({super.key});

  @override
  ConsumerState<QuickNoteOverlay> createState() => _QuickNoteOverlayState();
}

class _QuickNoteOverlayState extends ConsumerState<QuickNoteOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _saved = false;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field for instant typing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    try {
      final db = ref.read(databaseProvider);
      final repo = NoteRepository(db);
      await repo.createNote(
        title: text.split('\n').first,
        type: NoteType.text,
        deviceOriginId: 'local',
        deltaContent: null,
        plainText: text,
      );
      nookLog(NookLogKey.editor, 'Quick note saved: ${text.length} chars',
          LogLevel.info);
      if (mounted) {
        setState(() => _saved = true);
        // Brief delay so the user sees the checkmark before dismissal.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      nookLog(NookLogKey.editor, 'Quick note save failed: $e', LogLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Frosted backdrop
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.black.withValues(alpha: 0.4)),
              ),
            ),

            // Quick Note card — centered, glassmorphic
            Center(
              child: GestureDetector(
                onTap: () {}, // Absorb taps on the card itself.
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, topPadding + 48, 24, 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 16, 0),
                                child: Row(
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedEdit02,
                                      size: 20,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Quick Note',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_saved)
                                      HugeIcon(
                                        icon: HugeIcons
                                            .strokeRoundedCheckmarkCircle01,
                                        size: 20,
                                        color: scheme.primary,
                                      )
                                    else
                                      Text(
                                        'Esc to close',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Text field
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  maxLines: 8,
                                  minLines: 4,
                                  onChanged: (_) => _scheduleAutoSave(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: scheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Start typing a quick note...',
                                    hintStyle: TextStyle(
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),

                              // Footer
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                child: Row(
                                  children: [
                                    Text(
                                      'Auto-saves',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: _save,
                                      child: const Text('Save & Close'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the quick note overlay as a modal route.
Future<void> showQuickNoteOverlay(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Quick Note',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return const QuickNoteOverlay();
    },
  );
}
