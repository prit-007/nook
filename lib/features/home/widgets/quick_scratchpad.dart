import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/nook_tokens.dart';
import '../../../core/widgets/paper_texture_painter.dart';

/// Ephemeral quick-capture scratchpad drawer that lets users jot a thought
/// and either save it as a note or discard it cleanly.
class QuickScratchpad extends StatefulWidget {
  const QuickScratchpad({
    super.key,
    required this.isOpen,
    required this.onSaveAsNote,
    required this.onDiscard,
  });

  final bool isOpen;
  final ValueChanged<String> onSaveAsNote;
  final VoidCallback onDiscard;

  @override
  State<QuickScratchpad> createState() => _QuickScratchpadState();
}

class _QuickScratchpadState extends State<QuickScratchpad> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: AppMotion.standard,
      curve: AppMotion.emphasizedDecelerate,
      alignment: Alignment.topCenter,
      child: widget.isOpen
          ? Container(
              margin: const EdgeInsets.symmetric(
                horizontal: NookTokens.kSpacingLg,
                vertical: NookTokens.kSpacingSm,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: PaperSurface(
                pattern: PaperPattern.dotted,
                child: Padding(
                  padding: const EdgeInsets.all(NookTokens.kSpacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedSparkles,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: NookTokens.kSpacingSm),
                          Text(
                            'Quick Scratchpad',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NookTokens.kSpacingSm),
                      TextField(
                        controller: _controller,
                        maxLines: 3,
                        minLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Jot a quick thought...',
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: NookTokens.kSpacingSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              _controller.clear();
                              widget.onDiscard();
                            },
                            child: const Text('Discard'),
                          ),
                          const SizedBox(width: NookTokens.kSpacingSm),
                          FilledButton.tonal(
                            onPressed: () {
                              final text = _controller.text.trim();
                              if (text.isNotEmpty) {
                                widget.onSaveAsNote(text);
                                _controller.clear();
                              }
                            },
                            child: const Text('Save as Note'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
