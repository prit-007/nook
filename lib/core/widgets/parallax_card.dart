import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Applies a subtle vertical parallax to [child] based on its position within
/// the nearest [Scrollable] viewport.
///
/// As the user scrolls, cards closer to the viewport edge drift further from
/// their grid slot than cards at the center, giving the grid a physical sense
/// of weight and momentum. The shift is bounded to `intensity * height`, so a
/// card never leaves its slot more than a fraction of its own size.
class ParallaxCard extends StatefulWidget {
  const ParallaxCard({
    super.key,
    required this.child,
    this.intensity = 0.08,
    this.enabled = true,
  });

  /// Maximum vertical drift as a fraction of the card's height.
  final double intensity;

  /// Set to `false` to render [child] statically.
  final bool enabled;

  final Widget child;

  @override
  State<ParallaxCard> createState() => _ParallaxCardState();
}

class _ParallaxCardState extends State<ParallaxCard> {
  ScrollPosition? _position;
  double _offsetDy = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_updateParallax);
      _position = position;
      _position?.addListener(_updateParallax);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateParallax());
  }

  @override
  void dispose() {
    _position?.removeListener(_updateParallax);
    super.dispose();
  }

  void _updateParallax() {
    if (!mounted) return;
    if (!widget.enabled) {
      if (_offsetDy != 0) setState(() => _offsetDy = 0);
      return;
    }
    final position = _position;
    final renderObject = context.findRenderObject();
    if (position == null ||
        !position.hasContentDimensions ||
        renderObject is! RenderBox ||
        !renderObject.hasSize) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return;

    // Scroll offset at which this card's leading edge sits at the viewport top.
    final leading = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    final cardMid = leading + renderObject.size.height / 2 - position.pixels;
    final viewportMid = position.viewportDimension / 2;
    final factor =
        ((cardMid - viewportMid) / position.viewportDimension).clamp(-0.5, 0.5);

    final maxTranslate = widget.intensity * renderObject.size.height;
    final dy = -factor * 2 * maxTranslate;
    if ((dy - _offsetDy).abs() > 0.01) {
      setState(() => _offsetDy = dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Transform.translate(
      offset: Offset(0, _offsetDy),
      child: widget.child,
    );
  }
}
