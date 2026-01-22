import 'package:flutter/material.dart';

// COLOR PALETTE
class AyahColor {
  static const Color correctLight = Color(0xFFE0F7FA);
  static const Color correctStrong = Color(0xFFFFFFFF);

  static const Color level0 = Color(0xFF26C6DA);
  static const Color level1 = Color(0xFFFFFDE7);
  static const Color level2 = Color(0xFFFFF9C4);
  static const Color level3 = Color(0xFFFFB300);
  static const Color level4 = Color(0xFFFF5722);
  static const Color level5 = Color(0xFFD32F2F);

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
      case 4:
        return level4;
      default:
        return level5;
    }
  }

  static Color getAyahHighlightColor(int mistakeCount, int correctStreak) {
    final baseColor = _baseColorFromMistakes(mistakeCount);

    // No mistakes → show positive
    if (mistakeCount == 0) {
      if (correctStreak >= 3) return AyahColor.correctStrong;
      if (correctStreak >= 1) return AyahColor.correctLight;
      return AyahColor.level0;
    }

    // If there are mistakes but also correct streaks
    if (correctStreak == 0) return baseColor;

    // Blend more naturally
    double blendFactor = (correctStreak / 4).clamp(0.0, 0.6);

    // If low mistakes, lean green more
    final targetColor = mistakeCount <= 2
        ? AyahColor.correctStrong
        : AyahColor.correctLight;

    return Color.lerp(baseColor, targetColor, blendFactor)!;
  }

  static Color getaAyahHighlightColor(int mistakeCount, int correctStreak) {
    final baseColor = _baseColorFromMistakes(mistakeCount);

    if (mistakeCount == 0) {
      if (correctStreak >= 3) return correctStrong;
      if (correctStreak >= 1) return correctLight;
      return level0;
    }

    if (correctStreak == 0) return baseColor;

    // If there is 1 correct
    if (correctStreak == 1) return Color.lerp(baseColor, correctLight, 0.2)!;

    // If there are 2 correct
    if (correctStreak == 2) return Color.lerp(baseColor, correctLight, 0.4)!;

    // If 3+ correct
    if (mistakeCount <= 2) return Color.lerp(baseColor, correctStrong, 0.6)!;

    // If mistakes are high (3+)
    return Color.lerp(baseColor, correctLight, 0.5)!;
  }
}
