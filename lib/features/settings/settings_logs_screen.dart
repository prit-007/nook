import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../core/providers/talker_provider.dart';

/// In-app log viewer powered by talker_flutter's [TalkerScreen].
///
/// Colors are mapped to the app's theme (error/warning/info/debug/verbose) plus
/// custom domain keys (sync, database, editor, security), newest first and
/// expanded by default. A help button in the app bar triggers a built-in
/// walkthrough tour overlay — talker has no tutorial of its own, so this is a
/// pure-Flutter overlay stacked on top of the screen.
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
    // Show the walkthrough on first visit only; afterwards it stays hidden
    // unless the user taps the help icon in the app bar.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: TalkerScreen(
              talker: talker,
              appBarTitle: 'App Logs',
              // Note: this replaces the auto back button; navigation back is
              // available via system gestures / browser back.
              appBarLeading: IconButton(
                tooltip: 'Log help',
                onPressed: () => setState(() => _showHelp = true),
                icon: Icon(LucideIcons.circleHelp, color: scheme.onSurface),
              ),
              theme: TalkerScreenTheme(
                backgroundColor: scheme.surface,
                textColor: scheme.onSurface,
                // Slightly elevated than the surface so cards read as cards.
                cardColor: scheme.surfaceContainerHighest,
                logColors: _logColors(scheme),
              ),
              isLogOrderReversed: true,
              isLogsExpanded: true,
            ),
          ),
          if (_showHelp) _LogsHelpOverlay(onDone: _closeHelp),
        ],
      ),
    );
  }
}

/// Maps every log type (base + custom domain keys) to a theme-aware color for
/// [TalkerScreenTheme.logColors].
Map<String, Color> _logColors(ColorScheme scheme) => {
      TalkerKey.error: scheme.error,
      TalkerKey.critical: scheme.error,
      TalkerKey.exception: scheme.error,
      TalkerKey.warning: const Color(0xFFEF6C00),
      TalkerKey.info: scheme.primary,
      TalkerKey.debug: scheme.onSurfaceVariant,
      TalkerKey.verbose: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      NookLogKey.sync: const Color(0xFF6D5BFF),
      NookLogKey.database: const Color(0xFF14B8A6),
      NookLogKey.editor: const Color(0xFFFFB300),
      NookLogKey.security: const Color(0xFFF43F5E),
    };

Color _onColor(Color bg) =>
    ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;

typedef _LegendEntry = ({String label, Color color});

// ---------------------------------------------------------------------------
// Help / walkthrough tour
// ---------------------------------------------------------------------------

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
  final IconData icon;
  final Color color;
  final List<_LegendEntry>? legend;
}

/// Full-screen walkthrough overlay stacked above the [TalkerScreen].
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
          title: 'What are logs?',
          description:
              'Every action Nook takes — saving, syncing, locking, errors — '
              'is recorded here so you can see exactly what happened and when.',
          icon: LucideIcons.scrollText,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Filter by type',
          description:
              'The chips in the app bar filter the list. Toggle any type on '
              'or off to focus on sync, database, editor or security events.',
          icon: LucideIcons.slidersHorizontal,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Search logs',
          description:
              'Type in the search field to instantly find a note, device or '
              'error message across every entry.',
          icon: LucideIcons.search,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Actions menu',
          description:
              'Open the menu in the app bar for the full toolset — copy an '
              'entry, share the whole report, or clear the log history.',
          icon: LucideIcons.moreHorizontal,
          color: scheme.primary,
        ),
        _TourStep(
          title: 'Color legend',
          description: 'Each log type has its own color, from errors to the '
              'sync, database, editor and security domains.',
          icon: LucideIcons.palette,
          color: scheme.primary,
          legend: [
            (label: 'Error', color: scheme.error),
            (label: 'Warning', color: const Color(0xFFEF6C00)),
            (label: 'Info', color: scheme.primary),
            (label: 'Debug', color: scheme.onSurfaceVariant),
            (
              label: 'Verbose',
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6)
            ),
            (label: 'Sync', color: const Color(0xFF6D5BFF)),
            (label: 'Database', color: const Color(0xFF14B8A6)),
            (label: 'Editor', color: const Color(0xFFFFB300)),
            (label: 'Security', color: const Color(0xFFF43F5E)),
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
          // Dim + blur the logs screen beneath the tour.
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: TextButton(
              onPressed: widget.onDone,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(steps.length, (i) {
                final active = i == _step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary
                        : Colors.white.withValues(alpha: 0.35),
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

/// One glassmorphism step card in the tour.
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stepColor,
                  boxShadow: [
                    BoxShadow(
                      color: stepColor.withValues(alpha: 0.45),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(step.icon, size: 30, color: _onColor(stepColor)),
              ),
              const SizedBox(height: 22),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                step.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (step.legend != null) ...[
                const SizedBox(height: 24),
                _Legend(scheme: scheme, entries: step.legend!),
              ],
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: isLast ? onDone : onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: stepColor,
                    foregroundColor: _onColor(stepColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Done' : 'Next',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Color-coded legend shown on the final tour step.
class _Legend extends StatelessWidget {
  const _Legend({required this.scheme, required this.entries});

  final ColorScheme scheme;
  final List<_LegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 10,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                entry.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
