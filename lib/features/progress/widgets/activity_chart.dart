import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class ActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  final int selectedStatRange;
  final Function(int) onRangeChanged;
  final bool isDark;

  static const List<int> chartRanges = [7, 30, 90, 180, 365];

  const ActivityChart({
    super.key,
    required this.chartData,
    required this.selectedStatRange,
    required this.onRangeChanged,
    required this.isDark,
  });

  Map<int, String> _getRangeLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return {
      7: l10n.days7,
      30: l10n.days30,
      90: l10n.months3,
      180: l10n.months6,
      365: l10n.year1,
    };
  }

  /// Safely gets a supported locale for the intl package
  String _getSafeLocale(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    // List of common locales usually supported by intl.
    // You can add more, but 'en' is the safest fallback.
    const supportedIntlLocales = ['en', 'ar', 'es', 'fr', 'de', 'it', 'tr'];

    if (supportedIntlLocales.contains(locale)) {
      return locale;
    }
    return 'en'; // Fallback to English for date formatting if 'so' is not supported
  }

  /// Safely formats the date range. If the input isn't a DateTime,
  /// it returns the fallback string provided.
  String _formatDateRange(
    BuildContext context,
    dynamic start,
    dynamic end,
    String fallback,
  ) {
    if (start is! DateTime) return fallback;

    // Use the safe locale instead of raw languageCode
    final locale = _getSafeLocale(context);

    try {
      final startFormat = DateFormat('MMM d', locale);

      if (end is! DateTime) {
        return startFormat.format(start);
      }

      if (start.month == end.month && start.year == end.year) {
        final endFormat = DateFormat('d', locale);
        return '${startFormat.format(start)}-${endFormat.format(end)}';
      } else {
        final endFormat = DateFormat('MMM d', locale);
        return '${startFormat.format(start)}-${endFormat.format(end)}';
      }
    } catch (e) {
      // Final emergency fallback if DateFormat still fails
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabels = _getRangeLabels(context);
    final primary = isDark ? const Color(0xFF8DB2FF) : AppColors.primaryNavy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.surfaceDark, const Color(0xFF243C60)]
              : [Colors.white, const Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.activity,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          // Range Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chartRanges.map((r) {
                final isSelected = selectedStatRange == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onRangeChanged(r),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? primary.withValues(alpha: 0.25)
                                  : AppColors.primaryNavy.withValues(
                                      alpha: 0.12,
                                    ))
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF2F6FF)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? primary.withValues(alpha: 0.35)
                              : (isDark
                                    ? Colors.white10
                                    : AppColors.dividerLight),
                        ),
                      ),
                      child: Text(
                        rangeLabels[r]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.primaryNavy)
                              : (isDark ? Colors.grey : Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          if (chartData.every((d) => (d['count'] ?? 0) == 0))
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  AppLocalizations.of(context)!.noActivityPeriod,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 180, // Increased height for rotated labels
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartData.map((d) {
                  final count = (d['count'] as num?)?.toInt() ?? 0;

                  // Use the helper to get the label safely
                  final dateLabel = _formatDateRange(
                    context,
                    d['startDate'],
                    d['endDate'],
                    d['day']?.toString() ??
                        '', // Fallback to the old 'day' string
                  );

                  int maxCount = 1;
                  try {
                    maxCount = chartData
                        .map((e) => (e['count'] as num?)?.toInt() ?? 0)
                        .reduce((a, b) => a > b ? a : b);
                    if (maxCount == 0) maxCount = 1;
                  } catch (_) {
                    maxCount = 1;
                  }

                  final normalizedHeight = (count / maxCount) * 80;
                  final barWidth = chartData.length > 15 ? 8.0 : 14.0;
                  final bool rotateLabels = chartData.length > 7;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey : primary,
                            ),
                          ),
                        ),
                      Container(
                        width: barWidth,
                        height: 80,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF0F4FB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: count > 0
                            ? Container(
                                width: barWidth,
                                height: normalizedHeight.clamp(barWidth, 80.0),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      primary,
                                      primary.withValues(alpha: 0.72),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: rotateLabels
                            ? 60
                            : 20, // Give space for rotated text
                        child: rotateLabels
                            ? RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey
                                        : Colors.grey[600],
                                  ),
                                ),
                              )
                            : Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey
                                      : Colors.grey[600],
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
