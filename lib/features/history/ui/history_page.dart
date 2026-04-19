import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/core/utils/ayah_search_query.dart';
import 'package:hifdh/shared/widgets/collapsible_note_card.dart';
import 'package:hifdh/shared/widgets/liquid_glass.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';

enum HistorySort { newest, oldest, typeMemorize, typeRevision }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<PlanTask> _history = [];
  List<PlanTask> _filteredHistory = []; // Display list
  bool _isLoading = true;
  bool _isRefreshingHistory = false;
  bool _pendingHistoryRefresh = false;
  int? _processingTaskId;
  HistorySort _sortOption = HistorySort.newest;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    PlannerDatabase().dataUpdateNotifier.addListener(_handleHistoryUpdate);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    PlannerDatabase().dataUpdateNotifier.removeListener(_handleHistoryUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _handleHistoryUpdate() {
    _loadHistory(showLoading: false);
  }

  void _onSearchChanged() {
    _filterHistory();
  }

  Future<void> _loadHistory({bool showLoading = true}) async {
    if (_isRefreshingHistory) {
      _pendingHistoryRefresh = true;
      return;
    }

    _isRefreshingHistory = true;
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final history = await PlannerDatabase().getCompletedTasks();

      // Sort logic
      _sortData(history); // Sort the raw list

      final query = _searchController.text.trim();
      final search = query.isEmpty ? null : AyahSearchQuery.parse(query);
      final filtered = _computeFilteredHistory(history, query, search);

      if (mounted) {
        setState(() {
          _history = history;
          _filteredHistory = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      _isRefreshingHistory = false;
      if (_pendingHistoryRefresh && mounted) {
        _pendingHistoryRefresh = false;
        Future.microtask(() => _loadHistory(showLoading: false));
      }
    }
  }

  void _filterHistory() {
    final query = _searchController.text.trim();
    final search = query.isEmpty ? null : AyahSearchQuery.parse(query);
    final filtered = _computeFilteredHistory(_history, query, search);
    if (!mounted) return;
    setState(() => _filteredHistory = filtered);
  }

  List<PlanTask> _computeFilteredHistory(
    List<PlanTask> source,
    String query,
    AyahSearchQuery? search,
  ) {
    if (query.isEmpty) {
      return List<PlanTask>.from(source);
    }

    final q = query.toLowerCase();
    return source.where((task) {
      bool matchesRange = false;

      if (search != null) {
        if (search.isSpecificAyah()) {
          if (task.unitType == PlanUnitType.surah &&
              task.unitId == search.surahNumber) {
            final start = task.startAyah ?? 1;
            final end = task.endAyah ?? 9999;
            if (search.ayahNumber! >= start && search.ayahNumber! <= end) {
              matchesRange = true;
            }
          }
        } else if (search.surahNumber != null && search.ayahNumber == null) {
          if (task.unitType == PlanUnitType.surah &&
              task.unitId == search.surahNumber) {
            matchesRange = true;
          }
        }
      }

      if (matchesRange) return true;

      return task.title.toLowerCase().contains(q) ||
          (task.subtitle?.toLowerCase().contains(q) ?? false) ||
          (task.note?.toLowerCase().contains(q) ?? false) ||
          task.id.toString() == q;
    }).toList();
  }

  void _sortData(List<PlanTask> list) {
    if (list.isEmpty) return;

    switch (_sortOption) {
      case HistorySort.newest:
        list.sort(
          (a, b) => (b.completedAt ?? DateTime(0)).compareTo(
            a.completedAt ?? DateTime(0),
          ),
        );
        break;
      case HistorySort.oldest:
        list.sort(
          (a, b) => (a.completedAt ?? DateTime(0)).compareTo(
            b.completedAt ?? DateTime(0),
          ),
        );
        break;
      case HistorySort.typeMemorize:
        list.sort((a, b) {
          int typeComp = a.type.index.compareTo(
            b.type.index,
          ); // 0: memorize, 1: revision
          if (typeComp != 0) return typeComp; // Memorize first
          return (b.completedAt ?? DateTime(0)).compareTo(
            a.completedAt ?? DateTime(0),
          );
        });
        break;
      case HistorySort.typeRevision:
        list.sort((a, b) {
          int typeComp = b.type.index.compareTo(a.type.index); // Revision first
          if (typeComp != 0) return typeComp;
          return (b.completedAt ?? DateTime(0)).compareTo(
            a.completedAt ?? DateTime(0),
          );
        });
        break;
    }
  }

  void _onSortChanged(HistorySort? sort) {
    if (sort != null) {
      setState(() => _sortOption = sort);
      // Re-sort and re-filter
      _sortData(_history);
      _filterHistory();
    }
  }

  Widget _buildSearchField(bool isDark) {
    return LiquidGlass(
      padding: EdgeInsets.zero,
      blur: 18,
      borderRadius: BorderRadius.circular(14),
      tint: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.68),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchHistory,
            hintStyle: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : AppColors.textSecondaryLight,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: isDark ? Colors.white70 : AppColors.primaryNavy,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    color: Colors.grey,
                    onPressed: () {
                      _searchController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Map<String, List<PlanTask>> _groupTasksByDate(BuildContext context) {
    final Map<String, List<PlanTask>> grouped = {};
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final locale = Localizations.localeOf(context).languageCode == 'ar'
        ? 'ar'
        : 'en';

    // Use _filteredHistory instead of _history
    for (var task in _filteredHistory) {
      final date = task.completedAt;
      if (date == null) continue;

      String key;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        key = AppLocalizations.of(context)!.today;
      } else if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) {
        key = AppLocalizations.of(context)!.yesterday;
      } else {
        key = DateFormat('MMMM d, y', locale).format(date);
      }

      if (grouped.containsKey(key)) {
        grouped[key]!.add(task);
      } else {
        grouped[key] = [task];
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final groupedTasks = _groupTasksByDate(context).entries.toList();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF152B4D), AppColors.backgroundDark]
                  : [const Color(0xFFEAF1FF), AppColors.backgroundLight],
            ),
          ),
        ),
        title: _buildSearchField(isDark), // Replaced title with search
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<HistorySort>(
              icon: LiquidGlass(
                padding: EdgeInsets.zero,
                blur: 16,
                borderRadius: BorderRadius.circular(12),
                tint: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.68),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    Icons.sort,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.primaryNavy,
                    size: 20,
                  ),
                ),
              ),
              onSelected: _onSortChanged,
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<HistorySort>>[
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.newest,
                      child: Text(
                        AppLocalizations.of(context)!.sortNewest,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.oldest,
                      child: Text(
                        AppLocalizations.of(context)!.sortOldest,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.typeMemorize,
                      child: Text(
                        AppLocalizations.of(context)!.memorizeTasksFirst,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.typeRevision,
                      child: Text(
                        AppLocalizations.of(context)!.revisionTasksFirst,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : groupedTasks.isEmpty
            ? _buildEmptyState(isDark)
            : _buildGroupedHistoryList(groupedTasks, isDark),
      ),
    );
  }

  Widget _buildGroupedHistoryList(
    List<MapEntry<String, List<PlanTask>>> groupedTasks,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final totalTasks = _filteredHistory.length;
    final memorizedTasks = _filteredHistory
        .where((t) => t.type == TaskType.memorize)
        .length;
    final revisionTasks = totalTasks - memorizedTasks;
    final flatItems = _buildFlatHistoryItems(groupedTasks);

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      itemCount: flatItems.length,
      itemBuilder: (context, index) {
        final item = flatItems[index];

        switch (item.type) {
          case _HistoryListItemType.summary:
            return Column(
              children: [
                _SlideFadeReveal(
                  index: index,
                  child: LiquidGlass(
                    blur: 22,
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(16),
                    tint: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.68),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryPill(
                            label: l10n.total,
                            value: '$totalTasks',
                            color: AppColors.primaryNavy,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryPill(
                            label: l10n.memorize,
                            value: '$memorizedTasks',
                            color: AppColors.successGreen,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryPill(
                            label: l10n.revision,
                            value: '$revisionTasks',
                            color: AppColors.accentOrange,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          case _HistoryListItemType.header:
            return _SlideFadeReveal(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Text(
                  item.headerText!,
                  style: TextStyle(
                    color: AppColors.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
          case _HistoryListItemType.task:
            return _SlideFadeReveal(
              index: index,
              child: _buildTaskItem(item.task!, isDark),
            );
        }
      },
    );
  }

  List<_HistoryListItem> _buildFlatHistoryItems(
    List<MapEntry<String, List<PlanTask>>> groupedTasks,
  ) {
    final items = <_HistoryListItem>[const _HistoryListItem.summary()];
    for (final entry in groupedTasks) {
      items.add(_HistoryListItem.header(entry.key));
      for (final task in entry.value) {
        items.add(_HistoryListItem.task(task));
      }
    }
    return items;
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: BorderRadius.circular(12),
      blur: 10,
      tint: color.withValues(alpha: isDark ? 0.24 : 0.12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      boxShadow: const [],
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: LiquidGlass(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        borderRadius: BorderRadius.circular(18),
        blur: 16,
        tint: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.7),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.dividerLight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off,
              size: 60,
              color: AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noHistory,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.completeSomeMemorizationToSeeHistory,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(PlanTask task, bool isDark) {
    final isMemorize = task.type == TaskType.memorize;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        blur: 14,
        tint: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.7),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.dividerLight.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showTaskDetails(task),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isMemorize
                          ? AppColors.successGreen.withValues(alpha: 0.1)
                          : AppColors.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isMemorize ? Icons.menu_book : Icons.cached,
                      color: isMemorize
                          ? AppColors.successGreen
                          : AppColors.accentOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            LiquidGlass(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              blur: 8,
                              tint: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.65),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : AppColors.dividerLight,
                              ),
                              boxShadow: const [],
                              child: Text(
                                DateFormat(
                                  'hh:mm a',
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'ar'
                                      ? 'ar'
                                      : 'en',
                                ).format(task.completedAt!),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (task.subtitle != null && task.subtitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              task.subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            _buildChip(
                              isMemorize
                                  ? AppLocalizations.of(context)!.memorize
                                  : AppLocalizations.of(context)!.revision,
                              isMemorize
                                  ? AppColors.successGreen
                                  : AppColors.accentOrange,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            if (task.unitType == PlanUnitType.surah)
                              _buildChip(
                                AppLocalizations.of(context)!.surah,
                                AppColors.primaryNavy,
                                isDark,
                              ),
                            if (task.unitType == PlanUnitType.juz)
                              _buildChip(
                                AppLocalizations.of(context)!.juz,
                                AppColors.primaryNavy,
                                isDark,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (task.completedAt != null &&
                      task.completedAt!.year == DateTime.now().year &&
                      task.completedAt!.month == DateTime.now().month &&
                      task.completedAt!.day == DateTime.now().day)
                    _processingTaskId == task.id
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : SizedBox(
                            width: 36,
                            height: 36,
                            child: LiquidGlass(
                              padding: EdgeInsets.zero,
                              borderRadius: BorderRadius.circular(10),
                              blur: 8,
                              tint: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.68),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : AppColors.dividerLight,
                              ),
                              boxShadow: const [],
                              child: IconButton(
                                icon: Icon(
                                  Icons.undo,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  size: 18,
                                ),
                                onPressed: _processingTaskId == null
                                    ? () => _confirmUndoTask(task)
                                    : null,
                                tooltip: AppLocalizations.of(
                                  context,
                                )!.undoCompletion,
                              ),
                            ),
                          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUndoTask(PlanTask task) async {
    // Disable clicks if any task is processing
    if (_processingTaskId != null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final l10n = AppLocalizations.of(context)!;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LiquidGlass(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              borderRadius: BorderRadius.circular(18),
              blur: 16,
              tint: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.74),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.undoCompletion,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.moveTaskBackToDashboard(task.title),
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentOrange,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.undo),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm == true && task.id != null) {
      if (mounted) setState(() => _processingTaskId = task.id);
      try {
        await PlannerDatabase().undoCompleteTask(task.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.taskMovedBackToDashboard,
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _processingTaskId = null);
      }
    }
  }

  Widget _buildChip(String label, Color color, bool isDark) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      borderRadius: BorderRadius.circular(6),
      blur: 8,
      tint: color.withValues(alpha: isDark ? 0.2 : 0.1),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      boxShadow: const [],
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showTaskDetails(PlanTask task) {
    if (task.id == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TaskHistoryDetailsSheet(task: task),
    );
  }
}

class _TaskHistoryDetailsSheet extends StatefulWidget {
  final PlanTask task;
  const _TaskHistoryDetailsSheet({required this.task});

  @override
  State<_TaskHistoryDetailsSheet> createState() =>
      _TaskHistoryDetailsSheetState();
}

class _TaskHistoryDetailsSheetState extends State<_TaskHistoryDetailsSheet> {
  late Future<List<TaskNote>> _notesFuture;
  bool _legacyNoteDeleted = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    _notesFuture = PlannerDatabase()
        .getTaskNotes(widget.task.id!)
        .then(
          (notes) => notes.where((n) => n.type != NoteType.correct).toList(),
        );
  }

  Future<void> _deleteNote(int id) async {
    await PlannerDatabase().deleteTaskNote(id);
    if (mounted) {
      setState(() {
        _loadNotes();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return FutureBuilder<List<TaskNote>>(
          future: _notesFuture,
          builder: (context, snapshot) {
            return LiquidGlass(
              padding: EdgeInsets.zero,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              blur: 20,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1A2E4D), AppColors.backgroundDark]
                    : [const Color(0xFFF2F7FF), AppColors.backgroundLight],
              ),
              tint: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.64),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.task.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      Icons.calendar_today,
                      l10n.completedOn,
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).languageCode == 'ar'
                            ? 'ar'
                            : 'en',
                      ).add_jm().format(widget.task.completedAt!),
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.category,
                      l10n.taskType,
                      widget.task.type == TaskType.memorize
                          ? AppLocalizations.of(context)!.memorize
                          : AppLocalizations.of(context)!.revision,
                      isDark,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.primaryNavy,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.notesHistory,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!snapshot.hasData)
                      const Center(child: CircularProgressIndicator())
                    else if (snapshot.data!.isEmpty &&
                        (widget.task.note == null ||
                            widget.task.note!.isEmpty ||
                            _legacyNoteDeleted))
                      _buildEmptyNotesState(isDark)
                    else ...[
                      if (widget.task.note != null &&
                          widget.task.note!.isNotEmpty &&
                          !_legacyNoteDeleted &&
                          !snapshot.data!.any(
                            (n) => n.content == widget.task.note,
                          ))
                        CollapsibleNoteCard(
                          note: TaskNote(
                            id: -1,
                            taskId: widget.task.id!,
                            content: widget.task.note!,
                            type: NoteType.mistake,
                            createdAt:
                                widget.task.completedAt ?? DateTime.now(),
                          ),
                          onDelete: () async {
                            await PlannerDatabase().updateTaskNote(
                              widget.task.id!,
                              '',
                            );
                            if (mounted) {
                              setState(() {
                                _legacyNoteDeleted = true;
                              });
                            }
                          },
                        ),
                      ...snapshot.data!.map(
                        (note) => CollapsibleNoteCard(
                          note: note,
                          onDelete: () => _deleteNote(note.id!),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: LiquidGlass(
                        padding: const EdgeInsets.all(4),
                        borderRadius: BorderRadius.circular(14),
                        blur: 12,
                        tint: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.68),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF5A7EA8)
                                  : const Color(0xFF58779A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              elevation: 0,
                            ),
                            child: Text(l10n.close),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyNotesState(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: LiquidGlass(
        padding: const EdgeInsets.symmetric(vertical: 24),
        borderRadius: BorderRadius.circular(12),
        blur: 12,
        tint: isDark
            ? AppColors.backgroundDark.withValues(alpha: 0.74)
            : AppColors.backgroundLight.withValues(alpha: 0.76),
        border: Border.all(
          color: isDark ? Colors.transparent : AppColors.dividerLight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.notes,
              size: 40,
              color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.noNotesRecordedYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(12),
      blur: 10,
      tint: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.68),
      border: Border.all(
        color: isDark ? Colors.white10 : AppColors.dividerLight,
      ),
      boxShadow: const [],
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlideFadeReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _SlideFadeReveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion = mediaQuery?.disableAnimations ?? false;
    final androidPhone =
        defaultTargetPlatform == TargetPlatform.android &&
        !kIsWeb &&
        (mediaQuery?.size.shortestSide ?? 1000) < 600;

    if (reduceMotion || androidPhone) {
      return child;
    }

    final clampedIndex = index.clamp(0, 14);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (clampedIndex * 35)),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
    );
  }
}

enum _HistoryListItemType { summary, header, task }

class _HistoryListItem {
  final _HistoryListItemType type;
  final String? headerText;
  final PlanTask? task;

  const _HistoryListItem.summary()
    : type = _HistoryListItemType.summary,
      headerText = null,
      task = null;

  const _HistoryListItem.header(this.headerText)
    : type = _HistoryListItemType.header,
      task = null;

  const _HistoryListItem.task(this.task)
    : type = _HistoryListItemType.task,
      headerText = null;
}
