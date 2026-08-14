import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/app_info.dart';

/// Full editorial "About Us" screen.
///
/// Uses `SingleChildScrollView` with the app's serif/sans-serif contrast:
/// Playfair Display for the "nook." title and section headers, Inter for body.
/// Every surface is frosted glass to maintain the luxury editorial feel.
class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
        children: [
          // ── Header ──────────────────────────────────────────
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Icon(
                LucideIcons.bookOpen,
                size: 48,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'nook.',
            textAlign: TextAlign.center,
            style: text.displayLarge?.copyWith(
              fontSize: 56,
              letterSpacing: -2.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'VERSION ${AppInfo.version}',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: scheme.primary,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The private, editorial space for your mind.',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),

          // ── Vision ──────────────────────────────────────────
          const SizedBox(height: 48),
          _SectionHeader(scheme: scheme, text: text, title: 'Our Vision'),
          const SizedBox(height: 12),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'Nook was born from a singular, uncompromising vision: your thoughts '
              'belong to you, and the tools you use to capture them should feel '
              'like a masterpiece.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.7,
              ),
            ),
          ),

          // ── Zero Telemetry ──────────────────────────────────
          const SizedBox(height: 32),
          _SectionHeader(
              scheme: scheme,
              text: text,
              title: 'Zero Telemetry. Absolute Ownership.'),
          const SizedBox(height: 12),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'Your data is yours. Nook operates on a strictly local-first '
              'architecture. There are no cloud servers scraping your ideas, no '
              'analytics tracking your habits, and no required accounts. '
              'Everything you write, sketch, or plan lives encrypted on your '
              'device.\n\n'
              'When you need to share or backup your vault, Nook\'s proprietary '
              'peer-to-peer sync engine uses your local network to beam data '
              'directly to your other devices\u2014bypassing the public internet '
              'entirely.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.7,
              ),
            ),
          ),

          // ── Designed for Flow ───────────────────────────────
          const SizedBox(height: 32),
          _SectionHeader(
              scheme: scheme, text: text, title: 'Designed for Flow'),
          const SizedBox(height: 12),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'Every pixel of Nook is crafted to get out of your way. From the '
              'fluid glassmorphic canvases to the dynamic, macro-typographic '
              'layouts that adapt to your chosen color signature, the interface '
              'is designed to make capturing ideas a tactile, delightful '
              'experience.\n\n'
              'Whether you are sketching a concept, tracking a project, or '
              'drafting a late-night thought, Nook provides the quiet, luxurious '
              'whitespace you need to focus.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.7,
              ),
            ),
          ),

          // ── Crafted by ──────────────────────────────────────
          const SizedBox(height: 32),
          _SectionHeader(
              scheme: scheme,
              text: text,
              title: 'Crafted by Developer\'s Paradise'),
          const SizedBox(height: 12),
          _GlassCard(
            scheme: scheme,
            child: Text(
              'Engineered with precision in Rajkot, Gujarat by Prit Vasani.\n'
              'Built on a foundation of open-source technologies, driven by a '
              'passion for uncompromised privacy and luxury design.',
              style: text.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.7,
              ),
            ),
          ),

          // ── License & Technologies ──────────────────────────
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(scheme: scheme, label: 'GPL-3.0 License'),
              const SizedBox(width: 8),
              _Badge(scheme: scheme, label: 'Flutter'),
              const SizedBox(width: 8),
              _Badge(scheme: scheme, label: 'SQLite'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(scheme: scheme, label: 'libp2p'),
              const SizedBox(width: 8),
              _Badge(scheme: scheme, label: 'Perfect Freehand'),
            ],
          ),

          const SizedBox(height: 56),
        ],
      ),
    );
  }
}

// ── Internal widgets ─────────────────────────────────────────────────────────

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
    return Text(
      title,
      style: text.headlineSmall?.copyWith(
        color: scheme.onSurface,
        fontSize: 20,
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
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
