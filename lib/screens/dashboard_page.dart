import 'package:flutter/material.dart';
import '../widgets/theme_toggle_button.dart';
import 'planner/assign_page.dart';
import '../models/plan_task.dart';
import '../services/planner_database_helper.dart';
import '../services/database_helper.dart';
import '../theme/app_colors.dart';
import '../utils/ayah_search_query.dart';
import '../widgets/collapsible_note_card.dart';

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

    Color statusColor;
    String statusText;
    String btnText;
    IconData btnIcon;

    switch (task.status) {
      case TaskStatus.notStarted:
        statusColor = AppColors.accentOrange;
        statusText = "Pending";
        btnText = "Start";
        btnIcon = Icons.play_arrow;
        break;
      case TaskStatus.inProgress:
        statusColor = Colors.blue;
        statusText = "In Progress";
        btnText = "Complete";
        btnIcon = Icons.check;
        break;
      default:
        statusColor = Colors.grey;
        statusText = "Unknown";
        btnText = "Done";
        btnIcon = Icons.check;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                    color: statusColor.withOpacity(0.1),
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
                        task.title,
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
                    color: statusColor.withOpacity(0.1),
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
                  task.type == TaskType.memorize ? "Memorize" : "Revision",
                  isDark ? Colors.grey[400] : Colors.grey[700],
                ),
                _buildInfoPill(
                  Icons.event,
                  _formatDate(task.deadline),
                  isDark ? Color(0xFFF0C33D) : Color(0xFFFF0000),
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
                          "Notes",
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

  String _monthAbbr(int month) {
    const months = [
      "", // Placeholder for 0 index
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month];
  }

  String _formatTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm";
  }

  // 07 Jan 2026 10:30 AM
  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} "
      "${_monthAbbr(d.month)} ${d.year} "
      "${_formatTime(d)}";
}

class NotesSheet extends StatefulWidget {
  final PlanTask task;
  const NotesSheet({super.key, required this.task});

  @override
  State<NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<NotesSheet> {
  final TextEditingController _noteController = TextEditingController();
  NoteType _selectedType = NoteType.note;
  List<TaskNote> _notes = [];
  bool _loading = true;

  // Ayah Selection
  List<Map<String, dynamic>> _availableAyahs = [];
  int? _selectedAyahId;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadAvailableAyahs();
  }

