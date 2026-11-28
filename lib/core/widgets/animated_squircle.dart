import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/nook_tokens.dart';

/// Material 3 Expressive shape presets supported by [AnimatedSquircle].
enum SquircleShape {
  squircle,
  circle,
  clover,
  pill,
}

/// Superellipse (squircle) [OutlinedBorder] with smooth [lerpFrom] / [lerpTo]
/// support for Material 3 Expressive shape morphing.
class SquircleBorder extends OutlinedBorder {
  const SquircleBorder({
    this.cornerRadius = NookTokens.kRadiusMd,
    this.smoothness = 0.6,
    super.side,
  });

  final double cornerRadius;
  final double smoothness;

  @override
  ShapeBorder scale(double t) {
    return SquircleBorder(
      cornerRadius: cornerRadius * t,
      smoothness: smoothness,
      side: side.scale(t),
    );
  }

  @override
  OutlinedBorder copyWith({BorderSide? side}) {
    return SquircleBorder(
      cornerRadius: cornerRadius,
      smoothness: smoothness,
      side: side ?? this.side,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SquircleBorder) {
      return SquircleBorder(
        cornerRadius:
            lerpDouble(a.cornerRadius, cornerRadius, t) ?? cornerRadius,
        smoothness: lerpDouble(a.smoothness, smoothness, t) ?? smoothness,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    if (a is CircleBorder) {
      return SquircleBorder(
        cornerRadius: lerpDouble(999.0, cornerRadius, t) ?? cornerRadius,
        smoothness: lerpDouble(1.0, smoothness, t) ?? smoothness,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SquircleBorder) {
      return SquircleBorder(
        cornerRadius:
            lerpDouble(cornerRadius, b.cornerRadius, t) ?? cornerRadius,
        smoothness: lerpDouble(smoothness, b.smoothness, t) ?? smoothness,
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    if (b is CircleBorder) {
      return SquircleBorder(
        cornerRadius: lerpDouble(cornerRadius, 999.0, t) ?? cornerRadius,
        smoothness: lerpDouble(smoothness, 1.0, t) ?? smoothness,
        side: BorderSide.lerp(side, b.side, t),
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final insetRect = rect.deflate(side.strokeInset);
    return _buildSquirclePath(
      insetRect,
      math.max(0.0, cornerRadius - side.strokeInset),
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _buildSquirclePath(rect, cornerRadius);
  }

  Path _buildSquirclePath(Rect rect, double radius) {
    final maxR = math.min(rect.width, rect.height) / 2.0;
    final r = radius.clamp(0.0, maxR);
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(r * (1.0 + smoothness * 0.35)),
    ).getOuterPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final path = getOuterPath(rect.deflate(side.strokeOffset));
    canvas.drawPath(path, side.toPaint());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquircleBorder &&
        other.cornerRadius == cornerRadius &&
        other.smoothness == smoothness &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(cornerRadius, smoothness, side);
}

/// Four-lobed Material 3 Expressive clover [OutlinedBorder].
class CloverBorder extends OutlinedBorder {
  const CloverBorder({super.side, this.lobeDepth = 0.14});

  final double lobeDepth;

  @override
  ShapeBorder scale(double t) =>
      CloverBorder(side: side.scale(t), lobeDepth: lobeDepth);

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      CloverBorder(side: side ?? this.side, lobeDepth: lobeDepth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildCloverPath(rect.deflate(side.strokeInset));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildCloverPath(rect);

  Path _buildCloverPath(Rect rect) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final rx = rect.width / 2.0;
    final ry = rect.height / 2.0;
    final path = Path();
    const steps = 64;
    for (var i = 0; i <= steps; i++) {
      final theta = (2 * math.pi * i) / steps;
      final mod = 1.0 - lobeDepth * (0.5 - 0.5 * math.cos(4 * theta));
      final x = cx + rx * mod * math.cos(theta);
      final y = cy + ry * mod * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.strokeOffset)),
      side.toPaint(),
    );
  }
}

/// Implicitly animated Material 3 Expressive squircle container that morphs
/// smoothly between [SquircleShape] variants and responds to press gestures.
class AnimatedSquircle extends StatefulWidget {
  const AnimatedSquircle({
    super.key,
    required this.child,
    this.shape = SquircleShape.squircle,
    this.size,
    this.color,
    this.onTap,
  });

  final Widget child;
  final SquircleShape shape;
  final double? size;
  final Color? color;
  final VoidCallback? onTap;

  @override
  State<AnimatedSquircle> createState() => _AnimatedSquircleState();
}

class _AnimatedSquircleState extends State<AnimatedSquircle> {
  bool _pressed = false;

  ShapeBorder _shapeBorderFor(SquircleShape shape) {
    return switch (shape) {
      SquircleShape.squircle => const SquircleBorder(
          cornerRadius: NookTokens.kRadiusMd,
        ),
      SquircleShape.circle => const CircleBorder(),
      SquircleShape.clover => const CloverBorder(),
      SquircleShape.pill => const StadiumBorder(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.color ?? scheme.primaryContainer;
    final targetShape = _shapeBorderFor(widget.shape);

    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: AppMotion.shapeSnap,
        curve: AppMotion.shapeSnapCurve,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: AppMotion.standard,
            curve: AppMotion.emphasizedDecelerate,
            width: widget.size,
            height: widget.size,
            decoration: ShapeDecoration(
              color: bg,
              shape: targetShape,
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
