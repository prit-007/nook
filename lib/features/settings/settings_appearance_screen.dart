import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/theme/design_tokens.dart';

class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pref = ref.watch(themePreferenceProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Appearance',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          const _SectionHeader(title: 'Seed Color Signature'),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: NookColors.seeds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, i) => _SeedSwatch(
                color: NookColors.seeds[i],
                name: NookColors.seedNames[i],
                isSelected: pref.seedIndex == i,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  pref.setSeedIndex(i);
                },
              ),
            ),
          ),
          const SizedBox(height: 36),
          const _SectionHeader(title: 'Theme Mode'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    for (final mode in ThemeMode.values)
                      _ThemeModeTile(
                        mode: mode,
                        isSelected: pref.themeMode == mode,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          pref.setThemeMode(mode);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          const _SectionHeader(title: 'True Black (AMOLED)'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile.adaptive(
                  title: const Text(
                    'True black (AMOLED)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Pure black surfaces in dark mode so OLED pixels turn '
                    'off. Seed colors stay intact.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  secondary: Icon(
                    LucideIcons.moon,
                    color: scheme.primary,
                    size: 28,
                  ),
                  value: pref.amoledDark,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    pref.setAmoledDark(value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          const _SectionHeader(title: 'Reduce Motion'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile.adaptive(
                  title: const Text(
                    'Reduce motion',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Fades, slides, and entrance animations are disabled. '
                    'Also honors your device\u2019s system setting.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  secondary: Icon(
                    LucideIcons.rabbit,
                    color: scheme.primary,
                    size: 28,
                  ),
                  value: pref.reduceMotion,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    pref.setReduceMotion(value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: scheme.primary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });
  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = mode.name[0].toUpperCase() + mode.name.substring(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSelected)
                Icon(LucideIcons.checkCircle, color: scheme.primary, size: 22)
              else
                Icon(
                  LucideIcons.circle,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeedSwatch extends StatelessWidget {
  const _SeedSwatch({
    required this.color,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });
  final Color color;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$name color theme',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: isSelected ? 52 : 44,
              height: isSelected ? 52 : 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? scheme.onSurface
                      : scheme.outlineVariant.withValues(alpha: 0.2),
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
