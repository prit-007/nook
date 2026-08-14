import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Conflict resolution card — editorial split-view layout.
///
/// The local version gets the primary theme tint and the incoming remote
/// version gets a secondary tint, making the decision visually intuitive.
class ConflictCard extends StatelessWidget {
  const ConflictCard({
    super.key,
    required this.noteTitle,
    required this.localDeviceName,
    required this.remoteDeviceName,
    this.onResolved,
  });

  final String noteTitle;
  final String localDeviceName;
  final String remoteDeviceName;
  final void Function(String choice)? onResolved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                color: scheme.error,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Conflict: $noteTitle',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Edited independently on both devices. Choose which version to keep.',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Local version.
                Expanded(
                  child: _VersionPanel(
                    tint: scheme.primary,
                    containerColor:
                        scheme.primaryContainer.withValues(alpha: 0.6),
                    onContainerColor: scheme.onPrimaryContainer,
                    icon: HugeIcons.strokeRoundedSmartPhone01,
                    deviceName: localDeviceName,
                    label: 'This device',
                    actionLabel: 'Keep this device',
                    onAction: () => _resolve(context, 'local'),
                  ),
                ),
                const SizedBox(width: 12),
                // Incoming remote version.
                Expanded(
                  child: _VersionPanel(
                    tint: scheme.tertiary,
                    containerColor:
                        scheme.tertiaryContainer.withValues(alpha: 0.6),
                    onContainerColor: scheme.onTertiaryContainer,
                    icon: HugeIcons.strokeRoundedLayers01,
                    deviceName: remoteDeviceName,
                    label: 'Incoming',
                    actionLabel: 'Keep incoming',
                    onAction: () => _resolve(context, 'remote'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _resolve(context, 'both'),
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCopyPlus,
                size: 18,
                color: scheme.onSurface),
            label: const Text(
              'Keep both',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _resolve(BuildContext context, String choice) {
    if (onResolved != null) {
      onResolved!(choice);
    } else {
      Navigator.of(context).pop(choice);
    }
  }
}

class _VersionPanel extends StatelessWidget {
  const _VersionPanel({
    required this.tint,
    required this.containerColor,
    required this.onContainerColor,
    required this.icon,
    required this.deviceName,
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  final Color tint;
  final Color containerColor;
  final Color onContainerColor;
  final List<List<dynamic>> icon;
  final String deviceName;
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, size: 18, color: tint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: onContainerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tint,
                foregroundColor: onContainerColor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onAction,
              child: Text(
                actionLabel,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
