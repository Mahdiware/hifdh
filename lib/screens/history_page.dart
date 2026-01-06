import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/plan_task.dart';
import '../services/planner_database_helper.dart';
import '../theme/app_colors.dart';

enum HistorySort { newest, oldest, typeMemorize, typeRevision }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<PlanTask> _history = [];
  bool _isLoading = true;
  HistorySort _sortOption = HistorySort.newest;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    PlannerDatabaseHelper().dataUpdateNotifier.addListener(_loadHistory);
  }

  @override
  void dispose() {
    PlannerDatabaseHelper().dataUpdateNotifier.removeListener(_loadHistory);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await PlannerDatabaseHelper().getCompletedTasks();

    // Sort logic
    _sortData(history);

    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
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
      // Re-sort current list immediately
      _sortData(_history);
    }
  }

  Map<String, List<PlanTask>> _groupTasksByDate() {
    final Map<String, List<PlanTask>> grouped = {};
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    for (var task in _history) {
      final date = task.completedAt;
      if (date == null) continue;

      String key;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        key = "Today";
      } else if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) {
        key = "Yesterday";
      } else {
        key = DateFormat('MMMM d, y').format(date);
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
    final groupedTasks = _groupTasksByDate();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          "History",
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<HistorySort>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.transparent : AppColors.dividerLight,
                  ),
                ),
                child: Icon(
                  Icons.sort,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.primaryNavy,
                  size: 20,
                ),
              ),
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              onSelected: _onSortChanged,
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<HistorySort>>[
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.newest,
                      child: Text(
                        'Newest First',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.oldest,
                      child: Text(
                        'Oldest First',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.typeMemorize,
                      child: Text(
                        'Memorize Tasks First',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    PopupMenuItem<HistorySort>(
                      value: HistorySort.typeRevision,
                      child: Text(
                        'Revision Tasks First',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedTasks.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: groupedTasks.length,
              itemBuilder: (context, index) {
                String dateKey = groupedTasks.keys.elementAt(index);
                List<PlanTask> tasks = groupedTasks[dateKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 4,
                      ),
                      child: Text(
                        dateKey,
                        style: TextStyle(
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...tasks.map((task) => _buildTaskItem(task, isDark)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
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
            "No completed tasks yet",
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
            "Complete some memorization to see them here!",
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark.withOpacity(0.7)
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(PlanTask task, bool isDark) {
    final isMemorize = task.type == TaskType.memorize;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.transparent
              : AppColors.dividerLight.withOpacity(0.5),
        ),
      ),
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
                        ? AppColors.successGreen.withOpacity(0.1)
                        : AppColors.accentOrange.withOpacity(0.1),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.backgroundDark
                                  : AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat('hh:mm a').format(task.completedAt!),
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
                            isMemorize ? "Memorization" : "Revision",
                            isMemorize
                                ? AppColors.successGreen
                                : AppColors.accentOrange,
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          if (task.unitType == PlanUnitType.surah)
                            _buildChip("Surah", AppColors.primaryNavy, isDark),
                          if (task.unitType == PlanUnitType.juz)
                            _buildChip("Juz", AppColors.primaryNavy, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showTaskDetails(PlanTask task) {
    if (task.id == null) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<TaskNote>>(
              future: PlannerDatabaseHelper().getTaskNotes(task.id!),
              builder: (context, snapshot) {
                return SingleChildScrollView(
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
                        task.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildDetailRow(
                        Icons.calendar_today,
                        "Completed On",
                        DateFormat(
                          'MMM d, y • hh:mm a',
                        ).format(task.completedAt!),
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.category,
                        "Task Type",
                        task.type == TaskType.memorize
                            ? "Memorization"
                            : "Revision",
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
                            "Notes History",
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
                          (task.note == null || task.note!.isEmpty))
                        _buildEmptyNotesState(isDark)
                      else ...[
                        if (task.note != null &&
                            task.note!.isNotEmpty &&
                            !snapshot.data!.any((n) => n.content == task.note))
                          _buildNoteItem(
                            TaskNote(
                              taskId: task.id!,
                              content: task.note!,
                              type: NoteType.note,
                              createdAt: task.completedAt!,
                            ),
                            isDark,
                            isLegacy: true,
                          ),
                        ...snapshot.data!.map(
                          (note) => _buildNoteItem(note, isDark),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text("Close"),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyNotesState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.transparent : AppColors.dividerLight,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notes,
            size: 40,
            color: AppColors.textSecondaryLight.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "No notes recorded",
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(TaskNote note, bool isDark, {bool isLegacy = false}) {
    IconData icon;
    Color color;
    String typeLabel;

    switch (note.type) {
      case NoteType.doubt:
        icon = Icons.help_outline;
        color = AppColors.accentOrange;
        typeLabel = "Doubt";
        break;
      case NoteType.mistake:
        icon = Icons.error_outline;
        color = AppColors.errorRed;
        typeLabel = "Mistake";
        break;
      case NoteType.note:
        icon = Icons.edit_note;
        color = AppColors.primaryNavy;
        typeLabel = "Note";
        break;
    }

    if (isLegacy) {
      typeLabel = "Old Note";
      color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d').format(note.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryLight),
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
    );
  }
}
