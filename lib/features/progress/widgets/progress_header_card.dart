import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hifdh/core/services/export_statistics.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

class ProgressHeaderCard extends StatelessWidget {
  final Map<String, int> memPercentage;
  final Map<String, int> overallStats;
  final int selectedMetric;
  final Function(int) onMetricChanged;
  final bool isDark;

  const ProgressHeaderCard({
    super.key,
    required this.memPercentage,
    required this.overallStats,
    required this.selectedMetric,
    required this.onMetricChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final memCount = overallStats['completed'] ?? 0;
    final pendingCount = overallStats['pending'] ?? 0;

    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF263F65), Color(0xFF172A45)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFEFF5FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.textSecondaryLight;
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.primaryNavy.withValues(alpha: 0.1);
    final cardShadow = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.grey.withValues(alpha: 0.2);

    return LiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(32),
      blur: 20,
      gradient: gradient,
      tint: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.6),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.primaryNavy.withValues(alpha: 0.12),
      ),
      boxShadow: [
        BoxShadow(
          color: cardShadow,
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
      child: Stack(
        children: [
          // Decorative background circle for visual interest
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.primaryNavy.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Top Row: Title + Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            color: textColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.progress,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        _buildMetricSelector(context, textColor),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: "Export as PDF", // Shows on hover/long press
                          child: LiquidGlass(
                            padding: const EdgeInsets.all(2),
                            borderRadius: BorderRadius.circular(12),
                            blur: 10,
                            tint: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.7),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : AppColors.primaryNavy.withValues(
                                      alpha: 0.12,
                                    ),
                            ),
                            boxShadow: const [],
                            child: ElevatedButton(
                              onPressed: () async {
                                final data = await PlannerDatabase()
                                    .buildDynamicJuzRows();
                                await exportJuzRevisionPdf(
                                  data['rows'],
                                  maxRevisions: data['maxRevisions'],
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(12),
                                backgroundColor: isDark
                                    ? const Color(0xFF5A7EA8)
                                    : const Color(0xFF58779A),
                                elevation: 0,
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Middle Section: Large Circle + Stats
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildAnimatedCircularProgress(context, textColor),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatRow(
                            context,
                            AppLocalizations.of(context)!.completed,
                            "$memCount",
                            const Color(0xFF4CAF50), // Bright Green
                            Icons.check_circle_outline_rounded,
                            textColor,
                            subTextColor,
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow(
                            context,
                            AppLocalizations.of(context)!.pending,
                            "$pendingCount",
                            const Color(0xFFFFB74D), // Soft Orange
                            Icons.timer_outlined,
                            textColor,
                            subTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSelector(BuildContext context, Color textColor) {
    final menuColor = Theme.of(context).popupMenuTheme.color;

    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      borderRadius: BorderRadius.circular(20),
      blur: 8,
      tint: isDark
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.82),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : AppColors.primaryNavy.withValues(alpha: 0.2),
        width: 1,
      ),
      boxShadow: const [],
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMetric,
          isDense: true,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: menuColor,
          icon: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: textColor.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: [
            DropdownMenuItem(
              value: 2,
              child: Text(AppLocalizations.of(context)!.page),
            ),
            DropdownMenuItem(
              value: 3,
              child: Text(AppLocalizations.of(context)!.surah),
            ),
            DropdownMenuItem(
              value: 1,
              child: Text(AppLocalizations.of(context)!.ayah),
            ),
          ],
          onChanged: (val) {
            if (val != null) onMetricChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedCircularProgress(BuildContext context, Color textColor) {
    final int memorized = (memPercentage['memorized'] ?? 0);
    final int total = (memPercentage['total'] ?? 0);
    final double percentage = total > 0 ? (memorized / total) : 0.0;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: percentage),
            builder: (context, value, child) {
              return CustomPaint(
                painter: _ModernProgressPainter(
                  percentage: value,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  color: isDark
                      ? const Color(0xFF8DB2FF)
                      : AppColors.primaryNavy,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${(value * 100).toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.done,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          " ${memPercentage['memorized']} / ${memPercentage['total']}",
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.72)
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : AppColors.primaryNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: subTextColor, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernProgressPainter extends CustomPainter {
  final double percentage;
  final Color backgroundColor;
  final Color color;

  _ModernProgressPainter({
    required this.percentage,
    required this.backgroundColor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // Background Arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Foreground Arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Add a glowing effect shadow
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final sweepAngle = 2 * math.pi * percentage;
    // Start from top (-pi/2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      shadowPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ModernProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
