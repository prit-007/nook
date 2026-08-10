import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    ref.read(themePreferenceProvider).setSeedIndex(_selectedSeedIndex);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style:
                      TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
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
                children: List.generate(3, (i) {
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
                    _currentPage == 2 ? 'Get Started' : 'Continue',
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
          // Illustration placeholder
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.note_alt_outlined,
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
                    child: Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              color: scheme.onSurface.withValues(alpha: 0.6),
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
// Page 2: Pick Your Vibe
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
              color: scheme.onSurface.withValues(alpha: 0.6),
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
                        ? const Icon(Icons.check, color: Colors.white)
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
            ),
            child: Icon(
              Icons.check_rounded,
              size: 80,
              color: scheme.onPrimaryContainer,
            ),
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
              color: scheme.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
