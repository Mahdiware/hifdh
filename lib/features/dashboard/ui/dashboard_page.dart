import 'package:flutter/material.dart';
import 'package:hifdh/features/planner/ui/assign_page.dart';
import 'package:hifdh/shared/models/plan_task.dart';
import 'package:hifdh/core/services/planner_database.dart';
import 'package:hifdh/features/dashboard/widgets/plan_task_card.dart';
import 'package:hifdh/features/dashboard/widgets/notes_sheet.dart';
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
    _fetchTasks();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: DashboardAppBar(onRefresh: _fetchTasks),
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
                : _buildTaskList(),
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
