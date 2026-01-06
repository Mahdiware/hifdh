import 'package:flutter/material.dart';

class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ===========================================================================
  // Core Brand Palette
  // ===========================================================================
  static const Color primaryNavy = Color(0xFF23253A);
  static const Color accentOrange = Color(0xFFE67E22);
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color successGreenDark = Color(0xFF27AE60);
  static const Color errorRed = Color(0xFFE74C3C);

  // ===========================================================================
  // Background Colors
  // ===========================================================================
  static const Color backgroundLight = Color(0xFFF8F9FB);
  static const Color backgroundDark = Color(0xFF1A1C29);

  // ===========================================================================
  // Surface / Card Colors
  // ===========================================================================
  static const Color surfaceLight = Colors.white;
  // A slightly lighter navy for cards in dark mode
  static const Color surfaceDark = Color(0xFF2C2E42);

  // ===========================================================================
  // Text Colors
  // ===========================================================================
  static const Color textPrimaryLight = Color(0xFF23253A);
  static const Color textSecondaryLight = Color(0xFF7F8C8D);

  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFBDC3C7);

  // ===========================================================================
  // UI Elements
  // ===========================================================================
  static const Color dividerLight = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF404040);
}
