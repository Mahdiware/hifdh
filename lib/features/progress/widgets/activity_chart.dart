import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';

class ActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  final int selectedStatRange;
  final Function(int) onRangeChanged;
  final bool isDark;

  static const List<int> chartRanges = [7, 30, 90, 180, 365];
  static const Map<int, String> chartRangeLabels = {
    7: "7 Days",
    30: "30 Days",
    90: "3 Months",
    180: "6 Months",
    365: "1 Year",
  };

  const ActivityChart({
    super.key,
    required this.chartData,
    required this.selectedStatRange,
    required this.onRangeChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
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
            "Activity",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          // Range Selector Checkbox/Chips
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
                                  ? AppColors.accentOrange
                                  : AppColors.primaryNavy)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        chartRangeLabels[r]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
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
          if (chartData.every((d) => d['count'] == 0))
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  "No activity in this period",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartData.map((d) {
                  final count = d['count'] as int;
                  // Max Scaling
                  // Calculate max here or pass it? calculating here is fine for small list
                  int max = 0;
                  try {
                    max = chartData
                        .map((e) => e['count'] as int)
                        .reduce((a, b) => a > b ? a : b);
                  } catch (e) {
                    max = 1;
                  }

                  final scaleMax = max > 0 ? max : 1;
                  final normalizedHeight =
                      (count / scaleMax) * 80; // Max bar 80px

                  // Colors
                  final barColor = isDark
                      ? AppColors.accentOrange
                      : AppColors.primaryNavy;
                  final emptyColor = isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100];

                  final barWidth = chartData.length > 15 ? 8.0 : 14.0;
                  final bool rotateLabels = chartData.length > 8;

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
                              color: isDark
                                  ? Colors.grey
                                  : AppColors.primaryNavy,
                            ),
                          ),
                        ),
                      Container(
                        width: barWidth,
                        height: 80,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: emptyColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: count > 0
                            ? Container(
                                width: barWidth,
                                height: normalizedHeight > barWidth
                                    ? normalizedHeight.toDouble()
                                    : barWidth,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: isDark
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            AppColors.primaryNavy,
                                            AppColors.primaryNavy.withValues(alpha: 
                                              0.8,
                                            ),
                                          ],
                                        ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      // Label
                      if (rotateLabels)
                        RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            d['day'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey : Colors.grey[600],
                            ),
                          ),
                        )
                      else
                        Text(
                          d['day'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey : Colors.grey[600],
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
