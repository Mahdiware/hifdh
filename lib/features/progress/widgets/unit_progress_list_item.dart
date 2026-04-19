import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

class UnitProgressListItem extends StatelessWidget {
  final int number;
  final String title;
  final String? subtitle;
  final double progress;
  final bool isCompleted;
  final int activeTaskCount;
  final int revisionCount;
  final VoidCallback onTap;

  const UnitProgressListItem({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    required this.progress,
    required this.isCompleted,
    this.activeTaskCount = 0,
    this.revisionCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final isFull = isCompleted || progress >= 0.999;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(18),
        blur: 16,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.surfaceDark, const Color(0xFF243B5E)]
              : [const Color(0xFFF4F8FF), const Color(0xFFE8F1FF)],
        ),
        tint: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.58),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.primaryNavy.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: _buildLeadingIndicator(isDark, isFull),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: _buildSubtitle(context, isDark, l10n),
              trailing: _buildTrailing(isDark, l10n),
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIndicator(bool isDark, bool isFull) {
    if (isFull) {
      return Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.successGreen, AppColors.successGreenDark],
          ),
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 20),
      );
    } else {
      return SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (progress > 0.0)
              CircularProgressIndicator(
                value: progress,
                backgroundColor: isDark
                    ? Colors.white10
                    : Colors.grey.withValues(alpha: 0.1),
                color: isDark ? const Color(0xFF8EB3FF) : AppColors.primaryNavy,
                strokeWidth: 3,
              )
            else
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                ),
              ),
            Text(
              progress > 0.0 ? "${(progress * 100).toInt()}%" : "$number",
              style: TextStyle(
                fontSize: progress > 0.0 ? 11 : 14,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? (progress > 0.0
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryDark)
                    : (progress > 0.0
                          ? AppColors.primaryNavy
                          : const Color(0xFF3F5876)),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSubtitle(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final List<Widget> rowChildren = [];

    // 1. Active Tasks Indicator
    if (activeTaskCount > 0) {
      rowChildren.add(
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.accentOrange,
            shape: BoxShape.circle,
          ),
        ),
      );
      rowChildren.add(const SizedBox(width: 6));
      rowChildren.add(
        Text(
          "$activeTaskCount ${l10n.inProgress}",
          style: const TextStyle(fontSize: 12, color: AppColors.accentOrange),
        ),
      );
      rowChildren.add(const SizedBox(width: 8));
    }

    // 2. Custom Subtitle or Default Percent
    if (subtitle != null) {
      if (activeTaskCount > 0 &&
          (title.startsWith("Surah") ||
              subtitle!.contains(RegExp(r'[\u0600-\u06FF]')))) {
        // Optimization: For Surahs, usually we hide Arabic name if active tasks exist
        // to avoid clutter, based on original "hasActive ? ... : Name" logic.
        // But if subtitle is explicitly provided and we have active tasks, we might want to show both?
        // Let's mimic original Surah behavior: If active, don't show custom subtitle (Arabic name).
        // BUT for Juz/Hizb, we DO want to show the custom subtitle (which might be "XX% memorized").

        // Actually, simpler logic:
        // The calling code for Surah passed `arabicName` as subtitle.
        // The calling code for Juz passed NOTHING (null) as subtitle, it relied on calculated percent.
        // So if subtitle is provided, we should probably show it.
        // Let's rely on the caller to decide.
        // If caller wants "Active OR Subtitle", they pass subtitle=null when active.
        // If caller wants "Active AND Subtitle", they pass subtitle always.
      }

      rowChildren.add(
        Flexible(
          // Wrap in Flexible for overflow safety
          child: Text(
            subtitle!,
            style: TextStyle(
              fontFamily: "QuranFont", // Only applies if it's arabic really
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF4B6280),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else {
      // Default: Show Memory Percentage
      rowChildren.add(
        Text(
          l10n.percentMemorized((progress * 100).toInt()),
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondaryDark
                : const Color(0xFF4B6280),
          ),
        ),
      );
    }

    if (rowChildren.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: rowChildren),
    );
  }

  Widget _buildTrailing(bool isDark, AppLocalizations l10n) {
    if (revisionCount > 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$revisionCount ${l10n.revisionsShort}",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.accentOrange,
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.primaryNavy.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white70 : AppColors.primaryNavy,
      ),
    );
  }
}
