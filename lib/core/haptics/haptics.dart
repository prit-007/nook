import 'package:flutter/services.dart';

/// Centralized haptic feedback controller for Nook.
///
/// Provides a consistent, unified entrypoint for both raw physical impacts
/// ([selection], [light], [medium], [heavy]) and semantic user-intent actions
/// ([success], [warning], [error], [toggle]).
///
/// Haptics can be globally toggled via [enabled] (e.g. from user settings),
/// or overridden in tests/debug environments via [debugOverrideEnabled].
abstract final class AppHaptics {
  /// Whether haptic feedback is globally enabled (e.g. user preference).
  ///
  /// Defaults to `true`.
  static bool enabled = true;

  /// Debug or test override flag.
  ///
  /// When non-null, this value takes precedence over [enabled].
  /// Useful for silencing haptics in automated widget tests or forcing them on.
  static bool? debugOverrideEnabled;

  /// Returns `true` if haptics are currently permitted to trigger.
  static bool get isEnabled => debugOverrideEnabled ?? enabled;

  // --- Core impacts ---

  /// Discrete selection click (e.g. picker wheel, tab switch, segmented button).
  static Future<void> selection() async {
    if (!isEnabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Subtle light impact (e.g. tap, reorder tick, chip selection).
  static Future<void> light() async {
    if (!isEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Noticeable medium impact (e.g. toggle switch, popup menu reveal, drag release).
  static Future<void> medium() async {
    if (!isEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Prominent heavy impact (e.g. destructive action, modal dismissal confirmation).
  static Future<void> heavy() async {
    if (!isEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  // --- Semantic actions ---

  /// Indicates a successful operation (e.g. sync complete, export succeeded).
  ///
  /// Triggers a light impact.
  static Future<void> success() => light();

  /// Indicates a warning or caution state (e.g. unsaved changes prompt, conflict detected).
  ///
  /// Triggers a medium impact.
  static Future<void> warning() => medium();

  /// Indicates an error or failed action (e.g. wrong PIN, network failure).
  ///
  /// Triggers a heavy impact.
  static Future<void> error() => heavy();

  /// Indicates a toggle state change (e.g. checkbox, switch, radio item).
  ///
  /// Triggers a selection click.
  static Future<void> toggle() => selection();
}
