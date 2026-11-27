import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_motion.dart';

/// Style variants of editorial page transitions.
enum EditorialTransitionType {
  /// Material 3 shared axis (horizontal or vertical) for hierarchical navigation.
  sharedAxis,

  /// Slide-up with secondary scale down for modal sheets, full-screen editors, and canvases.
  slideUp,

  /// Fade-through for top-level shell navigation and tab switches.
  fadeThrough,

  /// Container transform (zoom + vertical rise + fade) for card-to-editor transitions.
  containerTransform,
}

/// Unified, reusable page transition builders and [CustomTransitionPage] factories
/// using nook's [AppMotion] motion tokens and curves.
abstract class EditorialPageTransitions {
  // ── Default Durations ──────────────────────────────────────────
  static const Duration sharedAxisDuration = AppMotion.page;
  static const Duration sharedAxisReverseDuration = AppMotion.medium2;

  static const Duration slideUpDuration = AppMotion.modal;
  static const Duration slideUpReverseDuration = AppMotion.medium2;

  static const Duration fadeThroughDuration = AppMotion.standard;
  static const Duration fadeThroughReverseDuration = AppMotion.short4;

  static const Duration containerTransformDuration = AppMotion.page;
  static const Duration containerTransformReverseDuration = AppMotion.medium2;

  /// Returns the forward transition duration for [type].
  static Duration durationFor(EditorialTransitionType type) {
    switch (type) {
      case EditorialTransitionType.sharedAxis:
        return sharedAxisDuration;
      case EditorialTransitionType.slideUp:
        return slideUpDuration;
      case EditorialTransitionType.fadeThrough:
        return fadeThroughDuration;
      case EditorialTransitionType.containerTransform:
        return containerTransformDuration;
    }
  }

  /// Returns the reverse transition duration for [type].
  static Duration reverseDurationFor(EditorialTransitionType type) {
    switch (type) {
      case EditorialTransitionType.sharedAxis:
        return sharedAxisReverseDuration;
      case EditorialTransitionType.slideUp:
        return slideUpReverseDuration;
      case EditorialTransitionType.fadeThrough:
        return fadeThroughReverseDuration;
      case EditorialTransitionType.containerTransform:
        return containerTransformReverseDuration;
    }
  }

  // ── Transition Builders ────────────────────────────────────────

