import 'package:flutter/material.dart';

class AppBackground {
  AppBackground._();

  static BoxDecoration pageDecoration(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 1.0],
        colors: isDark
            ? [
                const Color(0xFF0F1B33),
                const Color(0xFF1A2F55),
                const Color(0xFF0C1529),
              ]
            : [
                const Color(0xFFF7FAFF),
                const Color(0xFFE5EEFF),
                const Color(0xFFF4F8FF),
              ],
      ),
    );
  }
}
