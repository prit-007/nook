import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A polished, multi-layered lock illustration for biometric lock and shield screens.
///
/// Combines concentric frosted circles, ambient glow, and an optional floating
/// credential badge (e.g. fingerprint or key). When animations are allowed,
/// renders a gentle breathing pulse.
class LockIllustration extends StatefulWidget {
  const LockIllustration({
    super.key,
    required this.primaryIcon,
    this.badgeIcon,
    this.size = 120,
    this.animate = true,
  });

  final List<List<dynamic>> primaryIcon;
  final List<List<dynamic>>? badgeIcon;
  final double size;
  final bool animate;

  @override
  State<LockIllustration> createState() => _LockIllustrationState();
}

class _LockIllustrationState extends State<LockIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion =
        !widget.animate || MediaQuery.disableAnimationsOf(context);

    final double outerSize = widget.size;
    final double innerSize = outerSize * 0.75;
    final double iconSize = innerSize * 0.48;
    final double badgeSize = outerSize * 0.32;
    final double badgeIconSize = badgeSize * 0.52;

    Widget illustration = SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Outer ambient halo
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.35),
            ),
          ),

          // Inner elevated circle with subtle shadow
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: HugeIcon(
                icon: widget.primaryIcon,
                size: iconSize,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),

          // Optional floating accent badge at bottom right
          if (widget.badgeIcon != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  border: Border.all(
                    color: scheme.surface,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: HugeIcon(
                    icon: widget.badgeIcon!,
                    size: badgeIconSize,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (reduceMotion) {
      return illustration;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: illustration,
    );
  }
}
