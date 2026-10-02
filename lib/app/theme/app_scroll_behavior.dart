import 'package:flutter/material.dart';

/// Keep scrolling and pull-to-refresh, without stretching Android content at
/// the viewport edges. Other platforms retain their default behavior.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (getPlatform(context) == TargetPlatform.android) return child;
    return super.buildOverscrollIndicator(context, child, details);
  }
}
