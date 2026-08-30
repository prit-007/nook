import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/app_info.dart';
import '../../core/widgets/dock_safe_area.dart';

/// Full editorial "About Us" screen for nook.
///
/// Employs deep glassmorphism, macro-typography, and high-contrast
/// spacing to deliver a premium, editorial reading experience.
class SettingsAboutScreen extends ConsumerWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final version = ref.watch(appInfoProvider).maybeWhen(
          data: (info) => info.version,
          orElse: () => '\u2014',
        );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'Manifesto',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          DockSafeArea.bottomOf(context) + 16,
        ),
        children: [
          // ── The Brand Hero ──────────────────────────────────────────
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedBookOpen01,
                color: scheme.onSurface,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'nook.',
            textAlign: TextAlign.center,
            style: text.displayLarge?.copyWith(
              fontSize: 72,
              fontWeight: FontWeight.w400,
              letterSpacing: -4.0,
              height: 0.9,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'EDITION $version',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 4.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'The private, editorial space for your mind.',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.3,
            ),
          ),

          // ── The Philosophy ──────────────────────────────────────────
          const SizedBox(height: 64),
          _SectionHeader(scheme: scheme, text: text, title: 'The Philosophy'),
          const SizedBox(height: 16),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'Born from a singular, uncompromising vision: your thoughts '
              'are your own. The canvas you use to capture them should not '
              'just function\u2014it should inspire. Every interaction is crafted '
              'to feel like a digital masterpiece.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.8,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // ── Absolute Sovereignty ──────────────────────────────────
          const SizedBox(height: 40),
          _SectionHeader(
            scheme: scheme,
            text: text,
            title: 'Absolute Sovereignty',
          ),
          const SizedBox(height: 16),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'A strictly local-first architecture. No cloud servers scraping '
              'your ideas. No analytics tracking your habits. Everything you '
              'write or sketch lives encrypted, exclusively on your device.\n\n'
              'When syncing is required, our proprietary peer-to-peer engine '
              'bypasses the public internet entirely, bridging your devices '
              'through your own local network.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.8,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // ── The Art of Focus ───────────────────────────────
          const SizedBox(height: 40),
          _SectionHeader(
            scheme: scheme,
            text: text,
            title: 'The Art of Focus',
          ),
          const SizedBox(height: 16),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'Designed to disappear. Through fluid glassmorphic layers and '
              'dynamic, macro-typographic layouts, the interface adapts to '
              'your rhythm. It provides the quiet, luxurious whitespace '
              'necessary to transform fragmented thoughts into clarity.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.8,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // ── Provenance ──────────────────────────────────────
          const SizedBox(height: 40),
          _SectionHeader(scheme: scheme, text: text, title: 'Provenance'),
          const SizedBox(height: 16),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'Engineered with absolute precision in Rajkot, Gujarat by '
              'Prit Vasani. Crafted by Developer\'s Paradise on a foundation '
              'of open-source technologies, driven by a relentless pursuit '
              'of uncompromised privacy and luxury design.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.8,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // ── Architecture & Licensing ──────────────────────────
          const SizedBox(height: 56),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _Badge(scheme: scheme, label: 'GPL-3.0 License'),
              _Badge(scheme: scheme, label: 'Flutter'),
              _Badge(scheme: scheme, label: 'SQLite'),
              _Badge(scheme: scheme, label: 'libp2p'),
              _Badge(scheme: scheme, label: 'Perfect Freehand'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Internal Widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.scheme,
    required this.text,
    required this.title,
  });
  final ColorScheme scheme;
  final TextTheme text;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: text.titleSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.scheme, required this.child});
  final ColorScheme scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.scheme, required this.label});
  final ColorScheme scheme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
