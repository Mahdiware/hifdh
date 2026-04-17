import 'package:flutter/material.dart';
import 'package:hifdh/core/theme/app_background.dart';
import 'package:hifdh/core/theme/app_colors.dart';
import 'package:hifdh/features/planner/ui/assign_page.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/features/dashboard/widgets/plan_task_card.dart';
import 'package:hifdh/features/dashboard/widgets/notes_sheet.dart';
import 'package:hifdh/features/revision_queue/ui/revision_queue_page.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/features/dashboard/widgets/dashboard_app_bar.dart';
import 'package:hifdh/features/dashboard/widgets/dashboard_header.dart';
import 'package:hifdh/features/dashboard/models/dashboard_filter_types.dart';

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
    PlannerDatabase().dataUpdateNotifier.addListener(_fetchTasks);
    _fetchTasks();
  }

  @override
  void dispose() {
    PlannerDatabase().dataUpdateNotifier.removeListener(_fetchTasks);
    super.dispose();
  }

  Future<void> _fetchTasks({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final tasks = await PlannerDatabase().getActiveTasks();
      setState(() {
        _tasks = tasks;
        _sortTasks(); // Sort immediately after fetching
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      if (mounted) setState(() => _isLoading = false);
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

  void _onFilterSelected(SortUnitType type) {
    setState(() {
      _selectedFilter = switch (type) {
        SortUnitType.all => null,
        SortUnitType.surah => PlanUnitType.surah,
        SortUnitType.juz => PlanUnitType.juz,
        SortUnitType.page => PlanUnitType.page,
        SortUnitType.custom => PlanUnitType.custom,
      };
    });
  }

  Future<void> _handleTaskAction(PlanTask task) async {
    if (task.status == TaskStatus.notStarted) {
      await PlannerDatabase().updateTaskStatus(task.id!, TaskStatus.inProgress);
    } else if (task.status == TaskStatus.inProgress) {
      await PlannerDatabase().completeTask(task.id!, DateTime.now());
    }
    _fetchTasks(showLoading: false);
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
      await PlannerDatabase().deleteTask(task.id!);
      _fetchTasks();
    }
  }

  List<PlanTask> get _filteredTasks {
    if (_selectedFilter == null) return _tasks;
    return _tasks.where((t) => t.unitType == _selectedFilter).toList();
  }

  Future<void> _openRevisionQueue() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RevisionQueuePage()),
    );
    if (mounted) {
      _fetchTasks(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: DashboardAppBar(
        onRefresh: _fetchTasks,
        onOpenRevisionQueue: _openRevisionQueue,
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 0,
        backgroundColor: AppColors.primaryNavy,
        child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AssignPage()),
          );
          if (res == true) _fetchTasks();
        },
      ),
      body: DecoratedBox(
        decoration: AppBackground.pageDecoration(theme),
        child: Column(
          children: [
            DashboardHeader(
              activeCount: _filteredTasks.length,
              selectedFilter: _selectedFilter,
              onFilterSelected: _onFilterSelected,
              onSortSelected: (sort) => _onSortChanged(sort),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTasks.isEmpty
                  ? _buildEmptyState(l10n)
                  : RefreshIndicator(
                      onRefresh: () => _fetchTasks(showLoading: false),
                      child: _buildTaskList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    final tasks = _filteredTasks;
    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];

        return _StaggeredListReveal(
          index: index,
          child: PlanTaskCard(
            task: task,
            onAction: () => _handleTaskAction(task),
            onNote: () => _openNotes(task),
            onEdit: () => _editTask(task),
            onDelete: () => _deleteTask(task),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.dividerLight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.spa_outlined,
                size: 30,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.noActiveTasks,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredListReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredListReveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final clampedIndex = index.clamp(0, 8);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (clampedIndex * 45)),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
    );
  }
}
