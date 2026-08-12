import 'package:flutter/material.dart';

import 'masked_reveal.dart';

/// Text convenience wrapper around [MaskedReveal] for macro typography.
///
/// The text slides up from behind a hard clip (an invisible baseline mask)
/// instead of simply fading in. Set [delay] to stagger multiple instances
/// (e.g. a title and its subtitle, or items in a grid).
class MaskedRevealText extends StatelessWidget {
  const MaskedRevealText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.duration = const Duration(milliseconds: 700),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.begin = const Offset(0, 1),
    this.fade = false,
    this.onComplete,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// How long the slide-up reveal takes once it starts.
  final Duration duration;

  /// Stagger delay before the reveal starts.
  final Duration delay;

  /// Easing of the slide-up reveal.
  final Curve curve;

  /// Start offset, as a fraction of the text's own height. `Offset(0, 1)`
  /// starts the text fully below its baseline so it is hidden by the mask.
  final Offset begin;

  /// Whether to additionally fade the text in. Defaults to a pure mask reveal.
  final bool fade;

  /// Called once the reveal animation completes (including [delay]).
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return MaskedReveal(
      duration: duration,
      delay: delay,
      curve: curve,
      begin: begin,
      fade: fade,
      onComplete: onComplete,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
