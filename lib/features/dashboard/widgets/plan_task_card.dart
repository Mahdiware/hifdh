import 'package:flutter/material.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlass(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(16),
        blur: 16,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1C2B3F), const Color(0xFF162436)]
              : [const Color(0xCCFFFFFF), const Color(0x99E8F2FF)],
        ),
        tint: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0x66DCEBFF),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.primaryNavy.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.16)
                : AppColors.primaryNavy.withValues(alpha: 0.08),
            blurRadius: isDark ? 9 : 14,
            offset: Offset(0, isDark ? 4 : 6),
          ),
        ],
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusColor.withValues(alpha: 0.2),
                        statusColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    task.unitType == PlanUnitType.surah
                        ? Icons.menu_book
                        : (task.unitType == PlanUnitType.juz
                              ? Icons.layers
                              : Icons.description),
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLocalizedTitle(context, task),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (task.subtitle != null &&
                          task.unitType != PlanUnitType.juz) ...[
                        const SizedBox(height: 2),
                        Text(
                          _getLocalizedSubtitle(context, task) ??
                              task.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: LiquidGlass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    blur: 8,
                    tint: statusColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                    boxShadow: const [],
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (widget.onEdit != null || widget.onDelete != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildInfoPill(
                      Icons.flag,
                      task.type == TaskType.memorize
                          ? l10n.memorize
                          : l10n.revision,
                      task.type == TaskType.memorize
                          ? AppColors.primaryNavy
                          : AppColors.accentOrange,
                      isDark,
                      maxWidth: 130,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildInfoPill(
                      Icons.event,
                      _formatDate(
                        task.deadline,
                        Localizations.localeOf(context).toString(),
                      ),
                      isDark
                          ? const Color(0xFFFFC857)
                          : const Color(0xFFB42318),
                      isDark,
                      maxWidth: 170,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.dividerLight,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: LiquidGlass(
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(10),
                    blur: 10,
                    tint: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.primaryNavy.withValues(alpha: 0.06),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : AppColors.primaryNavy.withValues(alpha: 0.12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onNote,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.primaryNavy,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                l10n.notes,
                                style: TextStyle(
                                  fontSize: 14,
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
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LiquidGlass(
                  padding: const EdgeInsets.all(2),
                  borderRadius: BorderRadius.circular(10),
                  blur: 10,
                  tint: statusColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(btnIcon, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                btnText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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

  Widget _buildInfoPill(
    IconData icon,
    String text,
    Color color,
    bool isDark, {
    double? maxWidth,
  }) {
    final pill = LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      borderRadius: BorderRadius.circular(999),
      blur: 8,
      tint: color.withValues(alpha: isDark ? 0.2 : 0.1),
      border: Border.all(color: color.withValues(alpha: 0.28)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (maxWidth == null) return pill;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: pill,
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
