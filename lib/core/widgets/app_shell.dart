import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'dock_safe_area.dart';

/// Responsive navigation shell with magical micro-animations.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/notebooks')) return 1;
    if (location.startsWith('/tags')) return 2;
    if (location.startsWith('/trash')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/notebooks');
      case 2:
        context.go('/tags');
      case 3:
        context.go('/trash');
      case 4:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;
    final selectedIndex = _currentIndex(context);

    if (isWide) {
      return _WideShell(
        selectedIndex: selectedIndex,
        onTap: (i) => _onTap(context, i),
        child: child,
      );
    }

    return _MobileShell(
      selectedIndex: selectedIndex,
      onTap: (i) => _onTap(context, i),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: Floating Glassmorphism Dock with Spring Physics
// ---------------------------------------------------------------------------

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.onTap,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final dockHeight = 72.0 + 24.0 + bottomInset;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: DockSafeArea(
        bottom: dockHeight,
        child: child,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: RepaintBoundary(
                child: Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _DockItem(
                        icon: HugeIcons.strokeRoundedHome01,
                        activeIcon: HugeIcons.strokeRoundedHome02,
                        label: 'Home',
                        isSelected: selectedIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      _DockItem(
                        icon: HugeIcons.strokeRoundedBook01,
                        activeIcon: HugeIcons.strokeRoundedBook02,
                        label: 'Notebooks',
                        isSelected: selectedIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      _DockItem(
                        icon: HugeIcons.strokeRoundedTag01,
                        activeIcon: HugeIcons.strokeRoundedTag02,
                        label: 'Tags',
                        isSelected: selectedIndex == 2,
                        onTap: () => onTap(2),
                      ),
                      _DockItem(
                        icon: HugeIcons.strokeRoundedDelete01,
                        activeIcon: HugeIcons.strokeRoundedDelete02,
                        label: 'Trash',
                        isSelected: selectedIndex == 3,
                        onTap: () => onTap(3),
                      ),
                      _DockItem(
                        icon: HugeIcons.strokeRoundedSettings01,
                        activeIcon: HugeIcons.strokeRoundedSettings02,
                        label: 'Settings',
                        isSelected: selectedIndex == 4,
                        onTap: () => onTap(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final List<List<dynamic>> activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem>
    with SingleTickerProviderStateMixin {
  static const _selectionDuration = Duration(milliseconds: 320);
  static const _iconSwapDuration = Duration(milliseconds: 260);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) => _controller.forward();

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = widget.isSelected ? widget.activeIcon : widget.icon;

    return Expanded(
      child: Semantics(
        label: widget.label,
        button: true,
        selected: widget.isSelected,
        onTap: widget.onTap,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: _selectionDuration,
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? scheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AnimatedSwitcher(
                        duration: _iconSwapDuration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.7, end: 1.0)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: HugeIcon(
                          key: ValueKey(icon),
                          icon: icon,
                          size: 24,
                          color: widget.isSelected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedDefaultTextStyle(
                          duration: _selectionDuration,
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: widget.isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: widget.isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                            letterSpacing: 0.3,
                          ),
                          child: Text(widget.label, maxLines: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide (tablet / desktop / web): Fluid NavigationRail
// ---------------------------------------------------------------------------

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.selectedIndex,
    required this.onTap,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  static const _destinations = [
    NavigationRailDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedHome01, size: 26),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedHome02, size: 26),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedBook01, size: 26),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedBook02, size: 26),
      label: Text('Notebooks'),
    ),
    NavigationRailDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedTag01, size: 26),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedTag02, size: 26),
      label: Text('Tags'),
    ),
    NavigationRailDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 26),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 26),
      label: Text('Trash'),
    ),
    NavigationRailDestination(
      icon: HugeIcon(icon: HugeIcons.strokeRoundedSettings01, size: 26),
      selectedIcon: HugeIcon(icon: HugeIcons.strokeRoundedSettings02, size: 26),
      label: Text('Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  right: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          minWidth: 110,
                          selectedIndex: selectedIndex,
                          onDestinationSelected: onTap,
                          backgroundColor: Colors.transparent,
                          indicatorColor:
                              scheme.primary.withValues(alpha: 0.12),
                          indicatorShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          selectedIconTheme:
                              IconThemeData(color: scheme.primary),
                          unselectedIconTheme:
                              IconThemeData(color: scheme.onSurfaceVariant),
                          selectedLabelTextStyle: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontSize: 13,
                          ),
                          unselectedLabelTextStyle: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          labelType: NavigationRailLabelType.all,
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer
                                    .withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedFlash,
                                size: 28,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          destinations: _destinations,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
