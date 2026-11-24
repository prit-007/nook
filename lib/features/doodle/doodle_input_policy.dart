import 'package:flutter/gestures.dart';

/// Decides which pointer events should drive drawing or interaction on the
/// doodle canvas.
///
/// When a stylus has been used recently, subsequent touch events are treated
/// as palm contact and ignored, so resting the palm on the screen while
/// writing does not create stray marks. With [stylusOnlyMode] all touch is
/// rejected, so only the stylus draws.
class DoodleInputPolicy {
  /// How long after stylus activity a touch is still considered a palm.
  static const palmRejectionWindow = Duration(milliseconds: 800);

  /// Two stylus downs within this window count as a double-tap tool swap.
  static const doubleTapWindow = Duration(milliseconds: 300);

  DateTime? _lastStylusActivity;
  DateTime? _lastStylusDown;

  DoodleInputPolicy();

  /// Records that the stylus was active at [time], refreshing the palm
  /// rejection window.
  void noteStylusActivity(DateTime time) {
    _lastStylusActivity = time;
  }

  /// Whether [event] should be accepted for drawing or interaction.
  ///
  /// Stylus events are always accepted and refresh the palm-rejection window.
  /// Touch events are rejected while within [palmRejectionWindow] of the last
  /// stylus activity, and always when [stylusOnlyMode] is set.
  bool shouldAccept(
    PointerEvent event, {
    DateTime? now,
    bool stylusOnlyMode = false,
  }) {
    final time = now ?? DateTime.now();
    switch (event.kind) {
      case PointerDeviceKind.stylus:
        noteStylusActivity(time);
        return true;
      case PointerDeviceKind.touch:
        if (stylusOnlyMode) return false;
        final last = _lastStylusActivity;
        if (last != null && time.difference(last) < palmRejectionWindow) {
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  /// Whether [event] signals a tool swap request:
  /// - stylus secondary (barrel) button press
  /// - stylus double-tap (two stylus downs within [doubleTapWindow])
  bool shouldSwapTool(PointerEvent event, {DateTime? now}) {
    final time = now ?? DateTime.now();
    if (event.kind != PointerDeviceKind.stylus) return false;
    if (event is! PointerDownEvent) return false;
    if (event.buttons & kSecondaryButton != 0) return true;
    final last = _lastStylusDown;
    if (last != null && time.difference(last) < doubleTapWindow) {
      _lastStylusDown = null;
      return true;
    }
    _lastStylusDown = time;
    return false;
  }
}
