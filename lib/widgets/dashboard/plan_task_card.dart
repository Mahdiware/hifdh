import 'package:flutter/material.dart';
import '../../models/plan_task.dart';
import '../../theme/app_colors.dart';

class PlanTaskCard extends StatelessWidget {
  final PlanTask task;
  final VoidCallback onAction;
  final VoidCallback onNote;

  const PlanTaskCard({
    super.key,
    required this.task,
    required this.onAction,
    required this.onNote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    String btnText;
    IconData btnIcon;

    switch (task.status) {
      case TaskStatus.notStarted:
        statusColor = AppColors.accentOrange;
        statusText = "Pending";
        btnText = "Start";
        btnIcon = Icons.play_arrow;
        break;
      case TaskStatus.inProgress:
        statusColor = Colors.blue;
        statusText = "In Progress";
        btnText = "Complete";
        btnIcon = Icons.check;
        break;
      default:
        statusColor = Colors.grey;
        statusText = "Unknown";
        btnText = "Done";
        btnIcon = Icons.check;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    task.unitType == PlanUnitType.surah
                        ? Icons.menu_book
                        : (task.unitType == PlanUnitType.juz
                              ? Icons.layers
                              : Icons.description),
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (task.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoPill(
                  Icons.flag,
                  task.type == TaskType.memorize ? "Memorize" : "Revision",
                  isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                _buildInfoPill(
                  Icons.event,
                  _formatDate(task.deadline),
                  isDark ? const Color(0xFFF0C33D) : const Color(0xFFFF0000),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                InkWell(
                  onTap: onNote,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.edit_note, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          "Notes",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: Icon(btnIcon, size: 18, color: Colors.white),
                  label: Text(
                    btnText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text, Color? color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  String _monthAbbr(int month) {
    const months = [
      "", // Placeholder for 0 index
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month];
  }

  String _formatTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }

  // 07 Jan 2026 10:30 AM
  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} "
      "${_monthAbbr(d.month)} ${d.year} "
      "${_formatTime(d)}";
}
