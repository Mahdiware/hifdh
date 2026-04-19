import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

class SelectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isSelected;
  final String? subtitle;

  const SelectionCard({
    super.key,
    required this.title,
    this.icon,
    this.onTap,
    this.trailing,
    this.isSelected = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final borderColor = isSelected
        ? colorScheme.primary.withValues(alpha: isDark ? 0.5 : 0.24)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.dividerLight);
    final iconContainerColor = isSelected
        ? colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12)
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.backgroundLight);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: LiquidGlass(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(18),
          blur: isSelected ? 16 : 12,
          tint: isSelected
              ? (isDark
                    ? const Color(0xFF2F4A6E).withValues(alpha: 0.44)
                    : const Color(0xFFE7F0FD).withValues(alpha: 0.78))
              : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.72)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? (isDark
                      ? [const Color(0xFF2E4F82), const Color(0xFF223D66)]
                      : [const Color(0xFFEFF5FF), const Color(0xFFE4EEFF)])
                : (isDark
                      ? [AppColors.surfaceDark, const Color(0xFF243855)]
                      : [Colors.white, const Color(0xFFF9FBFF)]),
          ),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? colorScheme.primary : Colors.black)
                  .withValues(alpha: isDark ? 0.24 : 0.08),
              blurRadius: isSelected ? 18 : 10,
              offset: const Offset(0, 6),
            ),
          ],
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconContainerColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 20,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.09)
                        : colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 13,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