  Future<void> _loadNotes() async {
    final notes = await PlannerDatabaseHelper().getTaskNotes(widget.task.id!);
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  Future<void> _loadAvailableAyahs() async {
    final db = await DatabaseHelper().database;
    String whereClause = "";
    List<dynamic> args = [];

    // Construct query based on task unit
    if (widget.task.unitType == PlanUnitType.surah) {
      whereClause = "surahNumber = ?";
      args.add(widget.task.unitId);
      if (widget.task.startAyah != null && widget.task.endAyah != null) {
        whereClause += " AND ayahNumber BETWEEN ? AND ?";
        args.add(widget.task.startAyah);
        args.add(widget.task.endAyah);
      }
    } else if (widget.task.unitType == PlanUnitType.page) {
      whereClause = "pageNumber BETWEEN ? AND ?";
      args.add(widget.task.unitId);
      args.add(widget.task.endUnitId ?? widget.task.unitId);
    } else if (widget.task.unitType == PlanUnitType.juz) {
      // Logic for Juz tasks (handling partial if needed, but assuming full juz for simplicity or using ranges)
      whereClause = "juzNumber = ?";
      args.add(widget.task.unitId);
    } else {
      // Custom/Other - maybe show nothing or fetch nothing
      return;
    }

    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT qm.id, qm.surahNumber, qm.ayahNumber, SUBSTR(qt.text, 1, 50) as text
      FROM quran_meta qm
      JOIN quran_text qt ON qm.id = qt.id
      WHERE $whereClause
      ORDER BY qm.surahNumber, qm.ayahNumber
      ''', args);

    if (mounted) {
      setState(() {
        _availableAyahs = rows;
        if (_availableAyahs.isNotEmpty) {
          _selectedAyahId = _availableAyahs.first['id'] as int;
        }
      });
    }
  }

  String _getSelectedAyahLabel() {
    if (_selectedAyahId == null) return "Select/Search Ayah...";
    final match = _availableAyahs.firstWhere(
      (e) => e['id'] == _selectedAyahId,
      orElse: () => {},
    );
    if (match.isEmpty) return "Unknown Ayah";
    return "${match['surahNumber']}:${match['ayahNumber']} - ${match['text']}";
  }

  void _showAyahSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _AyahSearchDialog(
          ayahs: _availableAyahs,
          onSelected: (id) {
            setState(() => _selectedAyahId = id);
          },
        );
      },
    );
  }

  Future<void> _addNote() async {
    // Description is optional, but we need an ayah selected
    if (_selectedAyahId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select an Ayah")));
      return;
    }

    await PlannerDatabaseHelper().addNote(
      widget.task.id!,
      _noteController.text.trim(),
      _selectedType,
      ayahId: _selectedAyahId,
    );
    _noteController.clear();
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          MediaQuery.of(context).size.height * 0.85, // Taller for more inputs
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Notes: ${widget.task.title}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                ? const Center(child: Text("No notes yet"))
                : ListView.builder(
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return _buildNoteItem(note);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Type Selector
                Row(
                  children: [
                    _buildTypeChip("Note", NoteType.note, Colors.blue),
                    const SizedBox(width: 8),
                    _buildTypeChip("Doubt", NoteType.doubt, Colors.orange),
                    const SizedBox(width: 8),
                    _buildTypeChip("Mistake", NoteType.mistake, Colors.red),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Ayah Selector (Searchable)
                if (_availableAyahs.isNotEmpty)
                  InkWell(
                    onTap: _showAyahSearchDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getSelectedAyahLabel(),
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'QuranFont',
                                color: _selectedAyahId == null
                                    ? Colors.grey
                                    : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black87),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Loading Ayahs...",
                      style: TextStyle(
                        fontFamily: 'QuranFont',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // 3. Input & Send
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          hintText: "Description (Optional)...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 0),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _addNote,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, NoteType type, Color color) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteItem(TaskNote note) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CollapsibleNoteCard(note: note),
    );
  }
}

class _AyahSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> ayahs;
  final Function(int) onSelected;

  const _AyahSearchDialog({required this.ayahs, required this.onSelected});

  @override
  State<_AyahSearchDialog> createState() => _AyahSearchDialogState();
}

class _AyahSearchDialogState extends State<_AyahSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredAyahs = [];

  @override
  void initState() {
    super.initState();
    _filteredAyahs = widget.ayahs;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _filteredAyahs = widget.ayahs);
      return;
    }

    final search = AyahSearchQuery.parse(query);

    setState(() {
      _filteredAyahs = widget.ayahs.where((row) {
        final surah = row['surahNumber'] as int;
        final ayah = row['ayahNumber'] as int;

        // 1. AyahSearchQuery Logic (e.g. 2:200)
        if (search != null) {
          if (search.isSpecificAyah()) {
            return surah == search.surahNumber && ayah == search.ayahNumber;
          }
          if (search.surahNumber != null && search.ayahNumber == null) {
            // If searched "2", matches all ayahs in Surah 2
            if (surah == search.surahNumber) return true;
          }
        }

        // 2. Text Search
        final text = (row['text'] as String).toLowerCase();
        final q = query.toLowerCase();
        return text.contains(q) ||
            "$surah:$ayah".contains(q) ||
            "$ayah".contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme aware
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "Search (e.g. 2:200, 2 200, content)...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey[600],
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey[300]!,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          SizedBox(
            height: 300,
            child: _filteredAyahs.isEmpty
                ? Center(
                    child: Text(
                      "No matches",
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredAyahs.length,
                    separatorBuilder: (c, i) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark ? Colors.white10 : Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final row = _filteredAyahs[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          "${row['surahNumber']}:${row['ayahNumber']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          row['text'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'QuranFont',
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        onTap: () {
                          widget.onSelected(row['id'] as int);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
