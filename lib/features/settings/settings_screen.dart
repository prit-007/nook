import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/app_info.dart';
import '../../core/providers/biometric_provider.dart';
import '../../core/providers/screenshot_blocker_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../sync/sync_orchestrator.dart';
import 'providers/vault_stats_provider.dart';

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
    final vaultStats = ref.watch(vaultStatsProvider);
    final syncState = ref.watch(syncOrchestratorProvider);
    final deviceCount = syncState.devices.length;
    final logCount = ref.watch(talkerLogCountProvider).maybeWhen(
          data: (count) => '$count entries',
          orElse: () => '\u2014',
        );

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
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          DockSafeArea.bottomOf(context) + 72,
        ),
        children: [
          _Section(
            title: 'Appearance',
            children: [
              _SettingsTile(
                icon: HugeIcons.strokeRoundedSwatch,
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
                icon: HugeIcons.strokeRoundedFingerPrint,
                title: 'Biometric Lock',
                trailing: Switch.adaptive(
                  value: gate.enabled,
                  activeThumbColor: scheme.primary,
                  onChanged: (value) => unawaited(() async {
                    unawaited(HapticFeedback.lightImpact());
                    final gate = ref.read(biometricGateProvider);
                    if (!value) {
                      gate.setEnabled(false);
                      return;
                    }
                    final enabled = await gate.enableWithVerification();
                    if (!enabled && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Authentication is unavailable on this device.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }()),
                ),
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedTimer01,
                title: 'Auto-Lock Timer',
                value: _autoLockLabel(gate.autoLockDuration),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/security');
                },
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedBlockGame,
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
                icon: HugeIcons.strokeRoundedHardDrive,
                title: 'Storage Used',
                value: vaultStats.maybeWhen(
                  data: (stats) => '${formatBytes(stats.dbBytes)} '
                      '\u00b7 ${stats.noteCount} notes',
                  orElse: () => '\u2014',
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/storage');
                },
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedUpload01,
                title: 'Export Vault',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/storage');
                },
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedWifi01,
                title: 'Peer Sync',
                value: 'Send & receive',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/sync');
                },
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedSmartPhone01,
                title: 'Paired Devices',
                value: deviceCount > 0 ? '$deviceCount active' : 'None',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/sync-devices');
                },
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedTransactionHistory,
                title: 'Sync History',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/sync/history');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Developer',
            children: [
              _SettingsTile(
                icon: HugeIcons.strokeRoundedComputerTerminal01,
                title: 'App Logs',
                value: logCount,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/logs');
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'About',
            children: [
              _SettingsTile(
                icon: HugeIcons.strokeRoundedSecurityCheck,
                title: 'Privacy Policy',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings/privacy');
                },
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedCode,
                title: 'Open Source Licenses',
                onTap: () {
                  HapticFeedback.lightImpact();
                  showLicensePage(context: context);
                },
              ),
              _SettingsTile(
                icon: HugeIcons.strokeRoundedInformationCircle,
                title: 'Version',
                value: AppInfo.version,
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
  final dynamic icon;
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
                ),
                child: HugeIcon(icon: icon, size: 20, color: scheme.onSurface),
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
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
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
