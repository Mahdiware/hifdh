import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double blur;
  final Color? tint;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final bool adaptivePerformance;

  const LiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.blur = 18,
    this.tint,
    this.border,
    this.boxShadow,
    this.gradient,
    this.adaptivePerformance = true,
  });

  double _alphaOf(Color color) => color.a;

  double _clampAlpha(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  Color _normalizeLightTint(Color color) {
    final normalizedAlpha = _clampAlpha(_alphaOf(color), 0.14, 0.44);
    final softened = color.withValues(alpha: normalizedAlpha);
    final coolCast = const Color(0xFFD7E9FF).withValues(alpha: 0.2);
    return Color.alphaBlend(coolCast, softened);
  }

  Border _normalizeLightBorder(Border input) {
    BorderSide normalize(BorderSide side) {
      if (side.style == BorderStyle.none) return side;
      final normalizedAlpha = _clampAlpha(_alphaOf(side.color), 0.08, 0.32);
      final softened = side.color.withValues(alpha: normalizedAlpha);
      final coolCast = const Color(0xFF4D73AB).withValues(alpha: 0.18);
      return side.copyWith(color: Color.alphaBlend(coolCast, softened));
    }

    return Border(
      top: normalize(input.top),
      right: normalize(input.right),
      bottom: normalize(input.bottom),
      left: normalize(input.left),
    );
  }

  List<BoxShadow> _normalizeLightShadows(List<BoxShadow> input) {
    return input.map((shadow) {
      final normalizedAlpha = _clampAlpha(_alphaOf(shadow.color), 0.02, 0.14);
      final softened = shadow.color.withValues(alpha: normalizedAlpha);
      final coolCast = const Color(0xFF3A5F93).withValues(alpha: 0.1);
      return shadow.copyWith(color: Color.alphaBlend(coolCast, softened));
    }).toList();
  }

  bool _isInPopupRoute(BuildContext context) {
    return ModalRoute.of(context) is PopupRoute;
  }

  bool _shouldPreserveSemanticTint(Color input) {
    final alpha = _alphaOf(input);
    if (alpha < 0.2) return false;

    final hsl = HSLColor.fromColor(input);
    return hsl.saturation >= 0.2;
  }

  Color _resolveSemanticTint(Color input, bool isDark, bool inPopupRoute) {
    final minAlpha = inPopupRoute
        ? (isDark ? 0.84 : 0.9)
        : (isDark ? 0.58 : 0.52);
    final maxAlpha = inPopupRoute ? 1.0 : (isDark ? 0.88 : 0.82);

    return input.withValues(
      alpha: _clampAlpha(_alphaOf(input), minAlpha, maxAlpha),
    );
  }

  Color _resolveSurfaceTint(Color input, bool isDark, bool inPopupRoute) {
    if (_shouldPreserveSemanticTint(input)) {
      return _resolveSemanticTint(input, isDark, inPopupRoute);
    }

    if (inPopupRoute) {
      return isDark ? const Color(0xFF2B3E5A) : Colors.white;
    }

    if (isDark) {
      final base = const Color(0xFF27364C);
      final softened = input.withValues(
        alpha: _clampAlpha(_alphaOf(input), 0.06, 0.24),
      );
      return Color.alphaBlend(softened, base);
    }

    final base = const Color(0xFFF2F6FC);
    final softened = _normalizeLightTint(
      input,
    ).withValues(alpha: _clampAlpha(_alphaOf(input), 0.08, 0.22));
    return Color.alphaBlend(softened, base);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reducedEffects = adaptivePerformance;
    final inPopupRoute = _isInPopupRoute(context);

    final effectiveBlur = reducedEffects ? 0.0 : blur;

    final baseTint =
        tint ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : const Color(0xFFDCE9FA).withValues(alpha: 0.16));

    final effectiveTint = _resolveSurfaceTint(baseTint, isDark, inPopupRoute);

    final baseBorder =
        border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.24)
              : const Color(0xFFB7C5D6),
          width: 1,
        );

    final resolvedBorder = isDark
        ? baseBorder
        : _normalizeLightBorder(baseBorder);

    final baseShadow = reducedEffects || inPopupRoute
        ? const <BoxShadow>[]
        : (boxShadow ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]);

    final resolvedShadow = isDark
        ? baseShadow
        : _normalizeLightShadows(baseShadow);

    final surfaceColor = effectiveTint;

    final content = Padding(padding: padding, child: child);

    Widget surface = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        gradient: null,
        border: resolvedBorder,
        borderRadius: borderRadius,
        boxShadow: resolvedShadow,
      ),
      child: content,
    );

    if (effectiveBlur > 0.1) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: surface,
      );
    }

    return RepaintBoundary(
      child: ClipRRect(borderRadius: borderRadius, child: surface),
    );
  }
}
