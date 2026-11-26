import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../haptics/haptics.dart';

/// A resizable two-pane split view with a draggable divider that persists its
/// position ratio to [SharedPreferences].
class ResizableSplitView extends StatefulWidget {
  const ResizableSplitView({
    super.key,
    required this.left,
    required this.right,
    this.initialRatio = 0.45,
    this.minRatio = 0.25,
    this.maxRatio = 0.75,
    this.storageKey = 'nook_split_pane_ratio',
    this.dividerHitWidth = 12.0,
  });

  /// The widget rendered in the left pane.
  final Widget left;

  /// The widget rendered in the right pane.
  final Widget right;

  /// Default ratio of left pane width to total available width (0.0 to 1.0).
  final double initialRatio;

  /// Minimum allowable width ratio for the left pane.
  final double minRatio;

  /// Maximum allowable width ratio for the left pane.
  final double maxRatio;

  /// SharedPreferences key used to persist the user's customized divider position.
  final String storageKey;

  /// Touch/mouse hit-test width of the draggable divider handle.
  final double dividerHitWidth;

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
    _loadPersistedRatio();
  }

  Future<void> _loadPersistedRatio() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(widget.storageKey);
    if (saved != null && mounted) {
      setState(() {
        _ratio = saved.clamp(widget.minRatio, widget.maxRatio);
      });
    }
  }

  Future<void> _saveRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(widget.storageKey, ratio);
  }

  void _onDragUpdate(DragUpdateDetails details, double totalWidth) {
    if (totalWidth <= 0) return;
    final deltaRatio = details.delta.dx / totalWidth;
    setState(() {
      _ratio = (_ratio + deltaRatio).clamp(widget.minRatio, widget.maxRatio);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _saveRatio(_ratio);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftWidth = (totalWidth * _ratio) - (widget.dividerHitWidth / 2);
        final rightWidth =
            (totalWidth * (1.0 - _ratio)) - (widget.dividerHitWidth / 2);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth > 0 ? leftWidth : 0,
              child: widget.left,
            ),
            DraggableSplitDivider(
              width: widget.dividerHitWidth,
              onDragStart: () => AppHaptics.selection(),
              onDragUpdate: (details) => _onDragUpdate(details, totalWidth),
              onDragEnd: _onDragEnd,
            ),
            Expanded(
              child: SizedBox(
                width: rightWidth > 0 ? rightWidth : 0,
                child: widget.right,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The interactive, draggable vertical divider handle with mouse hover cursor
/// and visual grab pill.
class DraggableSplitDivider extends StatefulWidget {
  const DraggableSplitDivider({
    super.key,
    required this.width,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onDragStart,
  });

  final double width;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback? onDragStart;

  @override
  State<DraggableSplitDivider> createState() => _DraggableSplitDividerState();
}

class _DraggableSplitDividerState extends State<DraggableSplitDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _isHovered || _isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
          widget.onDragStart?.call();
        },
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (details) {
          setState(() => _isDragging = false);
          widget.onDragEnd(details);
        },
        child: SizedBox(
          width: widget.width,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hairline vertical divider
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: active
                    ? scheme.primary.withValues(alpha: 0.6)
                    : scheme.outlineVariant.withValues(alpha: 0.25),
              ),
              // Subtle centered grab pill handle
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: active ? 4.0 : 3.0,
                height: active ? 36.0 : 24.0,
                decoration: BoxDecoration(
                  color: active
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
