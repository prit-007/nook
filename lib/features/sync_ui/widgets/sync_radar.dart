import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/nook_tokens.dart';

/// Animated concentric LAN radar/constellation visualization for peer sync.
class SyncRadarWidget extends StatefulWidget {
  const SyncRadarWidget({
    super.key,
    this.peerCount = 0,
    this.active = true,
    this.statusLabel = 'Scanning LAN...',
    this.size = 160,
  });

  final int peerCount;
  final bool active;
  final String statusLabel;
  final double size;

  @override
  State<SyncRadarWidget> createState() => _SyncRadarWidgetState();
}

class _SyncRadarWidgetState extends State<SyncRadarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SyncRadarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _SyncRadarPainter(
                  phase: _controller.value,
                  peerCount: widget.peerCount,
                  ringColor: scheme.primary.withValues(alpha: 0.25),
                  pulseColor: scheme.primary,
                  peerColor: scheme.tertiary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: NookTokens.kSpacingSm),
        Text(
          widget.statusLabel,
          style: TextStyle(
            fontSize: NookTokens.kFontFloor,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SyncRadarPainter extends CustomPainter {
  const _SyncRadarPainter({
    required this.phase,
    required this.peerCount,
    required this.ringColor,
    required this.pulseColor,
    required this.peerColor,
  });

  final double phase;
  final int peerCount;
  final Color ringColor;
  final Color pulseColor;
  final Color peerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 6;

    final ringPaint = Paint()
      ..color = ringColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), ringPaint);
    }

    final pulseRadius = maxRadius * phase;
    final pulsePaint = Paint()
      ..color = pulseColor.withValues(alpha: (1.0 - phase) * 0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    canvas.drawCircle(
      center,
      6,
      Paint()..color = pulseColor,
    );

    for (var i = 0; i < peerCount; i++) {
      final angle = (2 * math.pi * i / math.max(peerCount, 1)) +
          phase * 2 * math.pi * 0.25;
      final r = maxRadius * 0.65;
      final blip = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      canvas.drawCircle(blip, 5, Paint()..color = peerColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SyncRadarPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.peerCount != peerCount ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.pulseColor != pulseColor;
  }
}
