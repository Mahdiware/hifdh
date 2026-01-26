import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

class ProgressHeaderCard extends StatelessWidget {
  final double memPercentage;
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

    // Premium Gradients or Solid Colors
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF2E2F49), Color(0xFF181824)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Colors.white, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.1);
    final cardShadow = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.grey.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
                    : Colors.blue.withValues(alpha: 0.05),
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
                    _buildMetricSelector(context, textColor),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMetric,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF2C2E42) : Colors.white,
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
            fontFamily: 'Roboto', // Or system default
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
    return AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: memPercentage / 100),
        builder: (context, value, child) {
          return CustomPaint(
            painter: _ModernProgressPainter(
              percentage: value,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              color: const Color(0xFF69F0AE), // Accent Green
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
            : Colors.grey.withValues(alpha: 0.05),
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
