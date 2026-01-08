import 'package:flutter/material.dart';
import '../../models/plan_task.dart';
import '../../services/database_helper.dart';
import '../../services/planner_database_helper.dart';
import '../collapsible_note_card.dart';
import 'ayah_search_dialog.dart';

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
      // Logic for Juz tasks
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
        return AyahSearchDialog(
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
                      // Use CollapsibleNoteCard directly
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: CollapsibleNoteCard(note: note),
                      );
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
}
