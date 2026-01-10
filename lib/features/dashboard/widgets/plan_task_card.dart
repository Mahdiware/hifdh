import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

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
    final l10n = AppLocalizations.of(context)!;

    Color statusColor;
    String statusText;
    String btnText;
    IconData btnIcon;

    switch (task.status) {
      case TaskStatus.notStarted:
        statusColor = AppColors.accentOrange;
        statusText = l10n.pending;
        btnText = l10n.start;
        btnIcon = Icons.play_arrow;
        break;
      case TaskStatus.inProgress:
        statusColor = Colors.blue;
        statusText = l10n.inProgress;
        btnText = l10n.complete;
        btnIcon = Icons.check;
        break;
      default:
        statusColor = Colors.grey;
        statusText = l10n.unknown;
        btnText = l10n.done;
        btnIcon = Icons.check;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                    color: statusColor.withValues(alpha: 0.1),
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
                        _getLocalizedTitle(context, task),
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
                          _getLocalizedSubtitle(context, task) ??
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
                    color: statusColor.withValues(alpha: 0.1),
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
                  task.type == TaskType.memorize
                      ? l10n.memorize
                      : l10n.revision,
                  isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                _buildInfoPill(
                  Icons.event,
                  _formatDate(
                    task.deadline,
                    Localizations.localeOf(context).toString(),
                  ),
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
                          l10n.notes,
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

  String _formatDate(DateTime d, String locale) {
    try {
      return DateFormat.yMMMd(locale).add_jm().format(d);
    } catch (e) {
      return DateFormat.yMMMd('en').add_jm().format(d);
    }
  }

  String _getLocalizedTitle(BuildContext context, PlanTask task) {
    final l10n = AppLocalizations.of(context)!;
    switch (task.unitType) {
      case PlanUnitType.juz:
        return "${l10n.juz} ${task.unitId}";
      case PlanUnitType.page:
        return "${l10n.page} ${task.unitId} - ${task.endUnitId}";
      case PlanUnitType.surah:
      default:
        return task.title;
    }
  }

  String? _getLocalizedSubtitle(BuildContext context, PlanTask task) {
    if (task.subtitle == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final s = task.subtitle!;

    if (s == "Whole Juz") return l10n.wholeJuz;
    if (s.startsWith("Nisf Hizb ")) {
      return s.replaceFirst("Nisf Hizb", l10n.nisfHizb);
    }
    if (s.startsWith("Hizb ")) return s.replaceFirst("Hizb", l10n.hizb);
    if (s.startsWith("Rubuc ")) return s.replaceFirst("Rubuc", l10n.rubuc);
    if (s.startsWith("Ayah ")) return s.replaceFirst("Ayah", l10n.ayah);

    return s;
  }
}
