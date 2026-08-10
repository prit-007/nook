import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS-Spotlight-style pull-to-search gesture.
///
/// Wraps a scrollable and listens for drag-driven downward scroll updates at
/// the top (pixels driven negative by BouncingScrollPhysics). When the user
/// drags past [threshold] pixels (only while actively dragging, not during a
/// fling or ballistic scroll), [onTrigger] fires with haptic feedback.
class PullToSearch extends StatefulWidget {
  const PullToSearch({
    super.key,
    required this.child,
    required this.onTrigger,
    this.threshold = 80,
  });

  final Widget child;
  final VoidCallback onTrigger;
  final double threshold;

  @override
  State<PullToSearch> createState() => _PullToSearchState();
}

class _PullToSearchState extends State<PullToSearch> {
  bool _triggered = false;

  bool _onNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _triggered = false;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels < 0) {
      // With BouncingScrollPhysics, pulling down at the top drives pixels
      // negative. Trigger once the pull passes the threshold (drag only, so
      // flings and ballistic scrolls are ignored).
      if (!_triggered &&
          notification.metrics.pixels.abs() >= widget.threshold) {
        _triggered = true;
        // ignore: unawaited_futures
        HapticFeedback.lightImpact();
        widget.onTrigger();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}
