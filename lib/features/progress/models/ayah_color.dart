import 'package:flutter/material.dart';

// COLOR PALETTE
class AyahColor {
  static const Color level1 = Color(0xFFFFB300);
  static const Color level2 = Color(0xFFFF5722);
  static const Color level3 = Color(0xFFD32F2F);
  static const Color mastered = Color(0xFF2E9E56);
  static const Color masteredSoft = Color(0xFF53B86F);

  static Color getAyahHighlightColor(int mistakeCount, int correctStreak) {
    if (mistakeCount >= 3) return level3;
    if (mistakeCount == 2) return level2;
    if (mistakeCount == 1) return level1;
    if (correctStreak >= 3) return mastered;
    if (correctStreak >= 1) return masteredSoft;
    return Colors.transparent;
  }
}
