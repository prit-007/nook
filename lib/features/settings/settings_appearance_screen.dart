import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/theme_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/dock_safe_area.dart';
import 'widgets/mihon_theme_card.dart';
import 'widgets/theme_mode_segmented_bar.dart';

/// Settings screen for configuring app theme, color signatures, dark mode,
/// AMOLED true-black, and motion preferences.
///
/// Features a Mihon (Tachiyomi) inspired theme selector with real-time
/// miniature phone screen mockups and tactile haptic interactions.
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          DockSafeArea.bottomOf(context) + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Mihon App Theme Selector (Seed Color Signature) ──────────────
            const _SectionHeader(title: 'Seed Color Signature'),
            const SizedBox(height: 10),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < NookColors.seeds.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    MihonThemeCard(
                      seed: NookColors.seeds[i],
                      name: NookColors.seedNames[i],
                      subtitle: NookColors.seedDescriptions[i],
                      isSelected: pref.seedIndex == i,
                      themeMode: pref.themeMode,
                      amoledDark: pref.amoledDark,
                      onTap: () {
                        pref.setSeedIndex(i);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── 2. Mihon-Style Theme Mode Selector ──────────────────────────────
            const _SectionHeader(title: 'Theme Mode'),
            const SizedBox(height: 8),
            ThemeModeSegmentedBar(
              currentMode: pref.themeMode,
              onModeSelected: (mode) {
                pref.setThemeMode(mode);
              },
            ),
            const SizedBox(height: 28),

            // ── 3. True Black (AMOLED) Option ───────────────────────────────────
            const _SectionHeader(title: 'True Black (AMOLED)'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SwitchListTile.adaptive(
                    title: const Text(
                      'True black (AMOLED)',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Pure black surfaces in dark mode so OLED pixels turn '
                      'off. Seed colors stay intact.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoon01,
                      color: scheme.primary,
                      size: 24,
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
            const SizedBox(height: 28),

            // ── 4. Motion Reduction ─────────────────────────────────────────────
            const _SectionHeader(title: 'Reduce Motion'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SwitchListTile.adaptive(
                    title: const Text(
                      'Reduce motion',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Fades, slides, and entrance animations are disabled. '
                      'Also honors your device\u2019s system setting.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: HugeIcon(
                      icon: HugeIcons.strokeRoundedFlowCircle,
                      color: scheme.primary,
                      size: 24,
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
            const SizedBox(height: 28),
          ],
        ),
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
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: scheme.primary.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
