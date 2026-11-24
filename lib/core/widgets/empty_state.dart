import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_motion.dart';

/// A reusable empty-state widget following the pattern from EmptyHome.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.animate = true,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget iconWidget = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: HugeIcon(icon: icon, size: 48, color: scheme.primary),
    );

    final animationsAllowed =
        animate && !MediaQuery.disableAnimationsOf(context);

    if (animationsAllowed) {
      iconWidget = iconWidget
          .animate()
          .fadeIn(
            duration: AppMotion.medium2,
            curve: AppMotion.emphasizedDecelerate,
          )
          .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1.0, 1.0),
            duration: AppMotion.medium2,
            curve: AppMotion.emphasizedDecelerate,
          );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}
