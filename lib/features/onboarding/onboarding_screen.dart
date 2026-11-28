import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hugeicons/hugeicons.dart';
import '../../core/providers/navigation_preference.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/vault_password_provider.dart';
import '../../core/security/dek_manager.dart';
import '../../core/security/recovery_key_provider.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/design_tokens.dart';
import '../importers/import_dialog.dart';
import '../security/recovery_key_dialog.dart';
import '../security/vault_password_dialog.dart';

/// Multi-page onboarding flow.
/// Page 1: Welcome (prompt #1)
/// Page 2: Three Ways to Capture (screen mockups)
/// Page 3: Pick Your Vibe (theme preview)
/// Page 4: Master Vault Key (24-word recovery phrase)
/// Page 5: Ready (offline & sync ready)
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  int _selectedSeedIndex = 0;
  late final List<String> _recoveryWords;

  @override
  void initState() {
    super.initState();
    _recoveryWords = generateRecoveryKey();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: AppMotion.medium2,
        curve: AppMotion.emphasizedDecelerate,
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

  /// Sets a vault password and wraps the SQLCipher database encryption key (DEK)
  /// using [DekManager.wrapDekWithPassword] and the user's verified [recoveryWords].
  Future<bool> wrapDekWithPassword(
    String password, {
    List<String>? recoveryWords,
  }) async {
    final words = recoveryWords ?? _recoveryWords;
    await ref.read(vaultPasswordProvider).setPassword(
          password,
          recoveryWords: words,
        );
    return true;
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
                opacity: _currentPage == 4 ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _currentPage == 4,
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
                  _ProtectVaultPage(
                    scheme: scheme,
                    isProtected: ref.watch(vaultPasswordProvider).enabled,
                    onSetupVault: () async {
                      final ok = await showSetVaultPasswordDialog(
                        context,
                        onSetPassword: (password, shownWords) =>
                            wrapDekWithPassword(
                          password,
                          recoveryWords: shownWords,
                        ),
                      );
                      if (ok && mounted) {
                        _nextPage();
                      }
                    },
                    onSkipVault: _nextPage,
                  ),
                  _ReadyPage(
                    scheme: scheme,
                    onSetVaultPassword: (password, shownWords) =>
                        wrapDekWithPassword(
                      password,
                      recoveryWords: shownWords,
                    ),
                  ),
                ],
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
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
                    _currentPage == 4 ? 'Get Started' : 'Continue',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Illustration mockup
                  Container(
                    width: 160,
                    height: 160,
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
                          size: 70,
                          color: scheme.onPrimaryContainer,
                        ),
                        Positioned(
                          right: 24,
                          bottom: 24,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary,
                            ),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedLock,
                              size: 18,
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
                      color: scheme.onSurface.withValues(alpha: 0.87),
                      height: 1.4,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: Note Types (Screen Mockups)
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
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NoteTypeCard(
                  scheme: scheme,
                  icon: HugeIcons.strokeRoundedNotebook01,
                  title: 'Text Notes',
                  description:
                      'Rich text with headings, lists, and formatting. Your everyday journal.',
                  color: scheme.primary,
                  preview: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• Morning reflections',
                          style: TextStyle(
                            fontSize: 12,
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
                  preview: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: scheme.outline, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sketch sunset',
                          style: TextStyle(
                            fontSize: 12,
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
                  preview: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            fontSize: 12,
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
  });

  final ColorScheme scheme;
  final List<List<dynamic>> icon;
  final String title;
  final String description;
  final Color color;
  final Widget? preview;

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
// Page 4: Master Vault Key
// ---------------------------------------------------------------------------

class _ProtectVaultPage extends StatelessWidget {
  const _ProtectVaultPage({
    required this.scheme,
    required this.isProtected,
    required this.onSetupVault,
    required this.onSkipVault,
  });

  final ColorScheme scheme;
  final bool isProtected;
  final VoidCallback onSetupVault;
  final VoidCallback onSkipVault;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: isProtected
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedShield01,
                size: 40,
                color: isProtected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Protect your vault',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            isProtected
                ? 'Your vault password and 24-word recovery key are set up and wrapping your database key.'
                : 'Optionally set a vault password to wrap your SQLCipher database key and back up a verified 24-word recovery key.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          if (!isProtected) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onSetupVault,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedKey01,
                  size: 18,
                ),
                label: const Text('Set vault password & recovery key'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onSkipVault,
              child: const Text('Skip for now'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 5: Ready
// ---------------------------------------------------------------------------

class _ReadyPage extends ConsumerWidget {
  const _ReadyPage({required this.scheme, this.onSetVaultPassword});

  final ColorScheme scheme;
  final SetVaultPasswordCallback? onSetVaultPassword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Security & sync badge
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
                  icon: HugeIcons.strokeRoundedShield01,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Encrypted on this device • Peer Sync Ready',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedKey01,
                  size: 18,
                ),
                label: const Text(
                  'Backup Recovery Key',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  final vault = ref.read(vaultPasswordProvider);
                  if (!vault.enabled) {
                    await showSetVaultPasswordDialog(
                      context,
                      onSetPassword: onSetVaultPassword,
                    );
                  } else {
                    await showRecoveryKeyDialog(context);
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedDownload01,
                  size: 18,
                ),
                label: const Text(
                  'Import Notes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(150, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => showImportNotesSheet(context, ref),
              ),
            ],
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
