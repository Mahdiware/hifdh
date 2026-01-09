import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';

class ProgressHeaderCard extends StatelessWidget {
  final double memPercentage;
  final Map<String, int> overallStats;
  final bool isDark;

  const ProgressHeaderCard({
    super.key,
    required this.memPercentage,
    required this.overallStats,
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
                const Text(
                  "Hifdh Performance",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                      "Completed",
                      "$memCount",
                      Icons.check_circle,
                      AppColors.successGreen,
                    ),
                    _buildStatItem(
                      "Pending",
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