  /// Shared axis transition builder (horizontal or vertical).
  static Widget buildSharedAxis(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    Axis axis = Axis.horizontal,
  }) {
    final enterCurve = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    final exitCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    final beginOffset = axis == Axis.horizontal
        ? const Offset(0.08, 0.0)
        : const Offset(0.0, 0.08);

    return FadeTransition(
      opacity: enterCurve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(enterCurve),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(enterCurve),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.03).animate(exitCurve),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.85).animate(exitCurve),
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// Slide-up transition builder with secondary scale down.
  static Widget buildSlideUp(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enterCurve = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    final exitCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    return FadeTransition(
      opacity: enterCurve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.06),
          end: Offset.zero,
        ).animate(enterCurve),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.96).animate(exitCurve),
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }

  /// Fade-through transition builder for shell tab navigation.
  static Widget buildFadeThrough(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enterFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.2, 1.0, curve: AppMotion.standardDecelerate),
    );
    final scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasizedDecelerate,
      ),
    );
    final exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.35, curve: AppMotion.standardAccelerate),
      ),
    );

    return FadeTransition(
      opacity: enterFade,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: FadeTransition(
          opacity: exitFade,
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }

  /// Container transform transition builder for card-to-editor transitions.
  static Widget buildContainerTransform(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enterCurve = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    final exitCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    final enterFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.70, curve: AppMotion.standardDecelerate),
      reverseCurve: AppMotion.emphasizedAccelerate,
    );

    final enterScale = Tween<double>(begin: 0.90, end: 1.0).animate(enterCurve);
    final enterSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.04),
      end: Offset.zero,
    ).animate(enterCurve);

    final exitScale = Tween<double>(begin: 1.0, end: 0.95).animate(exitCurve);
    final exitFade = Tween<double>(begin: 1.0, end: 0.70).animate(exitCurve);

    return FadeTransition(
      opacity: enterFade,
      child: SlideTransition(
        position: enterSlide,
        child: ScaleTransition(
          scale: enterScale,
          child: ScaleTransition(
            scale: exitScale,
            child: FadeTransition(
              opacity: exitFade,
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ),
    );
  }

  // ── CustomTransitionPage Helpers for GoRouter ──────────────────

  /// Shared axis page transition for GoRouter.
  static CustomTransitionPage<T> sharedAxis<T>({
    required LocalKey key,
    required Widget child,
    Axis axis = Axis.horizontal,
    Duration duration = sharedAxisDuration,
    Duration reverseDuration = sharedAxisReverseDuration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return EditorialPageTransition.sharedAxis(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          axis: axis,
          child: child,
        );
      },
    );
  }

  /// Slide-up page transition for GoRouter.
  static CustomTransitionPage<T> slideUp<T>({
    required LocalKey key,
    required Widget child,
    Duration duration = slideUpDuration,
    Duration reverseDuration = slideUpReverseDuration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return EditorialPageTransition.slideUp(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }

  /// Fade-through page transition for GoRouter.
  static CustomTransitionPage<T> fadeThrough<T>({
    required LocalKey key,
    required Widget child,
    Duration duration = fadeThroughDuration,
    Duration reverseDuration = fadeThroughReverseDuration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return EditorialPageTransition.fadeThrough(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }

  /// Unified GoRouter page builder dispatching to [type].
  static CustomTransitionPage<T> buildPage<T>({
    required GoRouterState state,
    required Widget child,
    EditorialTransitionType type = EditorialTransitionType.slideUp,
    Axis axis = Axis.horizontal,
  }) {
    switch (type) {
      case EditorialTransitionType.sharedAxis:
        return sharedAxis<T>(key: state.pageKey, child: child, axis: axis);
      case EditorialTransitionType.slideUp:
        return slideUp<T>(key: state.pageKey, child: child);
      case EditorialTransitionType.fadeThrough:
        return fadeThrough<T>(key: state.pageKey, child: child);
      case EditorialTransitionType.containerTransform:
        return containerTransform<T>(key: state.pageKey, child: child);
    }
  }

  /// Container transform page transition for GoRouter.
  static CustomTransitionPage<T> containerTransform<T>({
    required LocalKey key,
    required Widget child,
    Duration duration = containerTransformDuration,
    Duration reverseDuration = containerTransformReverseDuration,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return EditorialPageTransition.containerTransform(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }
}

/// A widget that applies an editorial page transition to [child].
///
/// Respects [MediaQuery.disableAnimationsOf] to bypass motion when reduced motion is requested.
class EditorialPageTransition extends StatelessWidget {
  const EditorialPageTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    this.type = EditorialTransitionType.sharedAxis,
    this.axis = Axis.horizontal,
  });

  const EditorialPageTransition.sharedAxis({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    this.axis = Axis.horizontal,
  }) : type = EditorialTransitionType.sharedAxis;

  const EditorialPageTransition.slideUp({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  })  : type = EditorialTransitionType.slideUp,
        axis = Axis.vertical;

  const EditorialPageTransition.fadeThrough({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  })  : type = EditorialTransitionType.fadeThrough,
        axis = Axis.horizontal;

  const EditorialPageTransition.containerTransform({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  })  : type = EditorialTransitionType.containerTransform,
        axis = Axis.vertical;

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;
  final EditorialTransitionType type;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }

    switch (type) {
      case EditorialTransitionType.sharedAxis:
        return EditorialPageTransitions.buildSharedAxis(
          context,
          animation,
          secondaryAnimation,
          child,
          axis: axis,
        );
      case EditorialTransitionType.slideUp:
        return EditorialPageTransitions.buildSlideUp(
          context,
          animation,
          secondaryAnimation,
          child,
        );
      case EditorialTransitionType.fadeThrough:
        return EditorialPageTransitions.buildFadeThrough(
          context,
          animation,
          secondaryAnimation,
          child,
        );
      case EditorialTransitionType.containerTransform:
        return EditorialPageTransitions.buildContainerTransform(
          context,
          animation,
          secondaryAnimation,
          child,
        );
    }
  }
}

/// Lightweight editorial page route for imperative [Navigator.push] calls.
class EditorialPageRoute<T> extends PageRouteBuilder<T> {
  EditorialPageRoute({
    required WidgetBuilder builder,
    EditorialTransitionType transitionType = EditorialTransitionType.slideUp,
    Axis axis = Axis.horizontal,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: transitionDuration ??
              EditorialPageTransitions.durationFor(transitionType),
          reverseTransitionDuration: reverseTransitionDuration ??
              EditorialPageTransitions.reverseDurationFor(transitionType),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return EditorialPageTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              type: transitionType,
              axis: axis,
              child: child,
            );
          },
        );
}
