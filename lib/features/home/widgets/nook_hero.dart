// lib/features/home/widgets/nook_hero.dart
//
// NookHero: the Home header.
// - Expanded: sentence-case vault label, calm Playfair greeting, quick-capture bar.
// - Collapsed (pinned): plain "Nook" title + sync status + search.
// - Sync is a status pill here, not a dock tab.
// - No all-caps, no stacked alpha on text surfaces, text >= 12sp,
//   entrance plays once per app session, honours reduce-motion,
//   tracking is zeroed for Indic scripts, layout grows with text scale.
//
// Uses only Flutter + hugeicons (no new dependencies).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/nook_tokens.dart';

enum NookSyncStatus { synced, syncing, conflict, localOnly }

class NookHeroSliver extends StatelessWidget {
  const NookHeroSliver({
    super.key,
    required this.noteCount,
    required this.syncStatus,
    required this.onSearch,
    required this.onSyncTap,
    required this.onCaptureText,
    required this.onCaptureChecklist,
    required this.onCaptureDoodle,
    this.onCaptureVoice,
    this.title = 'Nook',
    this.animate = true,
  });

  final int noteCount;
  final NookSyncStatus syncStatus;
  final VoidCallback onSearch;
  final VoidCallback onSyncTap;
  final VoidCallback onCaptureText;
  final VoidCallback onCaptureChecklist;
  final VoidCallback onCaptureDoodle;
  final VoidCallback? onCaptureVoice; // hide the mic until voice exists
  final String title;
  final bool animate;

  @visibleForTesting
  static void resetEntranceForTesting() => _EntranceOnce._played = false;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeroDelegate(hero: this, topInset: topInset, textScale: scale),
    );
  }
}

const double _barHeight = 64;
const double _bodyHeight = 168; // label + greeting + capture bar at 1.0x

class _HeroDelegate extends SliverPersistentHeaderDelegate {
  _HeroDelegate({
    required this.hero,
    required this.topInset,
    required this.textScale,
  });

  final NookHeroSliver hero;
  final double topInset;
  final double textScale;

  // Greeting + label grow with text scale; capture bar height stays fixed.
  double get _extra => (textScale - 1) * 70;

  @override
  double get minExtent => topInset + _barHeight;

  @override
  double get maxExtent => topInset + _barHeight + _bodyHeight + _extra;

  @override
  bool shouldRebuild(covariant _HeroDelegate old) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final hPad = tokens.radiusLg; // 20.0 from NookTokens
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final bodyOpacity = Curves.easeOut.transform((1 - t * 1.6).clamp(0.0, 1.0));
    final titleOpacity =
        Curves.easeIn.transform(((t - 0.55) / 0.45).clamp(0.0, 1.0));

    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant
                  .withValues(alpha: t), // animated, not stacked
              width: 1,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Expanded body
            Positioned(
              left: hPad,
              right: hPad,
              top: topInset + _barHeight - (t * 20),
              child: IgnorePointer(
                ignoring: bodyOpacity < 0.1,
                child: Opacity(
                  opacity: bodyOpacity,
                  child: _EntranceOnce(
                    enabled: hero.animate,
                    child: _HeroBody(hero: hero),
                  ),
                ),
              ),
            ),
            // Top bar (always visible)
            Positioned(
              left: 0,
              right: 0,
              top: topInset,
              height: _barHeight,
              child: Padding(
                padding: EdgeInsets.only(left: hPad, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: titleOpacity,
                        child: Semantics(
                          header: true,
                          child: Text(
                            hero.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: _tracking(context, -0.4),
                                ),
                          ),
                        ),
                      ),
                    ),
                    _SyncPill(status: hero.syncStatus, onTap: hero.onSyncTap),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Search notes',
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        hero.onSearch();
                      },
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedSearch01,
                        size: 22,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- body

