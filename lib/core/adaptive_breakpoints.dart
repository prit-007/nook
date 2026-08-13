import 'package:flutter/widgets.dart';

/// Material 3 window-size breakpoints (from the Flutter adaptive-layout guide).
class AdaptiveBreakpoints {
  AdaptiveBreakpoints._();

  /// < 600dp: phones in portrait.
  static const double compact = 600;

  /// 600–839dp: foldables, phones in landscape, small tablets.
  static const double medium = 840;

  /// >= 840dp: large tablets, landscape foldables, desktop.
  static const double expanded = 840;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compact && width < medium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;

  /// Whether the current width is wide enough for a master-detail layout.
  static bool supportsDualPane(BuildContext context) => isExpanded(context);
}
