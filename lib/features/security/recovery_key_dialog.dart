import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/security/recovery_key_provider.dart';

/// Shows a dialog presenting the 24-word recovery key to the user.
///
/// Returns `true` if the user confirmed saving the key, or `false`/`null` if cancelled.
Future<bool?> showRecoveryKeyDialog(
  BuildContext context, {
  List<String>? words,
  VoidCallback? onConfirmed,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => RecoveryKeyDialog(
      words: words,
      onConfirmed: onConfirmed,
    ),
  );
}

/// A Material 3 dialog presenting the 24-word recovery key.
///
/// Features:
/// - Frosted glass backdrop blur.
/// - 24-word numbered grid chips.
/// - Prominent warning card ("Keys cannot be recovered if lost").
/// - "Copy to clipboard" affordance with haptic feedback.
/// - Mandatory safety confirmation checkbox before the confirm button is enabled.
/// - HugeIcons only, font size ≥12sp, min touch targets ≥48×48dp.
class RecoveryKeyDialog extends StatefulWidget {
  const RecoveryKeyDialog({
    super.key,
    this.words,
    this.onConfirmed,
  });

  /// The 24 recovery words to display. If omitted or null, a fresh 24-word
  /// mnemonic is generated automatically.
  final List<String>? words;

  /// Optional callback invoked when the user confirms having saved the phrase safely.
  final VoidCallback? onConfirmed;

  @override
  State<RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends State<RecoveryKeyDialog> {
  late final List<String> _words;
  bool _hasSaved = false;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _words = widget.words ?? generateRecoveryKey();
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    unawaited(HapticFeedback.lightImpact());
    await Clipboard.setData(ClipboardData(text: _words.join(' ')));
    if (!mounted) return;
    setState(() {
      _copied = true;
    });
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Title & Copy Button
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedKey01,
                        color: scheme.onPrimaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vault Recovery Key',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '24-word backup phrase',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Copy to clipboard affordance with min 48x48 touch target
                    Tooltip(
                      message: _copied ? 'Copied!' : 'Copy to clipboard',
                      child: IconButton(
                        onPressed: _copyToClipboard,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.all(12),
                          backgroundColor: _copied
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                        ),
                        icon: HugeIcon(
                          icon: _copied
                              ? HugeIcons.strokeRoundedCheckmarkCircle01
                              : HugeIcons.strokeRoundedCopy01,
                          color: _copied ? scheme.primary : scheme.onSurface,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Prominent warning card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedAlertCircle,
                          color: scheme.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keep this recovery key safe!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Keys cannot be recovered if lost. Anyone with these 24 words can unlock and access all your sensitive notes.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Numbered words grid (Scrollable)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          scheme.surfaceContainerLowest.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Table(
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          for (var row = 0; row < 12; row++)
                            TableRow(
                              children: [
                                _buildWordChip(
                                  scheme,
                                  index: row + 1,
                                  word: _words[row],
                                ),
                                const SizedBox(width: 8),
                                _buildWordChip(
                                  scheme,
                                  index: row + 13,
                                  word: _words[row + 12],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Safety confirmation checkbox with min 48px height target
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _hasSaved = !_hasSaved;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _hasSaved,
                          activeColor: scheme.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _hasSaved = val ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'I have saved my recovery key safely',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Action buttons: Cancel & Done (Confirm)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      onPressed: _hasSaved
                          ? () {
                              widget.onConfirmed?.call();
                              Navigator.of(context).pop(true);
                            }
                          : null,
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordChip(
    ColorScheme scheme, {
    required int index,
    required String word,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$index.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                word,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