class _HeroBody extends StatelessWidget {
  const _HeroBody({required this.hero});
  final NookHeroSliver hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = hero.noteCount;
    final label =
        n == 0 ? 'Your vault' : 'Your vault · $n ${n == 1 ? 'note' : 'notes'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sentence case, 12sp. Replaces the 9sp all-caps "YOUR VAULT".
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: _tracking(context, 0.2),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            _greeting(DateTime.now().hour),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700, // was w900
              height: 1.12,
              letterSpacing: _tracking(context, -0.8),
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CaptureBar(
          onText: hero.onCaptureText,
          onChecklist: hero.onCaptureChecklist,
          onDoodle: hero.onCaptureDoodle,
          onVoice: hero.onCaptureVoice,
        ),
      ],
    );
  }
}

String _greeting(int hour) {
  if (hour < 12) return 'Morning thoughts.';
  if (hour < 17) return 'Afternoon flow.';
  if (hour < 22) return 'Evening reflections.';
  return 'Late night ideas.';
}

/// Negative tracking breaks joined glyph shaping in Gujarati/Devanagari.
double _tracking(BuildContext context, double latin) {
  const indic = {'gu', 'hi', 'mr'};
  final code = Localizations.maybeLocaleOf(context)?.languageCode;
  return indic.contains(code) ? 0 : latin;
}

// -------------------------------------------------------- capture bar

class _CaptureBar extends StatelessWidget {
  const _CaptureBar({
    required this.onText,
    required this.onChecklist,
    required this.onDoodle,
    this.onVoice,
  });

  final VoidCallback onText;
  final VoidCallback onChecklist;
  final VoidCallback onDoodle;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = context.tokens.radiusLg;

    return Material(
      color: scheme.surfaceContainerHigh, // solid role: contrast is predictable
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Capture a thought',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onText();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedPencilEdit02,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Capture a thought',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _CaptureAction(
              tooltip: 'New checklist',
              icon: HugeIcons.strokeRoundedCheckmarkSquare02,
              onTap: onChecklist,
            ),
            _CaptureAction(
              tooltip: 'New doodle',
              icon: HugeIcons.strokeRoundedPenTool01,
              onTap: onDoodle,
            ),
            if (onVoice != null)
              _CaptureAction(
                tooltip: 'Voice note',
                icon: HugeIcons.strokeRoundedMic01,
                onTap: onVoice!,
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: HugeIcon(icon: icon, size: 22, color: scheme.primary),
    );
  }
}

// ---------------------------------------------------------- sync pill

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.status, required this.onTap});
  final NookSyncStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (String label, String semantic, Color bg, Color fg, Widget icon) =
        switch (status) {
      NookSyncStatus.synced => (
          'Synced',
          'Sync status: all devices up to date',
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
          HugeIcon(
            icon: HugeIcons.strokeRoundedTick02,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
      NookSyncStatus.syncing => (
          'Syncing',
          'Sync status: syncing now',
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
        ),
      NookSyncStatus.conflict => (
          'Needs review',
          'Sync status: conflicts need your review',
          scheme.errorContainer,
          scheme.onErrorContainer,
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 14,
            color: scheme.onErrorContainer,
          ),
        ),
      // Offline-first: not an error, just a fact.
      NookSyncStatus.localOnly => (
          'On this device',
          'Sync status: stored on this device only',
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
          HugeIcon(
            icon: HugeIcons.strokeRoundedFingerPrint,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
    };

    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: 28,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
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

// ------------------------------------------------------ entrance (once)

/// Plays a single fade + rise the first time the hero appears in a session.
/// Skipped on rebuilds, tab revisits, and when reduce-motion is on.
class _EntranceOnce extends StatefulWidget {
  const _EntranceOnce({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  static bool _played = false;

  @override
  State<_EntranceOnce> createState() => _EntranceOnceState();
}

class _EntranceOnceState extends State<_EntranceOnce> {
  bool? _animate;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    _animate ??=
        !_EntranceOnce._played && !MediaQuery.disableAnimationsOf(context);
    _EntranceOnce._played = true;
    if (_animate == false) return widget.child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      child: widget.child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
    );
  }
}
