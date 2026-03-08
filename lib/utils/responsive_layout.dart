import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppResponsive {
  static const Size designSize = Size(393, 852);
  static const double tabletBreakpoint = 600.0;
  static const double tabletMaxWidth = 520.0;

  const AppResponsive._({
    required this.mediaQuery,
    required this.scaleFactor,
  });

  final MediaQueryData mediaQuery;
  final double scaleFactor;

  static AppResponsive of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final widthScale = mediaQuery.size.width / designSize.width;
    final scaleFactor = widthScale.clamp(0.92, 1.16).toDouble();

    return AppResponsive._(
      mediaQuery: mediaQuery,
      scaleFactor: scaleFactor,
    );
  }

  static MediaQueryData normalizedMediaQuery(
    MediaQueryData data, {
    double minTextScale = 0.95,
    double maxTextScale = 1.10,
  }) {
    final currentTextScale = data.textScaler.scale(16) / 16;
    final clampedTextScale =
        currentTextScale.clamp(minTextScale, maxTextScale).toDouble();

    return data.copyWith(
      textScaler: TextScaler.linear(clampedTextScale),
    );
  }

  Size get size => mediaQuery.size;

  double get width => size.width;
  double get height => size.height;

  bool get isTabletWidth => width >= tabletBreakpoint;

  double get constrainedPageWidth =>
      isTabletWidth ? math.min(width, tabletMaxWidth) : width;

  bool get isCompactWidth => width < 375;

  bool get isCompactHeight => height < 780;

  double space(
    double base, {
    double minScale = 0.90,
    double maxScale = 1.16,
  }) {
    return _scaled(base, minScale: minScale, maxScale: maxScale);
  }

  double font(
    double base, {
    double minScale = 0.94,
    double maxScale = 1.14,
  }) {
    return _scaled(base, minScale: minScale, maxScale: maxScale);
  }

  double icon(
    double base, {
    double minScale = 0.92,
    double maxScale = 1.16,
  }) {
    return _scaled(base, minScale: minScale, maxScale: maxScale);
  }

  double radius(
    double base, {
    double minScale = 0.95,
    double maxScale = 1.16,
  }) {
    return _scaled(base, minScale: minScale, maxScale: maxScale);
  }

  double border(
    double base, {
    double minScale = 0.90,
    double maxScale = 1.05,
  }) {
    return _scaled(base, minScale: minScale, maxScale: maxScale);
  }

  double _scaled(
    double base, {
    required double minScale,
    required double maxScale,
  }) {
    return (base * scaleFactor)
        .clamp(base * minScale, base * maxScale)
        .toDouble();
  }
}

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = AppResponsive.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.constrainedPageWidth),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
