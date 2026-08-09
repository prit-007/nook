import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EmptyHome extends StatelessWidget {
  const EmptyHome({super.key, this.animate = true});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget icon = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 48,
        color: scheme.primary,
      ),
    );

    if (animate) {
      icon = icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: -8,
            end: 8,
            duration: 2500.ms,
            curve: Curves.easeInOut,
          )
          .scaleXY(begin: 0.95, end: 1.05, duration: 2500.ms);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 24),
          Text(
            'Your canvas is clear',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "New Note" below to capture a thought or sketch.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
