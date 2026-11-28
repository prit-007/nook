import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/nook_tokens.dart';

/// Compact circular progress ring with `completed/total` label for checklist
/// cards. Renders nothing when [total] <= 0.
class ChecklistProgressRing extends StatelessWidget {
  const ChecklistProgressRing({
    super.key,
    required this.completed,
    required this.total,
    this.size = 20.0,
  });

  final int completed;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final ratio = (completed / total).clamp(0.0, 1.0);
    final isDone = completed >= total;
    final activeColor = isDone ? scheme.tertiary : scheme.primary;

    return Semantics(
      label: '$completed of $total tasks completed',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: ratio),
            duration: AppMotion.standard,
            curve: AppMotion.emphasizedDecelerate,
            builder: (context, animatedRatio, _) {
              return SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: animatedRatio,
                    trackColor: scheme.outlineVariant.withValues(alpha: 0.35),
                    progressColor: activeColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: NookTokens.kFontFloor,
              fontWeight: FontWeight.w600,
              color: isDone ? activeColor : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 3.0) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.001 ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
