import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/widgets/dock_safe_area.dart';
import 'privacy_explainer_screen.dart';

/// In-app privacy policy. Honest, no-cloud copy: every permission the app may
/// touch is declared up front so the Play Store data-safety form can simply
/// mirror this screen.
class SettingsPrivacyScreen extends StatelessWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          DockSafeArea.bottomOf(context) + 16,
        ),
        children: [
          _ExplainerLink(scheme: scheme),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'Local-first'),
          const SizedBox(height: 8),
          const _Paragraph(
            'Nook is designed so that no data is collected, shared, or '
            'sold — there is no account, no cloud, and no analytics. Your '
            'notes, checklists, doodles, and attachments are stored only on '
            'your device, encrypted with SQLCipher. Keys live in your '
            'device keystore and never leave it.',
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Permissions'),
          const SizedBox(height: 8),
          const _GlassCard(
            child: Column(
              children: [
                _PermissionTile(
                  icon: HugeIcons.strokeRoundedWifi01,
                  title: 'Wi-Fi Sync',
                  subtitle:
                      'While the Sync screen is open, Nook advertises a short '
                      'beacon and accepts device-to-device transfers directly '
                      'over your local Wi-Fi. No internet connection is used; '
                      'nothing is routed through a server. Permissions: '
                      'INTERNET, ACCESS_NETWORK_STATE, '
                      'CHANGE_WIFI_MULTICAST_STATE.',
                ),
                Divider(height: 1),
                _PermissionTile(
                  icon: HugeIcons.strokeRoundedFingerPrint,
                  title: 'Biometric Lock',
                  subtitle:
                      'Face ID / fingerprint unlock is handled entirely by the '
                      'platform. Your biometrics never reach Nook or any '
                      'server — the app only learns whether the check passed.',
                ),
                Divider(height: 1),
                _PermissionTile(
                  icon: HugeIcons.strokeRoundedFile01,
                  title: 'Storage & Backup',
                  subtitle: 'The database is written to the app\u2019s private '
                      'storage. Exporting a .nook zip or a PNG writes a file '
                      'you explicitly choose to save or share; importing reads '
                      'a file you explicitly pick.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Your control'),
          const SizedBox(height: 8),
          const _Paragraph(
            'Everything is opt-in and reversible. Sync only runs when you '
            'start it. Crash logging is off by default and stores errors only '
            'on this device. Deleting a note empties it from the local '
            'database, and uninstalling the app removes the encrypted store '
            'with the keystore-held key.',
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _ExplainerLink extends StatelessWidget {
  const _ExplainerLink({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PrivacyExplainerScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedShield01,
                size: 22,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How your data stays yours',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Where data lives, what sync sends, what we never '
                      'collect, and how to verify',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(
                              alpha: 0.85,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final dynamic icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: HugeIcon(icon: icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
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

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: child,
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
      padding: const EdgeInsets.only(left: 16),
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
