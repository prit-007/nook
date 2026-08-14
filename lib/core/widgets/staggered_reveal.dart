import 'package:flutter/material.dart';

/// A staggered reveal widget for cascading entrance animations.
///
/// Wraps a child in a fade + translate-up animation that starts after [delay].
/// Use multiple instances with incrementing delays to create a waterfall effect
/// (e.g. title → subtitle → card body).
///
/// Respects `MediaQuery.disableAnimationsOf(context)` for reduce-motion.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutExpo,
    this.slideDistance = 30,
  });

  /// The widget to animate in.
  final Widget child;

  /// Delay before this element starts animating, for stagger sequencing.
  final Duration delay;

  /// Total animation duration once this element starts.
  final Duration duration;

  /// Easing curve for the reveal.
  final Curve curve;

  /// How far (in logical pixels) the child slides up from.
  final double slideDistance;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, _) {
        final totalSeconds = duration.inMicroseconds / 1000000.0;
        final delaySeconds = delay.inMicroseconds / 1000000.0;

        // Normalize progress into [0, 1] after the delay window.
        final raw = (value - (delaySeconds / totalSeconds));
        final normalized =
            (raw / (1 - (delaySeconds / totalSeconds))).clamp(0.0, 1.0);

        return Opacity(
          opacity: normalized,
          child: Transform.translate(
            offset: Offset(0, slideDistance * (1 - normalized)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
