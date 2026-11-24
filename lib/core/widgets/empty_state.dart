import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_motion.dart';
import '../theme/nook_tokens.dart';

/// A reusable editorial empty-state widget.
///
/// Follows Nook's editorial identity with Playfair Display / Inter typography,
/// soft tinted icon background, and a single entrance animation that respects
/// [MediaQuery.disableAnimationsOf].
///
/// Supports an optional primary action button with accessible touch target
/// (≥48×48dp) and typography (≥12sp), either via [EmptyState.action] or
/// by passing [actionLabel] and [onActionPressed]. Custom [action] widgets
/// are also supported.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.animate = true,
  });

  /// Alternative constructor explicitly for editorial empty states with an
  /// actionable primary button.
  const EmptyState.action({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionPressed,
    this.actionIcon,
    this.animate = true,
  }) : action = null;

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final List<List<dynamic>>? actionIcon;
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
          )
          .moveY(
            begin: 8,
            end: 0,
            duration: AppMotion.medium2,
            curve: AppMotion.emphasizedDecelerate,
          );
    }

    final Widget? effectiveAction;
    if (action != null) {
      effectiveAction = action;
    } else if (actionLabel != null) {
      const buttonTextStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: 14, // >= 12sp (NookTokens.kFontFloor)
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

      final buttonStyle = FilledButton.styleFrom(
        minimumSize: const Size(
          NookTokens.kMinTapTarget,
          NookTokens.kMinTapTarget,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusLg),
        ),
        textStyle: buttonTextStyle,
      );

      final actionText = Text(
        actionLabel!,
        style: buttonTextStyle,
      );

      final buttonWidget = actionIcon != null
          ? FilledButton.icon(
              onPressed: onActionPressed,
              style: buttonStyle,
              icon: HugeIcon(
                icon: actionIcon!,
                size: 18,
                color: scheme.onPrimary,
              ),
              label: actionText,
            )
          : FilledButton(
              onPressed: onActionPressed,
              style: buttonStyle,
              child: actionText,
            );

      effectiveAction = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: NookTokens.kMinTapTarget,
          minHeight: NookTokens.kMinTapTarget,
        ),
        child: buttonWidget,
      );
    } else {
      effectiveAction = null;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          if (effectiveAction != null) ...[
            const SizedBox(height: 24),
            effectiveAction,
          ],
        ],
      ),
    );
  }
}
