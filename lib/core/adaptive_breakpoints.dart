import 'package:flutter/widgets.dart';

/// Material 3 window-size breakpoints (from the Flutter adaptive-layout guide).
class AdaptiveBreakpoints {
  AdaptiveBreakpoints._();

  /// < 600dp: phones in portrait.
  static const double compact = 600;

  /// 600–839dp: foldables, phones in landscape, small tablets.
  ///
  /// In this band the wide shell (`_WideShell`) is used with the left
  /// `NavigationRail` and a **single content pane**. Dual-pane (rail + list +
  /// editor) only begins at `expanded` (>= 840dp).
  static const double medium = 840;

  /// >= 840dp: large tablets, landscape foldables, desktop.
  static const double expanded = 840;

  /// >= 1200dp: desktop monitors, widescreen tablets.
  static const double large = 1200;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compact && width < medium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;

  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= large;

  /// Whether the current width is wide enough for a master-detail layout.
  static bool supportsDualPane(BuildContext context) => isExpanded(context);

  /// Whether the screen is wide enough for a 3-pane desktop layout
  /// (Sidebar + Notes List + Note Preview/Editor).
  static bool supportsThreePane(BuildContext context) => isLarge(context);
}

/// Material 3 window size class based on width.
enum WindowSizeClass { compact, medium, expanded, large }
