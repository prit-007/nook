import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/widgets/dock_safe_area.dart';
import 'privacy_explainer_copy.dart';

/// Deep privacy explainer — how Nook keeps notes on-device.
///
/// Reachable from Settings → Privacy (and via `/settings/privacy/explainer`).
/// Tone: calm and factual. Copy lives in [privacy_explainer_copy.dart] so
/// tests can lock claims down.
class PrivacyExplainerScreen extends StatelessWidget {
  const PrivacyExplainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'How your data stays yours',
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
          _ExplainerCard(
            icon: HugeIcons.strokeRoundedDatabase,
            title: kPrivacyWhereDataLivesTitle,
            body: kPrivacyWhereDataLivesBody,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          _ExplainerCard(
            icon: HugeIcons.strokeRoundedWifi01,
            title: kPrivacyWhatSyncSendsTitle,
            body: kPrivacyWhatSyncSendsBody,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          _ExplainerCard(
            icon: HugeIcons.strokeRoundedShield01,
            title: kPrivacyNeverCollectsTitle,
            body: kPrivacyNeverCollectsBody,
            scheme: scheme,
          ),
          const SizedBox(height: 16),
          _ExplainerCard(
            icon: HugeIcons.strokeRoundedSearch01,
            title: kPrivacyHowToVerifyTitle,
            body: kPrivacyHowToVerifyBody,
            scheme: scheme,
          ),
          const SizedBox(height: 28),
          Text(
            'Nook motto — Your notes. Your device. Yours.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }
}

class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.scheme,
  });

  /// HugeIcon glyph data (`HugeIcons.strokeRoundedXxx`), not `IconData`.
  final List<List<dynamic>> icon;
  final String title;
  final String body;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: icon, size: 22, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
