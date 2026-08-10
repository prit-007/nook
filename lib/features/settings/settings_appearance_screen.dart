// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/theme/design_tokens.dart';

class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pref = ref.watch(themePreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _SectionHeader(scheme: scheme, title: 'Seed color'),
          _SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < NookColors.seeds.length; i++)
                      _SeedSwatch(
                        color: NookColors.seeds[i],
                        name: NookColors.seedNames[i],
                        isSelected: pref.seedIndex == i,
                        onTap: () => pref.setSeedIndex(i),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(scheme: scheme, title: 'Theme mode'),
          _SectionCard(
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  title:
                      Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
                  value: mode,
                  groupValue: pref.themeMode,
                  onChanged: (v) {
                    if (v != null) pref.setThemeMode(v);
                  },
                ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.scheme, required this.title});

  final ColorScheme scheme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: scheme.onSurface, width: 3)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? Icon(Icons.check, size: 18, color: _contrastColor(color))
              : null,
        ),
      ),
    );
  }

  static Color _contrastColor(Color c) {
    return c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
