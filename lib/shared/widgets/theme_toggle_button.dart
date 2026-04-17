import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hifdh/features/settings/logic/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark =
        themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final iconColor = isDark ? const Color(0xFFFFE082) : colorScheme.primary;
    final backgroundColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : colorScheme.primary.withValues(alpha: 0.10);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : colorScheme.primary.withValues(alpha: 0.22);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: IconButton(
        tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        splashRadius: 20,
        icon: Icon(
          isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
          color: iconColor,
        ),
        onPressed: () {
          themeProvider.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
        },
      ),
    );
  }
}
