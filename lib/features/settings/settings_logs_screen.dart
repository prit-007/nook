import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../core/providers/talker_provider.dart';

/// In-app log viewer powered by talker_flutter's [TalkerScreen].
class SettingsLogsScreen extends ConsumerStatefulWidget {
  const SettingsLogsScreen({super.key});

  @override
  ConsumerState<SettingsLogsScreen> createState() => _SettingsLogsScreenState();
}

class _SettingsLogsScreenState extends ConsumerState<SettingsLogsScreen> {
  static const _helpSeenKey = 'logs_help_seen';

  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_helpSeenKey) ?? false;
      if (!seen && mounted) {
        setState(() => _showHelp = true);
      }
    });
  }

  Future<void> _closeHelp() async {
    setState(() => _showHelp = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_helpSeenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // The core developer tool
          Positioned.fill(
            child: TalkerScreen(
              talker: talker,
              appBarTitle: 'Diagnostic Logs',
              theme: TalkerScreenTheme(
                backgroundColor: scheme.surface,
                textColor: scheme.onSurface,
                cardColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                logColors: _logColors(scheme),
              ),
              isLogOrderReversed: true,
              isLogsExpanded: true,
            ),
          ),

          // Sleek Help Affordance (Top Right)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 16,
            child: _HelpFloatingPill(
              onPressed: () => setState(() => _showHelp = true),
            ),
          ),

          // The Walkthrough Overlay
          if (_showHelp) _LogsHelpOverlay(onDone: _closeHelp),
        ],
      ),
    );
  }
}

class _HelpFloatingPill extends StatelessWidget {
  const _HelpFloatingPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Log documentation',
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedBookOpen01,
                    color: scheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Guide',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Map<String, Color> _logColors(ColorScheme scheme) => {
      TalkerKey.error: scheme.error,
      TalkerKey.critical: scheme.error,
      TalkerKey.exception: scheme.error,
      TalkerKey.warning: const Color(0xFFE67E22), // Muted Orange
      TalkerKey.info: scheme.primary,
      TalkerKey.debug: scheme.onSurfaceVariant,
      TalkerKey.verbose: scheme.onSurfaceVariant.withValues(alpha: 0.5),
      NookLogKey.sync: const Color(0xFF8E44AD), // Muted Purple
      NookLogKey.database: const Color(0xFF16A085), // Teal
      NookLogKey.editor: const Color(0xFFF39C12), // Amber
      NookLogKey.security: const Color(0xFFD81B60), // Rose
    };

typedef _LegendEntry = ({String label, Color color});

class _TourStep {
  const _TourStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.legend,
  });

  final String title;
  final String description;
  final List<List<dynamic>> icon;
  final Color color;
  final List<_LegendEntry>? legend;
}

class _LogsHelpOverlay extends StatefulWidget {
  const _LogsHelpOverlay({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_LogsHelpOverlay> createState() => _LogsHelpOverlayState();
}

class _LogsHelpOverlayState extends State<_LogsHelpOverlay> {
  int _step = 0;

  List<_TourStep> _steps(ColorScheme scheme) => [
        _TourStep(
          title: 'System Diagnostics',
          description:
              'Every action—saving, syncing, locking, and unexpected errors—is recorded in real-time. This provides absolute transparency into your vault.',
          icon: HugeIcons.strokeRoundedScroll,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Domain Filtering',
          description:
              'Use the chips in the top bar to filter the data stream. Isolate specific events like peer-to-peer sync or biometric security checks.',
          icon: HugeIcons.strokeRoundedSlidersHorizontal,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Global Search',
          description:
              'Instantly locate a specific note ID, connected device name, or error code across the entire historical log.',
          icon: HugeIcons.strokeRoundedSearch01,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Data Control',
          description:
              'The actions menu allows you to copy a specific entry to your clipboard, export the entire report, or securely clear the log history.',
          icon: HugeIcons.strokeRoundedMoreHorizontal,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Color Syntax',
          description:
              'Each system domain is color-coded for rapid visual scanning across the diagnostic feed.',
          icon: HugeIcons.strokeRoundedPaintBoard,
          color: scheme.primary,
          legend: [
            (label: 'Error', color: scheme.error),
            (label: 'Warning', color: const Color(0xFFE67E22)),
            (label: 'Info', color: scheme.primary),
            (label: 'Debug', color: scheme.onSurfaceVariant),
            (label: 'Sync', color: const Color(0xFF8E44AD)),
            (label: 'Database', color: const Color(0xFF16A085)),
            (label: 'Editor', color: const Color(0xFFF39C12)),
            (label: 'Security', color: const Color(0xFFD81B60)),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = _steps(scheme);
    final step = steps[_step];
    final isLast = _step == steps.length - 1;

    return Positioned.fill(
      child: Stack(
        children: [
          // Frosted background mask
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: ColoredBox(
                color: scheme.surface.withValues(alpha: 0.8),
              ),
            ),
          ),

          // Skip Button
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: 24,
            child: GestureDetector(
              onTap: widget.onDone,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // Constrained, Adaptive Tour Card
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420), // Prevents ultra-wide stretching
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _TourCard(
                    key: ValueKey(_step),
                    step: step,
                    scheme: scheme,
                    isLast: isLast,
                    onNext: () => setState(() => _step++),
                    onDone: widget.onDone,
                  ),
                ),
              ),
            ),
          ),

          // Navigation Dots
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(steps.length, (i) {
                final active = i == _step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: active ? 32 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.scheme,
    required this.isLast,
    required this.onNext,
    required this.onDone,
  });

  final _TourStep step;
  final ColorScheme scheme;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final stepColor = step.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stepColor.withValues(alpha: 0.1),
              border: Border.all(color: stepColor.withValues(alpha: 0.3)),
            ),
            child: HugeIcon(
              icon: step.icon,
              size: 32,
              color: stepColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (step.legend != null) ...[
            const SizedBox(height: 32),
            _Legend(scheme: scheme, entries: step.legend!),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: isLast ? onDone : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                isLast ? 'Enter Logs' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.scheme, required this.entries});

  final ColorScheme scheme;
  final List<_LegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
