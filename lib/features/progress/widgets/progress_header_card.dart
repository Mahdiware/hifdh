import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.surfaceDark, Colors.black]
              : [AppColors.primaryNavy, AppColors.surfaceDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Diagram
          SizedBox(
            height: 100,
            width: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: memPercentage / 100,
                  strokeWidth: 8,
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.successGreen,
                  ),
                  backgroundColor: Colors.white10,
                ),
                Center(
                  child: Text(
                    "${memPercentage.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Stats Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.progress,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: DropdownButton<int>(
                        value: selectedMetric,
                        underline: const SizedBox(),
                        dropdownColor: AppColors.primaryNavy,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 16,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      AppLocalizations.of(context)!.completed,
                      "$memCount",
                      Icons.check_circle,
                      AppColors.successGreen,
                    ),
                    _buildStatItem(
                      AppLocalizations.of(context)!.pending,
                      "$pendingCount",
                      Icons.timelapse,
                      AppColors.accentOrange,
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

  Widget _buildStatItem(String label, String val, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
