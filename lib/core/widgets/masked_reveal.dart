import 'package:flutter/material.dart';

/// GSAP-style masked reveal for any widget.
///
/// The child slides up from behind a hard clip (an invisible baseline mask)
/// instead of simply fading in, giving content a tactile, editorial entrance.
/// Set [delay] to stagger multiple instances (e.g. a title and its subtitle,
/// or items in a grid).
class MaskedReveal extends StatefulWidget {
  const MaskedReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 700),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.begin = const Offset(0, 1),
    this.fade = false,
    this.onComplete,
  });

  final Widget child;

  /// How long the slide-up reveal takes once it starts.
  final Duration duration;

  /// Stagger delay before the reveal starts.
  final Duration delay;

  /// Easing of the slide-up reveal.
  final Curve curve;

  /// Start offset, as a fraction of the child's own height. `Offset(0, 1)`
  /// starts the child fully below its baseline so it is hidden by the mask.
  final Offset begin;

  /// Whether to additionally fade the child in. Defaults to a pure mask reveal.
  final bool fade;

  /// Called once the reveal animation completes (including [delay]).
  final VoidCallback? onComplete;

  @override
  State<MaskedReveal> createState() => _MaskedRevealState();
}

class _MaskedRevealState extends State<MaskedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    final start = total == Duration.zero
        ? 0.0
        : widget.delay.inMicroseconds / total.inMicroseconds;

    _controller = AnimationController(
      vsync: this,
      duration: total,
    );
    _slide = Tween<Offset>(begin: widget.begin, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, 1.0, curve: widget.curve),
      ),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: Curves.easeOut),
    );

    _controller.forward().whenCompleteOrCancel(() {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce-motion: render the final state immediately, no reveal.
      return widget.child;
    }
    Widget child = SlideTransition(
      position: _slide,
      child: widget.child,
    );
    if (widget.fade) {
      child = FadeTransition(opacity: _fade, child: child);
    }
    return ClipRect(child: child);
  }
}
