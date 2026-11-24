import 'package:flutter/material.dart';

/// Centralized Material 3 motion tokens and animation constants for nook.
///
/// Follows the Material 3 motion specification:
/// - Short durations (50-200ms) for micro-interactions, icons, and small fades.
/// - Medium durations (250-400ms) for standard transitions, cards, and dialogs.
/// - Long durations (450-600ms) for page-level transitions and full-screen reveals.
/// - Standard easing for natural acceleration and deceleration.
/// - Emphasized easing for elements entering or exiting the screen.
abstract class AppMotion {
  // ── Durations ───────────────────────────────────────────────
  static const Duration short1 = Durations.short1; // 50ms
  static const Duration short2 = Durations.short2; // 100ms
  static const Duration short3 = Durations.short3; // 150ms
  static const Duration short4 = Durations.short4; // 200ms

  static const Duration medium1 = Durations.medium1; // 250ms
  static const Duration medium2 = Durations.medium2; // 300ms
  static const Duration medium3 = Durations.medium3; // 350ms
  static const Duration medium4 = Durations.medium4; // 400ms

  static const Duration long1 = Durations.long1; // 450ms
  static const Duration long2 = Durations.long2; // 500ms

  // ── Standard Semantic Durations ─────────────────────────────
  static const Duration micro = Durations.short2;
  static const Duration toggle = Durations.short4;
  static const Duration standard = Durations.medium2;
  static const Duration page = Durations.medium4;
  static const Duration modal = Durations.medium4;
  static const Duration toast = Durations.short3;

  // ── Easings ─────────────────────────────────────────────────
  static const Curve standardEasing = Easing.standard;
  static const Curve standardDecelerate = Easing.standardDecelerate;
  static const Curve standardAccelerate = Easing.standardAccelerate;

  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve emphasizedDecelerate = Easing.emphasizedDecelerate;
  static const Curve emphasizedAccelerate = Easing.emphasizedAccelerate;
  static const Curve emphasizedBack = Curves.easeOutBack;

  // ── Component Transitions ───────────────────────────────────
  static const Duration toolbarExpand = Durations.medium2;
  static const Curve toolbarCurve = Easing.emphasizedDecelerate;

  static const Duration shapeSnap = Durations.short4;
  static const Curve shapeSnapCurve = Easing.emphasizedDecelerate;

  // ── Stagger Constants ─────────────────────────────────────────
  static const Duration staggerStep = Duration(milliseconds: 30);
  static const Duration staggerMax = Duration(milliseconds: 300);

  static Duration staggerDelay(int index,
      {Duration step = staggerStep, Duration max = staggerMax}) {
    final ms = (index * step.inMilliseconds).clamp(0, max.inMilliseconds);
    return Duration(milliseconds: ms);
  }
}
