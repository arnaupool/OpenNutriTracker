import 'package:flutter/material.dart';

/// Breakpoints for the desktop web layout (FAS-02). Below [wide] the app
/// keeps its phone layout unchanged.
class ResponsiveLayout {
  /// From here the bottom navigation becomes a side rail and Home / Diary
  /// split into columns.
  static const double wide = 1000;

  /// From here the side rail shows its labels.
  static const double extendedRail = 1280;

  /// Widest a single column of content gets; on very wide screens the
  /// rest becomes margin rather than over-stretched cards.
  static const double maxContentWidth = 1440;

  /// Widest a form or detail screen gets.
  static const double maxFormWidth = 720;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wide;
}

/// Centers [child] and caps its width, for screens that read better at a
/// form-like width on a desktop monitor. A no-op on phones.
class MaxWidthBox extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const MaxWidthBox({super.key, this.maxWidth = ResponsiveLayout.maxFormWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Frames a pushed screen (forms, detail views, settings) on a desktop
/// monitor: the screen keeps its own Scaffold but at a readable width,
/// centered on the window background. A no-op on phones.
class DesktopRouteFrame extends StatelessWidget {
  static const double maxRouteWidth = 900;

  final Widget child;

  const DesktopRouteFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveLayout.isWide(context)) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxRouteWidth),
          child: child,
        ),
      ),
    );
  }
}
