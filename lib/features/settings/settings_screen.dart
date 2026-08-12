import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/screenshot_blocker_provider.dart';

/// Settings root screen.
/// Frosted glass section cards with tight macro-typography and tactile
/// haptic feedback. Lucide iconography throughout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final gate = ref.watch(biometricGateProvider);
    final screenshotBlocker = ref.watch(screenshotBlockerProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _Section(
            title: 'Appearance',
            children: [
              _SettingsTile(
                icon: LucideIcons.palette,
                title: 'Theme & Colors',
                value: 'System',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/appearance');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Security & Privacy',
            children: [
              _SettingsTile(
                icon: LucideIcons.fingerprint,
                title: 'Biometric Lock',
                trailing: Switch.adaptive(
                  value: gate.enabled,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    ref.read(biometricGateProvider).setEnabled(value);
                  },
                ),
              ),
              _SettingsTile(
                icon: LucideIcons.timer,
                title: 'Auto-Lock Timer',
                value: _autoLockLabel(gate.autoLockDuration),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/security');
                },
              ),
              _SettingsTile(
                icon: LucideIcons.ban,
                title: 'Screenshot Blocking',
                trailing: Switch.adaptive(
                  value: screenshotBlocker.blocked,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    ref.read(screenshotBlockerProvider).setBlocked(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Storage & Sync',
            children: [
              _SettingsTile(
                icon: LucideIcons.hardDrive,
                title: 'Storage Used',
                value: '48 MB \u00b7 214 notes',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/storage');
                },
              ),
              _SettingsTile(
                icon: LucideIcons.arrowUpFromLine,
                title: 'Export Vault',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsTile(
                icon: LucideIcons.monitorSmartphone,
                title: 'Paired Devices',
                value: '2 active',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/sync-devices');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'About',
            children: [
              _SettingsTile(
                icon: LucideIcons.shieldCheck,
                title: 'Privacy Policy',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsTile(
                icon: LucideIcons.code,
                title: 'Open Source Licenses',
                onTap: () {
                  HapticFeedback.lightImpact();
                  showLicensePage(context: context);
                },
              ),
              _SettingsTile(
                icon: LucideIcons.info,
                title: 'Version',
                value: '0.1.0',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/about');
                },
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

String _autoLockLabel(AutoLockDuration duration) => switch (duration) {
      AutoLockDuration.immediately => 'Immediately',
      AutoLockDuration.oneMinute => '1 minute',
      AutoLockDuration.fiveMinutes => '5 minutes',
      AutoLockDuration.fifteenMinutes => '15 minutes',
      AutoLockDuration.never => 'Never',
    };

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: scheme.primary.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(icon, size: 20, color: scheme.onSurface),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
