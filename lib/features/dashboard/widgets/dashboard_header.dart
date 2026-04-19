import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/shared/models/plan_task.dart'; // For PlanUnitType if needed mapping
import 'package:hifdh/features/dashboard/models/dashboard_filter_types.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';

class DashboardHeader extends StatelessWidget {
  final int activeCount;
  final PlanUnitType? selectedFilter;
  final Function(SortUnitType) onFilterSelected;
  final Function(DashboardSort) onSortSelected;

  const DashboardHeader({
    super.key,
    required this.activeCount,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: LiquidGlass(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        borderRadius: BorderRadius.circular(22),
        blur: 20,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A4266), const Color(0xFF1F3454)]
              : [const Color(0xFFF4F8FF), const Color(0xFFE9F1FF)],
        ),
        tint: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.68),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.primaryNavy.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activeTasks,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "$activeCount ${l10n.pending}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildFilterMenu(context, isDark, l10n),
                _buildSortMenu(context, isDark, l10n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterMenu(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return PopupMenuButton<SortUnitType>(
      offset: const Offset(0, 44),
      tooltip: l10n.filter,
      icon: _buildIconContainer(Icons.filter_list_rounded, isDark),
      onSelected: onFilterSelected,
      itemBuilder: (BuildContext context) {
        return [
          _buildFilterMenuItem(context, l10n.all, SortUnitType.all, isDark),
          _buildFilterMenuItem(context, l10n.surah, SortUnitType.surah, isDark),
          _buildFilterMenuItem(context, l10n.juz, SortUnitType.juz, isDark),
          _buildFilterMenuItem(context, l10n.page, SortUnitType.page, isDark),
        ];
      },
    );
  }

  Widget _buildSortMenu(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return PopupMenuButton<DashboardSort>(
      offset: const Offset(0, 44),
      tooltip: l10n.sort,
      icon: _buildIconContainer(Icons.sort_rounded, isDark),
      onSelected: onSortSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<DashboardSort>>[
        PopupMenuItem<DashboardSort>(
          value: DashboardSort.newest,
          child: _buildSortItem(l10n.sortNewest, isDark),
        ),
        PopupMenuItem<DashboardSort>(
          value: DashboardSort.oldest,
          child: _buildSortItem(l10n.sortOldest, isDark),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<DashboardSort>(
          value: DashboardSort.typeMemorize,
          child: _buildSortItem(l10n.memorizeTasksFirst, isDark),
        ),
        PopupMenuItem<DashboardSort>(
          value: DashboardSort.typeRevision,
          child: _buildSortItem(l10n.revisionTasksFirst, isDark),
        ),
      ],
    );
  }

  Widget _buildIconContainer(IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: LiquidGlass(
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(11),
        blur: 10,
        tint: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.primaryNavy.withValues(alpha: 0.08),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : AppColors.primaryNavy.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        child: Icon(
          icon,
          color: isDark ? AppColors.textPrimaryDark : AppColors.primaryNavy,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildSortItem(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  PopupMenuItem<SortUnitType> _buildFilterMenuItem(
    BuildContext context,
    String label,
    SortUnitType value,
    bool isDark,
  ) {
    // Map internal SortUnitType to PlanUnitType for comparison
    final currentType = selectedFilter;

    // Logic: if value is 'all', check if current is null.
    // If value is 'surah', check if current is Surah.
    bool isSelected;
    if (value == SortUnitType.all) {
      isSelected = currentType == null;
    } else {
      // Only compares simpler types here.
      final mapped = switch (value) {
        SortUnitType.surah => PlanUnitType.surah,
        SortUnitType.juz => PlanUnitType.juz,
        SortUnitType.page => PlanUnitType.page,
        SortUnitType.custom => PlanUnitType.custom,
        _ => null,
      };
      isSelected = mapped == currentType;
    }

    final theme = Theme.of(context);

    return PopupMenuItem<SortUnitType>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? theme.primaryColor : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor
                    : (isDark ? Colors.white54 : Colors.grey),
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
