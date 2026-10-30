import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_theme.dart';

/// An interactive, miniature phone screen mockup card inspired by the Mihon
/// (Tachiyomi) app theme selector.
///
/// Previews the real [ColorScheme] roles (surface, primary, container,
/// surfaceContainerHigh, etc.) adapting dynamically to Light, Dark, or
/// True-Black AMOLED mode.
class MihonThemeCard extends StatelessWidget {
  const MihonThemeCard({
    super.key,
    required this.seed,
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.themeMode,
    required this.amoledDark,
    required this.onTap,
  });

  final Color seed;
  final String name;
  final String subtitle;
  final bool isSelected;
  final ThemeMode themeMode;
  final bool amoledDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ambientScheme = Theme.of(context).colorScheme;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    var cardScheme = buildSchemeForSeed(
      seed,
      isDark ? Brightness.dark : Brightness.light,
    );
    if (isDark && amoledDark) {
      cardScheme = applyAmoledSurfaces(cardScheme);
    }

    return Semantics(
      label: '$name color theme, $subtitle',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedScale(
          scale: isSelected ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 104,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Miniature Phone Mockup Frame ──────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 104,
                  height: 156,
                  decoration: BoxDecoration(
                    color: cardScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? cardScheme.primary
                          : ambientScheme.outlineVariant
                              .withValues(alpha: 0.35),
                      width: isSelected ? 2.5 : 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: cardScheme.primary.withValues(alpha: 0.32),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15.5),
                    child: Stack(
                      children: [
                        // ── App Mockup Layout ────────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Top Bar (App bar / search pill)
                            Container(
                              height: 22,
                              color: cardScheme.surfaceContainer,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Mock menu dot
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: cardScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  // Mock search / title pill
                                  Container(
                                    width: 32,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: cardScheme.onSurface
                                          .withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  // Mock action dots
                                  Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: cardScheme.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Mock Notes Body
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Column(
                                  children: [
                                    // Note Card 1 (with category tag)
                                    Container(
                                      height: 38,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: cardScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                width: 46,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: cardScheme.onSurface,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: cardScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            width: 30,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: cardScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.5),
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                          Container(
                                            width: 16,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color:
                                                  cardScheme.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 5),

                                    // Note Card 2 (Checklist snippet)
                                    Container(
                                      height: 32,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: cardScheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 3.5,
                                            decoration: BoxDecoration(
                                              color: cardScheme.onSurface
                                                  .withValues(alpha: 0.8),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: cardScheme.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(1),
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Container(
                                                width: 26,
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: cardScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Miniature Bottom Navigation Rail / Bar
                            Container(
                              height: 15,
                              color: cardScheme.surfaceContainer,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Active pill
                                  Container(
                                    width: 10,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: cardScheme.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  // Inactive dots
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: cardScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: cardScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Mini Floating Action Button (FAB)
                        Positioned(
                          right: 6,
                          bottom: 21,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: cardScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      cardScheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: cardScheme.onPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Selection Checkmark Badge
                        if (isSelected)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                color: cardScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedTick02,
                                  color: cardScheme.onPrimary,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                // ── Theme Name ────────────────────────────────────────────────
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? ambientScheme.primary
                        : ambientScheme.onSurface,
                  ),
                ),

                // ── Flavor Subtitle ───────────────────────────────────────────
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: ambientScheme.onSurfaceVariant
                        .withValues(alpha: isSelected ? 0.9 : 0.65),
                  ),
                ),

                const SizedBox(height: 5),

                // ── Tonal Swatch Dots ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TonalDot(color: cardScheme.primary),
                    const SizedBox(width: 4),
                    _TonalDot(color: cardScheme.secondary),
                    const SizedBox(width: 4),
                    _TonalDot(color: cardScheme.tertiary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TonalDot extends StatelessWidget {
  const _TonalDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
    );
  }
}
