import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      extendBody: true, // Allows child content to scroll behind the dock
      body: child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    // Ambient Glow
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _DockItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: selectedIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    _DockItem(
                      icon: Icons.book_outlined,
                      activeIcon: Icons.book_rounded,
                      label: 'Notebooks',
                      isSelected: selectedIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    _DockItem(
                      icon: Icons.label_outlined,
                      activeIcon: Icons.label_rounded,
                      label: 'Tags',
                      isSelected: selectedIndex == 2,
                      onTap: () => onTap(2),
                    ),
                    _DockItem(
                      icon: Icons.delete_outline,
                      activeIcon: Icons.delete_rounded,
                      label: 'Trash',
                      isSelected: selectedIndex == 3,
                      onTap: () => onTap(3),
                    ),
                    _DockItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
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

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: SizedBox(
              width: 54, // Fixed width prevents layout jitter
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? scheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.isSelected ? widget.activeIcon : widget.icon,
                      size: 24,
                      color: widget.isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: widget.isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                    child: Text(widget.label, maxLines: 1),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide (tablet / desktop / web): Elevated NavigationRail
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
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.book_outlined),
      selectedIcon: Icon(Icons.book_rounded),
      label: Text('Notebooks'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.label_outlined),
      selectedIcon: Icon(Icons.label_rounded),
      label: Text('Tags'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.delete_outline),
      selectedIcon: Icon(Icons.delete_rounded),
      label: Text('Trash'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: Text('Settings'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                right: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onTap,
              backgroundColor: Colors.transparent,
              indicatorColor: scheme.primary.withValues(alpha: 0.15),
              selectedIconTheme: IconThemeData(color: scheme.primary),
              unselectedIconTheme:
                  IconThemeData(color: scheme.onSurfaceVariant),
              selectedLabelTextStyle: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 28,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              destinations: _destinations,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
