import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';

class AppTheme {
  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Core Colors
    primaryColor: AppColors.primaryNavy,
    scaffoldBackgroundColor: AppColors.backgroundLight,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryNavy,
      secondary: AppColors.accentOrange,
      surface: AppColors.surfaceLight,
      error: AppColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryLight,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Inputs (TextFields)
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.dividerLight.withValues(alpha: 0.75),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.dividerLight.withValues(alpha: 0.75),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primaryNavy.withValues(alpha: 0.85),
          width: 1.4,
        ),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
      hintStyle: const TextStyle(color: AppColors.textSecondaryLight),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xEEF2F7FF),
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: const Color(0xFF3A68A9),
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      todayForegroundColor: const WidgetStatePropertyAll(
        AppColors.accentOrange,
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: const Color(0xEEF2F7FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      dialHandColor: AppColors.primaryNavy,
      dialBackgroundColor: const Color(0xFFDCE9FF),
      hourMinuteColor: const Color(0xFFDCE9FF),
      hourMinuteTextColor: AppColors.textPrimaryLight,
      dayPeriodColor: const Color(0xFFDFE9FA),
      dayPeriodTextColor: AppColors.primaryNavy,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xCCF1F7FF),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primaryNavy.withValues(alpha: 0.2)),
      ),
      textStyle: const TextStyle(
        color: AppColors.textPrimaryLight,
        fontWeight: FontWeight.w600,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xCCF1F7FF)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.primaryNavy.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xCCF1F7FF)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.primaryNavy.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),

    // Cards
    cardTheme: const CardThemeData(
      elevation: 2,
      color: AppColors.surfaceLight,
      shadowColor: Colors.black12,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 1,
    ),

    // Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.primaryNavy,
      unselectedItemColor: AppColors.textSecondaryLight,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Text
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimaryLight),
      bodyMedium: TextStyle(color: AppColors.textPrimaryLight),
      titleLarge: TextStyle(
        color: AppColors.textPrimaryLight,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Core Colors
    primaryColor: AppColors.primaryNavy,
    scaffoldBackgroundColor: AppColors.backgroundDark,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryNavy,
      secondary: AppColors.accentOrange,
      surface: AppColors.surfaceDark,
      error: AppColors.errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryDark,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Inputs (TextFields)
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.dividerDark.withValues(alpha: 0.75),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.dividerDark.withValues(alpha: 0.75),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.accentOrange.withValues(alpha: 0.9),
          width: 1.4,
        ),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
      hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: const Color(0xEE1E3557),
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: const Color(0xFF325F9E),
      headerForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      todayForegroundColor: const WidgetStatePropertyAll(
        AppColors.accentOrange,
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: const Color(0xEE1E3557),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      dialHandColor: AppColors.accentOrange,
      dialBackgroundColor: const Color(0xFF1B2D4A),
      hourMinuteColor: const Color(0xFF273E62),
      hourMinuteTextColor: Colors.white,
      dayPeriodColor: const Color(0xFF233754),
      dayPeriodTextColor: Colors.white,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xB3223D64),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xB3223D64)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          ),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xB3223D64)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accentOrange),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryNavy, // Or Orange for contrast?
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),

    // Cards
    cardTheme: const CardThemeData(
      elevation: 2,
      color: AppColors.surfaceDark,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.dividerDark,
      thickness: 1,
    ),

    // Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.accentOrange,
      unselectedItemColor: AppColors.textSecondaryDark,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Text
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimaryDark),
      bodyMedium: TextStyle(color: AppColors.textPrimaryDark),
      titleLarge: TextStyle(
        color: AppColors.textPrimaryDark,
        fontWeight: FontWeight.bold,
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
