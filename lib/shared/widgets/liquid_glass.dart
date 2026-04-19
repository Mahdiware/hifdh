import 'dart:ui';

import 'package:flutter/foundation.dart';
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

  Color _normalizeLightColor(Color color) {
    final normalizedAlpha = _clampAlpha(_alphaOf(color), 0.08, 0.52);
    final softened = color.withValues(alpha: normalizedAlpha);
    final coolCast = const Color(0xFFCFE2FF).withValues(alpha: 0.14);
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

  Gradient _normalizeGradientForLight(Gradient source) {
    if (source is LinearGradient) {
      return LinearGradient(
        begin: source.begin,
        end: source.end,
        colors: source.colors.map(_normalizeLightColor).toList(),
        stops: source.stops,
        tileMode: source.tileMode,
        transform: source.transform,
      );
    }

    if (source is RadialGradient) {
      return RadialGradient(
        center: source.center,
        radius: source.radius,
        colors: source.colors.map(_normalizeLightColor).toList(),
        stops: source.stops,
        tileMode: source.tileMode,
        focal: source.focal,
        focalRadius: source.focalRadius,
        transform: source.transform,
      );
    }

    if (source is SweepGradient) {
      return SweepGradient(
        center: source.center,
        startAngle: source.startAngle,
        endAngle: source.endAngle,
        colors: source.colors.map(_normalizeLightColor).toList(),
        stops: source.stops,
        tileMode: source.tileMode,
        transform: source.transform,
      );
    }

    return source;
  }

  bool _shouldUseReducedEffects(BuildContext context) {
    if (!adaptivePerformance) return false;

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;

    final smallPhone = mediaQuery.size.shortestSide <= 430;
    final lowerDensity = mediaQuery.devicePixelRatio <= 2.75;
    final reduceMotion = mediaQuery.disableAnimations;
    final androidPhone =
        defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

    return androidPhone && (smallPhone && lowerDensity || reduceMotion);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reducedEffects = _shouldUseReducedEffects(context);

    final effectiveBlur = reducedEffects ? (blur * 0.45).clamp(0.0, 8.0) : blur;

    final baseTint =
        tint ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0x99E2EEFF));

    final resolvedTint = isDark ? baseTint : _normalizeLightTint(baseTint);

    final baseBorder =
        border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0x6B5E84BA),
          width: 1,
        );

    final resolvedBorder = isDark
        ? baseBorder
        : _normalizeLightBorder(baseBorder);

    final baseShadow = reducedEffects
        ? const <BoxShadow>[]
        : (boxShadow ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]);

    final resolvedShadow = isDark
        ? baseShadow
        : _normalizeLightShadows(baseShadow);

    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [resolvedTint, resolvedTint.withValues(alpha: 0.04)]
          : [
              resolvedTint.withValues(alpha: 0.44),
              const Color(0x99FFFFFF),
              const Color(0x80D8EAFF),
            ],
      stops: isDark ? null : const [0.0, 0.45, 1.0],
    );

    final resolvedGradient = gradient == null
        ? defaultGradient
        : (isDark ? gradient! : _normalizeGradientForLight(gradient!));

    final surfaceColor = isDark
        ? resolvedTint
        : resolvedTint.withValues(
            alpha: _clampAlpha(_alphaOf(resolvedTint) * 0.42, 0.08, 0.28),
          );

    final content = reducedEffects
        ? Padding(padding: padding, child: child)
        : Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.08 : 0.22),
                          Colors.white.withValues(alpha: 0),
                          (isDark ? Colors.black : const Color(0xFFADC9F6))
                              .withValues(alpha: isDark ? 0.06 : 0.12),
                        ],
                        stops: const [0, 0.42, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -30,
                right: -20,
                child: IgnorePointer(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.24 : 0.42),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          );

    Widget surface = Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        gradient: resolvedGradient,
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
