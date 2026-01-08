import 'package:flutter/material.dart';
import '../widgets/theme_toggle_button.dart';
import 'planner/assign_page.dart';
import '../models/plan_task.dart';
import '../services/planner_database_helper.dart';
import '../widgets/dashboard/plan_task_card.dart';
import '../widgets/dashboard/notes_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTaskAction(PlanTask task) async {
    if (task.status == TaskStatus.notStarted) {
      await PlannerDatabaseHelper().updateTaskStatus(
        task.id!,
        TaskStatus.inProgress,
      );
    } else if (task.status == TaskStatus.inProgress) {
      // Complete logic
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Prevents back button if pushed
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('Dashboard', style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: theme.appBarTheme.iconTheme?.color,
            ),
            onPressed: _fetchTasks,
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? Colors.black12 : Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Active Tasks (${_tasks.length})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      return PlanTaskCard(
                        task: _tasks[index],
                        onAction: () => _handleTaskAction(_tasks[index]),
                        onNote: () => _openNotes(_tasks[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No active tasks.", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
