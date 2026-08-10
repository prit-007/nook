import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/screenshot_blocker_provider.dart';

/// Settings root screen per prompt #11.
/// Grouped list with rounded section cards, leading icons, switches.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(biometricGateProvider);
    final screenshotBlocker = ref.watch(screenshotBlockerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Appearance ──
          _Section(
            title: 'Appearance',
            children: [
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                value: 'System',
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Security ──
          _Section(
            title: 'Security',
            children: [
              _SettingsTile(
                icon: Icons.fingerprint,
                title: 'Biometric lock',
                trailing: Switch(
                  value: gate.enabled,
                  onChanged: (value) =>
                      ref.read(biometricGateProvider).setEnabled(value),
                ),
              ),
              _SettingsTile(
                icon: Icons.timer_outlined,
                title: 'Auto-lock timer',
                value: _autoLockLabel(gate.autoLockDuration),
                onTap: () => context.push('/settings/security'),
              ),
              _SettingsTile(
                icon: Icons.screenshot_outlined,
                title: 'Screenshot blocking',
                trailing: Switch(
                  value: screenshotBlocker.blocked,
                  onChanged: (value) =>
                      ref.read(screenshotBlockerProvider).setBlocked(value),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Storage & Sync ──
          _Section(
            title: 'Storage & Sync',
            children: [
              _SettingsTile(
                icon: Icons.storage_outlined,
                title: 'Storage used',
                value: '48 MB \u00b7 214 notes',
                onTap: () => context.push('/settings/storage'),
              ),
              _SettingsTile(
                icon: Icons.file_download_outlined,
                title: 'Export all notes',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.devices_outlined,
                title: 'Paired devices',
                value: '2 devices',
                onTap: () => context.push('/settings/sync-devices'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── About ──
          _Section(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.policy_outlined,
                title: 'Privacy policy',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.code_outlined,
                title: 'Open source licenses',
                onTap: () => showLicensePage(context: context),
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                value: '0.1.0',
                onTap: () => context.push('/settings/about'),
              ),
            ],
          ),

          const SizedBox(height: 32),
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: children),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value!,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}
