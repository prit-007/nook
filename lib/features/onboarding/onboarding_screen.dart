import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hugeicons/hugeicons.dart';
import '../../core/providers/navigation_preference.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/design_tokens.dart';

/// Multi-page onboarding flow.
/// Page 1: Welcome (prompt #1)
/// Page 2: Pick Your Vibe (prompt #2)
/// Page 3: Ready
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  int _selectedSeedIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    ref.read(themePreferenceProvider).setSeedIndex(_selectedSeedIndex);
    await NavigationPreference.completeOnboarding();
    talker.info('Onboarding completed (seed $_selectedSeedIndex)');
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (hidden on final page)
            Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _currentPage == 3 ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _currentPage == 3,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.87)),
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(scheme: scheme),
                  _NoteTypesPage(scheme: scheme),
                  _VibePage(
                    scheme: scheme,
                    selectedIndex: _selectedSeedIndex,
                    onSeedChanged: (i) =>
                        setState(() => _selectedSeedIndex = i),
                  ),
                  _ReadyPage(scheme: scheme),
                ],
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _nextPage,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _currentPage == 3 ? 'Get Started' : 'Continue',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1: Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Animated illustration mockup
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.15),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedNotebook01,
                  size: 80,
                  color: scheme.onPrimaryContainer,
                ),
                Positioned(
                  right: 30,
                  bottom: 30,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedLock,
                      size: 20,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -8, end: 8, duration: 2500.ms, curve: Curves.easeInOut)
              .scaleXY(begin: 0.96, end: 1.04, duration: 2500.ms),
          const Spacer(flex: 2),
          Text(
            'Your notes. Your device. Yours.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'No account. No cloud. No one else reads your notes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurface.withValues(alpha: 0.87),
              height: 1.4,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: Note Types
// ---------------------------------------------------------------------------

class _NoteTypesPage extends StatelessWidget {
  const _NoteTypesPage({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Three ways to capture',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the format that fits your thought.',
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurface.withValues(alpha: 0.87),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Column(
              children: [
                _NoteTypeCard(
                  scheme: scheme,
                  icon: HugeIcons.strokeRoundedNotebook01,
                  title: 'Text Notes',
                  description:
                      'Rich text with headings, lists, and formatting. Your everyday journal.',
                  color: scheme.primary,
                  delayMs: 100,
                  preview: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#journal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• Morning reflections',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _NoteTypeCard(
                  scheme: scheme,
                  icon: HugeIcons.strokeRoundedCheckList,
                  title: 'Checklists',
                  description:
                      'Interactive task lists with drag-to-reorder and swipe-to-complete.',
                  color: scheme.tertiary,
                  delayMs: 200,
                  preview: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                          size: 14,
                          color: scheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pack camera',
                          style: TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outline, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sketch sunset',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _NoteTypeCard(
                  scheme: scheme,
                  icon: HugeIcons.strokeRoundedDrawingMode,
                  title: 'Doodles',
                  description:
                      'Freehand drawing with pressure sensitivity and shape recognition.',
                  color: scheme.secondary,
                  delayMs: 300,
                  preview: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedPaintBoard,
                          size: 14,
                          color: scheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Vector ink canvas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteTypeCard extends StatelessWidget {
  const _NoteTypeCard({
    required this.scheme,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.preview,
    this.delayMs = 0,
  });

  final ColorScheme scheme;
  final List<List<dynamic>> icon;
  final String title;
  final String description;
  final Color color;
  final Widget? preview;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: HugeIcon(icon: icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (preview != null) preview!,
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs), duration: 350.ms)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ---------------------------------------------------------------------------
// Page 3: Pick Your Vibe
// ---------------------------------------------------------------------------

class _VibePage extends StatelessWidget {
  const _VibePage({
    required this.scheme,
    required this.selectedIndex,
    required this.onSeedChanged,
  });

  final ColorScheme scheme;
  final int selectedIndex;
  final ValueChanged<int> onSeedChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Pick your vibe',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Each note can have its own color theme.',
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurface.withValues(alpha: 0.87),
            ),
          ),
          const SizedBox(height: 32),

          // Color swatches
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: NookColors.seeds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final color = NookColors.seeds[index];
                final isSelected = index == selectedIndex;
                return GestureDetector(
                  onTap: () => onSeedChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: isSelected
                          ? Border.all(color: scheme.onSurface, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black87
                                : Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NookColors.seeds[selectedIndex].withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: NookColors.seeds[selectedIndex].withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: NookColors.seeds[selectedIndex],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Weekend trip packing list',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Passport, headphones, camera, snacks...',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3: Ready
// ---------------------------------------------------------------------------

class _ReadyPage extends StatelessWidget {
  const _ReadyPage({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              size: 80,
              color: scheme.onPrimaryContainer,
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1.0, 1.0),
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),
          const Spacer(flex: 2),
          Text(
            "You're all set!",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start writing. Your notes stay on this device unless you choose to sync.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurface.withValues(alpha: 0.87),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Animated security & sync badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedShieldSecurity,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Encrypted Local Storage • Peer Sync Ready',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 250.ms, duration: 400.ms)
              .slideY(begin: 0.15, end: 0, duration: 400.ms),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
