import 'package:flutter/material.dart';

// COLOR PALETTE
class AyahColor {
  static const Color level0 = Color(0xFFFFFFFF);
  static const Color level1 = Color(0xFFFFB300);
  static const Color level2 = Color(0xFFFF5722);
  static const Color level3 = Color(0xFFD32F2F);

  // Helper: base color from mistake count
  static Color _baseColorFromMistakes(int mistakes) {
    switch (mistakes) {
      case 0:
        return level0;
      case 1:
        return level1;
      case 2:
        return level2;
      case 3:
        return level3;
      default:
        return level3;
    }
  }

  static Color getAyahHighlightColor(int mistakeCount, int correctStreak) {
    final baseColor = _baseColorFromMistakes(mistakeCount);

    if (mistakeCount == 0) {
      if (correctStreak >= 3) return level0;
      if (correctStreak >= 1) return Color.lerp(level0, level0, 0.3)!;
      return level0;
    }

    // If there are mistakes but also correct streaks
    if (correctStreak == 0) return baseColor;

    double blendFactor = (correctStreak / 3).clamp(0.0, 0.6);
    return Color.lerp(baseColor, level0, blendFactor)!;
  }

}
