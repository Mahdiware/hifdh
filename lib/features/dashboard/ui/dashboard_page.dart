import 'package:flutter/material.dart';
import 'package:hifdh/shared/widgets/theme_toggle_button.dart';
import 'package:hifdh/features/planner/ui/assign_page.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/planner_database_helper.dart';
import 'package:hifdh/features/dashboard/widgets/plan_task_card.dart';
import 'package:hifdh/features/dashboard/widgets/notes_sheet.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:hifdh/features/settings/logic/locale_provider.dart';
import 'package:hifdh/core/theme/app_colors.dart';

enum DashboardSort { newest, oldest, typeMemorize, typeRevision }
enum SortUnitType { all, surah, juz, page, custom }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  PlanUnitType? _selectedFilter;
  DashboardSort _sortOption = DashboardSort.newest;
  List<PlanTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await PlannerDatabaseHelper().getActiveTasks();
      setState(() {
        _tasks = tasks;
        _sortTasks(); // Sort immediately after fetching
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  void _sortTasks() {
    switch (_sortOption) {
      case DashboardSort.newest:
        _tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case DashboardSort.oldest:
        _tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case DashboardSort.typeMemorize:
        _tasks.sort((a, b) {
          int typeComp = a.type.index.compareTo(b.type.index);
          if (typeComp != 0) return typeComp;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case DashboardSort.typeRevision:
        _tasks.sort((a, b) {
          int typeComp = b.type.index.compareTo(a.type.index);
          if (typeComp != 0) return typeComp;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
  }

  void _onSortChanged(DashboardSort? sort) {
    if (sort != null) {
      setState(() {
        _sortOption = sort;
        _sortTasks();
      });
    }
  }

  Future<void> _handleTaskAction(PlanTask task) async {
    if (task.status == TaskStatus.notStarted) {
      await PlannerDatabaseHelper().updateTaskStatus(
        task.id!,
        TaskStatus.inProgress,
      );
    } else if (task.status == TaskStatus.inProgress) {
      await PlannerDatabaseHelper().completeTask(task.id!, DateTime.now());
    }
    _fetchTasks();
  }

  void _openNotes(PlanTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => NotesSheet(task: task),
    );
  }

  Future<void> _editTask(PlanTask task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AssignPage(taskToEdit: task)),
    );
    if (result == true) {
      _fetchTasks();
    }
  }

  Future<void> _deleteTask(PlanTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.delete),
        content: Text(AppLocalizations.of(context)!.confirmDeleteTask),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PlannerDatabaseHelper().deleteTask(task.id!);
      _fetchTasks();
    }
  }

  List<PlanTask> get _filteredTasks {
    if (_selectedFilter == null) return _tasks;
    return _tasks.where((t) => t.unitType == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, theme, l10n),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AssignPage()),
          );
          if (res == true) _fetchTasks();
        },
      ),
      body: Column(
        children: [
          _buildHeader(isDark, l10n),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTasks.isEmpty
                ? _buildEmptyState(l10n)
                : _buildTaskList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      title: Text(l10n.dashboard, style: theme.appBarTheme.titleTextStyle),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: theme.appBarTheme.iconTheme?.color),
          onPressed: _fetchTasks,
        ),
        Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            return PopupMenuButton<Locale>(
              icon: Icon(
                Icons.language,
                color: theme.appBarTheme.iconTheme?.color,
              ),
              onSelected: (Locale locale) {
                localeProvider.setLocale(locale);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
                const PopupMenuItem<Locale>(
                  value: Locale('en'),
                  child: Text('English'),
                ),
                const PopupMenuItem<Locale>(
                  value: Locale('ar'),
                  child: Text('العربية'),
                ),
                const PopupMenuItem<Locale>(
                  value: Locale('so'),
                  child: Text('Soomaali'),
                ),
              ],
            );
          },
        ),
        const ThemeToggleButton(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader(bool isDark, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.activeTasks,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${_filteredTasks.length} ${l10n.pending}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ],
          ),
          Row(
            children: [
              PopupMenuButton<SortUnitType>(
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tooltip: "Filter",
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.primaryNavy,
                    size: 20,
                  ),
                ),
                color: isDark ? const Color(0xFF2C2E42) : Colors.white,
                elevation: 4,
                onSelected: (SortUnitType type) {
                  setState(() {
                      final PlanUnitType? value = switch (type) {
                          SortUnitType.all => null,
                          SortUnitType.surah => PlanUnitType.surah,
                          SortUnitType.juz => PlanUnitType.juz,
                          SortUnitType.page => PlanUnitType.page,
                          SortUnitType.custom => PlanUnitType.custom,
                      };

                      _selectedFilter = value;
                  });
                },
                  itemBuilder: (BuildContext context) {
                  return [
                    _buildFilterMenuItem(
                      context,
                      l10n.all,
                      SortUnitType.all,
                      isDark,
                    ),
                    _buildFilterMenuItem(
                      context,
                      l10n.surah,
                      SortUnitType.surah,
                      isDark,
                    ),
                    _buildFilterMenuItem(
                      context,
                      l10n.juz,
                      SortUnitType.juz,
                      isDark,
                    ),
                    _buildFilterMenuItem(
                      context,
                      l10n.page,
                      SortUnitType.page,
                      isDark,
                    ),
                  ];
                },
              ),
              PopupMenuButton<DashboardSort>(
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tooltip: "Sort",
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sort_rounded,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.primaryNavy,
                    size: 20,
                  ),
                ),
                color: isDark ? const Color(0xFF2C2E42) : Colors.white,
                elevation: 4,
                onSelected: _onSortChanged,
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<DashboardSort>>[
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
              ),
            ],
          ),
        ],
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

    final isSelected = switch (_selectedFilter?.name) {
        null => value.name == SortUnitType.all.name,
        _ => _selectedFilter!.name == value.name,
    };

    debugPrint("isSelected: $isSelected = ${_selectedFilter?.name} + ${value.name}");
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
          // Round Checkbox
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

  Widget _buildTaskList() {
    final tasks = _filteredTasks;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return PlanTaskCard(
          task: tasks[index],
          onAction: () => _handleTaskAction(tasks[index]),
          onNote: () => _openNotes(tasks[index]),
          onEdit: () => _editTask(tasks[index]),
          onDelete: () => _deleteTask(tasks[index]),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(l10n.noActiveTasks, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
