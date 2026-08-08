import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Responsive navigation shell.
/// - Mobile (< 600px): floating glassmorphism dock at bottom.
/// - Tablet/Desktop (>= 600px): NavigationRail on the side.
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
// Mobile: floating glassmorphism dock
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
      body: child,
      bottomNavigationBar: SizedBox(
        height: 100,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
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
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 22,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide (tablet / desktop / web): NavigationRail
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
              color: scheme.surfaceContainerLow,
              border: Border(
                right: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onTap,
              backgroundColor: Colors.transparent,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 12),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 28,
                  color: scheme.primary,
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
