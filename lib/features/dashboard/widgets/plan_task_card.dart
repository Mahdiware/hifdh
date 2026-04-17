import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

class PlanTaskCard extends StatefulWidget {
  final PlanTask task;
  final Future<void> Function() onAction;
  final VoidCallback onNote;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PlanTaskCard({
    super.key,
    required this.task,
    required this.onAction,
    required this.onNote,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<PlanTaskCard> createState() => _PlanTaskCardState();
}

class _PlanTaskCardState extends State<PlanTaskCard> {
  bool _isLoading = false;

  Future<void> _handleAction() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onAction();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final task = widget.task;

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
        statusColor = AppColors.primaryNavy;
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
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.surfaceDark, const Color(0xFF243C61)]
              : [Colors.white, const Color(0xFFF8FBFF)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusColor.withValues(alpha: 0.2),
                        statusColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
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
                      if (task.subtitle != null &&
                          task.unitType != PlanUnitType.juz) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getLocalizedSubtitle(context, task) ??
                              task.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
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
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
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
                if (widget.onEdit != null || widget.onDelete != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') widget.onEdit?.call();
                      if (value == 'delete') widget.onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      if (widget.onEdit != null)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 20),
                              const SizedBox(width: 12),
                              Text(l10n.edit),
                            ],
                          ),
                        ),
                      if (widget.onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: AppColors.errorRed,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.delete,
                                style: TextStyle(color: AppColors.errorRed),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
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
                  task.type == TaskType.memorize
                      ? AppColors.primaryNavy
                      : AppColors.accentOrange,
                  isDark,
                ),
                _buildInfoPill(
                  Icons.event,
                  _formatDate(
                    task.deadline,
                    Localizations.localeOf(context).toString(),
                  ),
                  isDark ? const Color(0xFFFFC857) : const Color(0xFFB42318),
                  isDark,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.dividerLight,
              ),
            ),
            Row(
              children: [
                InkWell(
                  onTap: widget.onNote,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.primaryNavy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.primaryNavy,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.notes,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(btnIcon, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              btnText,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        String title = "${l10n.juz} ${task.unitId}";
        final subtitle = _getLocalizedSubtitle(context, task);
        if (subtitle != null &&
            subtitle != l10n.wholeJuz &&
            task.subtitle != "Whole Juz" &&
            task.subtitle != "Full Juz") {
          title = "$title - $subtitle";
        }
        return title;
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

    if (s.contains("Whole Juz") || s.contains("Full Juz")) {
      return l10n.wholeJuz;
    }
    // Add logic for quarters/halves if needed, reusing logic from AssignPage
    return s;
  }
}
