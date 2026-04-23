import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';

class AppBackground {
  AppBackground._();

  static BoxDecoration pageDecoration(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
    );
  }
}
